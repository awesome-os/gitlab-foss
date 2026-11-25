package duoworkflow

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"maps"
	"mime"
	"net/http"
	"reflect"
	"slices"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"gitlab.com/gitlab-org/gitlab/workhorse/internal/api"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/log"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/secret"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/transport"

	pb "gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/clients/gopb/contract"

	"github.com/modelcontextprotocol/go-sdk/mcp"
	"google.golang.org/protobuf/proto"
)

const gitlabServerName = "gitlab"
const orbitServerName = "orbit"

// slackServerName is the key Rails gives the Slack MCP server.
const slackServerName = "slack"

const (
	externalMcpMaxIdleConns        = 100
	externalMcpMaxIdleConnsPerHost = 10

	mcpServerSetupTimeout = 10 * time.Second
	mcpReconnectTimeout   = 10 * time.Second
)

// mcpProtocolVersion predates 2026-07-28 so Connect skips server/discover.
// TODO: remove with https://gitlab.com/gitlab-org/gitlab/-/work_items/627825
const mcpProtocolVersion = "2025-11-25"

// externalMcpTransport is shared by all sessions so idle connections to external
// MCP servers can be reused across sessions. The restricted transport's default of 2
// idle connections in total is sized for a single caller, not a shared pool.
var externalMcpTransport = transport.NewRestrictedTransport(func(t *http.Transport) {
	t.MaxIdleConns = externalMcpMaxIdleConns
	t.MaxIdleConnsPerHost = externalMcpMaxIdleConnsPerHost
})

type serverSession struct {
	name  string
	cfg   api.McpServerConfig
	rails *api.API
	sess  *session

	client   atomic.Pointer[mcp.ClientSession]
	failures atomic.Int64

	mu      sync.Mutex
	closed  bool
	failErr error
}

type toolSession struct {
	serverName   string
	originalName string
	server       *serverSession
}

type mcpManager interface {
	HasTool(string) bool
	CallTool(context.Context, *pb.Action) (*pb.ClientEvent, error)
	Tools() []*pb.McpTool
	PreApprovedTools() []string
	Close() error
}

type manager struct {
	tools              []*pb.McpTool
	preApprovedTools   []string
	toolSessionsByName map[string]*toolSession
	serverSessions     []*serverSession
	reconnect          bool
	ctx                context.Context
	cancel             context.CancelFunc
}

type roundTripper struct {
	internal bool
	next     http.RoundTripper
	headers  map[string]string
	session  *session
}

var errMcpResponseTooLarge = fmt.Errorf("%w (%d bytes)", errResponseBodySizeLimitExceeded, ActionResponseBodyLimit)

// limitedReadCloser fails the read that passes ActionResponseBodyLimit. Ending
// the body early instead would hand go-sdk truncated JSON, which it treats as a
// broken connection and closes the session.
type limitedReadCloser struct {
	body      io.ReadCloser
	remaining int64
	onLimit   func()
}

func (l *limitedReadCloser) Read(p []byte) (int, error) {
	if l.remaining < 0 {
		return 0, errMcpResponseTooLarge
	}

	// One byte past the limit is enough to tell a body that is too large.
	if int64(len(p)) > l.remaining+1 {
		p = p[:l.remaining+1]
	}

	n, err := l.body.Read(p)
	l.remaining -= int64(n)
	if l.remaining < 0 {
		l.onLimit()
		return n - 1, errMcpResponseTooLarge
	}

	return n, err
}

func (l *limitedReadCloser) Close() error {
	return l.body.Close()
}

type responseLimitKey struct{}

// trackResponseLimit lets RoundTrip report that a call's response was too
// large. go-sdk drops the read error of a streamed response, so CallTool can't
// tell from the error it gets back.
func trackResponseLimit(ctx context.Context) (context.Context, *atomic.Bool) {
	hit := &atomic.Bool{}
	return context.WithValue(ctx, responseLimitKey{}, hit), hit
}

func (t *roundTripper) setWorkflowHeader(r *http.Request) {
	if wfID := t.session.WorkflowID(); wfID != "" {
		r.Header.Set("X-Duo-Workflow-Session-Id", wfID)

		// Rails attributes the call to the workflow through this header, as for RunHTTPRequest
		// actions. Third-party servers must not receive it.
		if t.internal {
			r.Header.Set("X-Gitlab-Duo-Workflow-Id", wfID)
		}
	}
}

func (t *roundTripper) RoundTrip(r *http.Request) (*http.Response, error) {
	for name, value := range t.headers {
		r.Header.Set(name, value)
	}
	r.Header.Set("User-Agent", "GitLab-Workhorse-Mcp-Client")
	t.setWorkflowHeader(r)

	if t.session.forwardedFor != "" {
		r.Header.Set("X-Forwarded-For", t.session.forwardedFor)
	}

	resp, err := t.next.RoundTrip(r)
	if err != nil || resp.Body == nil {
		return resp, err
	}

	limited := &limitedReadCloser{
		body:      resp.Body,
		remaining: ActionResponseBodyLimit,
		onLimit: func() {
			if hit, ok := r.Context().Value(responseLimitKey{}).(*atomic.Bool); ok {
				hit.Store(true)
			}
		},
	}

	// go-sdk closes the session when it can't read a JSON response, but keeps
	// it when RoundTrip fails, so a JSON body is checked here in full. An SSE
	// stream is checked as it is read: go-sdk fails that call, after one
	// reconnect if the server sent an event ID.
	if mediaType, _, _ := mime.ParseMediaType(resp.Header.Get("Content-Type")); mediaType == "application/json" {
		body, readErr := io.ReadAll(limited)
		_ = resp.Body.Close()
		if readErr != nil {
			return nil, readErr
		}

		resp.Body = io.NopCloser(bytes.NewReader(body))
		return resp, nil
	}

	resp.Body = limited
	return resp, nil
}

func newMcpManager(rails *api.API, sess *session, servers map[string]api.McpServerConfig, setupTimeout time.Duration, reconnect bool) (*manager, error) {
	if len(servers) == 0 {
		return nil, nil
	}

	// Servers are set up concurrently, so the session waits for the slowest
	// server or the setup deadline rather than for all of them in turn.
	// Results are merged in name order to keep the tool list deterministic.
	serverNames := slices.Sorted(maps.Keys(servers))

	ctx := sess.Context()
	var deadline <-chan struct{}
	if setupTimeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, setupTimeout)
		defer cancel()
		deadline = ctx.Done()
	}

	results := make([]chan serverSetup, len(serverNames))
	for i, serverName := range serverNames {
		results[i] = make(chan serverSetup, 1)
		go func() {
			// Outside the request goroutine net/http no longer recovers a
			// panic, so one would take down the whole process.
			defer func() {
				if p := recover(); p != nil {
					results[i] <- serverSetup{err: fmt.Errorf("failed to initialize MCP session %s: panic: %v", serverName, p)}
				}
			}()

			results[i] <- setupServer(ctx, rails, sess, serverName, servers[serverName])
		}()
	}

	setups := make([]serverSetup, len(serverNames))
	for i, serverName := range serverNames {
		setup, ok := awaitSetup(results[i], deadline)
		if !ok {
			// go-sdk's cleanup after a timeout can outlast the deadline, so the setup finishes alone.
			go closeAbandonedSetup(results[i])
			setup = serverSetup{err: fmt.Errorf("failed to initialize MCP session %s: %w", serverName, ctx.Err())}
		}
		setups[i] = setup
	}

	manager := &manager{toolSessionsByName: make(map[string]*toolSession), reconnect: reconnect}
	manager.ctx, manager.cancel = context.WithCancel(sess.Context())

	var errs []error
	for i, setup := range setups {
		if setup.session != nil {
			manager.serverSessions = append(manager.serverSessions, setup.session)
		}

		if setup.err != nil {
			reportMcpInitFailure(sess, serverNames[i], setup.err)
			errs = append(errs, setup.err)
			continue
		}

		errs = append(errs, manager.addTools(setup.session, setup.tools))
	}

	return manager, errors.Join(errs...)
}

// serverSetup is the outcome of connecting to one MCP server and listing its
// tools. session is set whenever the connection succeeded, so it is closed with
// the manager even if listing the tools failed.
type serverSetup struct {
	session *serverSession
	tools   *mcp.ListToolsResult
	err     error
}

// awaitSetup checks result first: after the deadline, select picks at random between them. A nil deadline never passes.
func awaitSetup(result <-chan serverSetup, deadline <-chan struct{}) (serverSetup, bool) {
	select {
	case setup := <-result:
		return setup, true
	default:
	}

	select {
	case setup := <-result:
		return setup, true
	case <-deadline:
		return serverSetup{}, false
	}
}

func closeAbandonedSetup(result <-chan serverSetup) {
	if setup := <-result; setup.session != nil {
		_ = setup.session.current().Close()
	}
}

func setupServer(ctx context.Context, rails *api.API, sess *session, serverName string, serverCfg api.McpServerConfig) serverSetup {
	session, err := buildSession(ctx, rails, sess, serverName, serverCfg)
	if err != nil {
		return serverSetup{err: fmt.Errorf("failed to initialize MCP session %s: %w", serverName, err)}
	}

	tools, err := session.current().ListTools(ctx, &mcp.ListToolsParams{})
	if err != nil {
		return serverSetup{session: session, err: fmt.Errorf("failed to list tools %s: %w", serverName, err)}
	}

	return serverSetup{session: session, tools: tools}
}

func buildSession(ctx context.Context, rails *api.API, sess *session, serverName string, serverCfg api.McpServerConfig) (*serverSession, error) {
	client := mcp.NewClient(&mcp.Implementation{Name: "mcp-client", Version: "v1.0.0"}, nil)

	var t *mcp.StreamableClientTransport

	var endpoint string
	var nextTransport http.RoundTripper

	internalPaths := map[string]string{
		gitlabServerName: "api/v4/mcp",
		orbitServerName:  "api/v4/orbit/mcp",
	}

	path, internal := internalPaths[serverName]
	if internal {
		endpoint = rails.URL.JoinPath(path).String()
		nextTransport = secret.NewRoundTripper(rails.Client.Transport, rails.Version)
	} else {
		endpoint = serverCfg.URL
		nextTransport = externalMcpTransport
	}

	rt := &roundTripper{
		internal: internal,
		next:     nextTransport,
		headers:  serverCfg.Headers,
		session:  sess,
	}

	t = &mcp.StreamableClientTransport{
		Endpoint:   endpoint,
		HTTPClient: &http.Client{Transport: rt},
		// DisableStandaloneSSE must be true because the GitLab MCP server does not support
		// SSE (Server-Sent Events). Without this flag, the client attempts an SSE connection
		// first, which fails and breaks the connection flow.
		// See: https://github.com/modelcontextprotocol/go-sdk/pull/729
		DisableStandaloneSSE: true,
	}

	session, err := client.Connect(ctx, t, &mcp.ClientSessionOptions{ProtocolVersion: mcpProtocolVersion})
	if err != nil {
		return nil, err
	}

	server := &serverSession{name: serverName, cfg: serverCfg, rails: rails, sess: sess}
	server.client.Store(session)

	return server, nil
}

func (s *serverSession) current() *mcp.ClientSession {
	return s.client.Load()
}

// reconnect opens a new session to replace the broken one. If a reconnect
// failed after this call started, it returns that error instead of trying again.
func (s *serverSession) reconnect(ctx context.Context, broken *mcp.ClientSession, failuresSeen int64, cause error) (*mcp.ClientSession, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.closed || s.current() != broken {
		return s.current(), nil
	}
	if s.failures.Load() != failuresSeen {
		return nil, s.failErr
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}

	fresh, err := s.connectWithin(ctx, mcpReconnectTimeout)
	if err != nil && ctx.Err() != nil {
		return nil, err
	}
	reportMcpReconnect(s.sess, s.name, cause, err)
	if err != nil {
		s.failErr = err
		s.failures.Add(1)
		return nil, err
	}

	go func() { _ = broken.Close() }()
	s.client.Store(fresh)

	return fresh, nil
}

// connectWithin stops waiting at timeout, since the SDK's cleanup after a failed Connect ignores the deadline.
func (s *serverSession) connectWithin(ctx context.Context, timeout time.Duration) (*mcp.ClientSession, error) {
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel()

	result := make(chan serverSetup, 1)
	go func() {
		defer func() {
			if p := recover(); p != nil {
				result <- serverSetup{err: fmt.Errorf("panic: %v", p)}
			}
		}()

		session, err := buildSession(ctx, s.rails, s.sess, s.name, s.cfg)
		result <- serverSetup{session: session, err: err}
	}()

	setup, ok := awaitSetup(result, ctx.Done())
	if !ok {
		go closeAbandonedSetup(result)
		return nil, ctx.Err()
	}
	if setup.err != nil {
		return nil, setup.err
	}

	return setup.session.current(), nil
}

func (s *serverSession) close() error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.closed = true

	return s.current().Close()
}

func (m *manager) addTools(s *serverSession, toolsResult *mcp.ListToolsResult) error {
	var errs []error

	// If s.cfg.Tools is missing (nil), then all tools are available
	// Otherwise, we filter the list of tools based on the provided value
	allToolsAvailable := true
	var configuredTools []string
	if s.cfg.Tools != nil {
		allToolsAvailable = false
		configuredTools = *s.cfg.Tools
	}

	var preApprovedTools []string
	if s.cfg.PreApprovedTools != nil {
		preApprovedTools = *s.cfg.PreApprovedTools
	}

	for _, tool := range toolsResult.Tools {
		schemaBytes, err := json.Marshal(tool.InputSchema)
		if err != nil {
			errs = append(errs, fmt.Errorf("failed to marshal input schema, server: %s, tool: %s, error: %v", s.name, tool.Name, err))
			continue
		}

		if allToolsAvailable || slices.Contains(configuredTools, tool.Name) {
			prefixedName := s.name + "_" + tool.Name

			mcpTool := &pb.McpTool{
				Name:        prefixedName,
				Description: tool.Description,
				InputSchema: string(schemaBytes),
				Trusted:     proto.Bool(s.cfg.Trusted),
			}

			m.tools = append(m.tools, mcpTool)

			m.toolSessionsByName[prefixedName] = &toolSession{
				serverName:   s.name,
				originalName: tool.Name,
				server:       s,
			}

			if slices.Contains(preApprovedTools, tool.Name) {
				m.preApprovedTools = append(m.preApprovedTools, prefixedName)
			}
		}
	}

	return errors.Join(errs...)
}

func (m *manager) HasTool(name string) bool {
	if m == nil {
		return false
	}

	_, ok := m.toolSessionsByName[name]
	return ok
}

func (m *manager) Tools() []*pb.McpTool {
	if m == nil {
		return nil
	}

	return m.tools
}

func (m *manager) PreApprovedTools() []string {
	if m == nil {
		return nil
	}

	return m.preApprovedTools
}

func (m *manager) CallTool(ctx context.Context, action *pb.Action) (*pb.ClientEvent, error) {
	mcpTool := action.GetRunMCPTool()

	toolSession, ok := m.toolSessionsByName[mcpTool.Name]
	if !ok {
		return nil, fmt.Errorf("CallTool: unknown tool: %v", mcpTool.Name)
	}

	var arguments map[string]any
	if err := json.Unmarshal([]byte(mcpTool.Args), &arguments); err != nil {
		return nil, fmt.Errorf("CallTool: failed to unmarshal MCP args: %v", err)
	}
	params := &mcp.CallToolParams{
		Name:      toolSession.originalName,
		Arguments: arguments,
	}

	server := mcpServerLabel(toolSession.serverName)
	start := time.Now()
	callCtx, responseTooLarge := trackResponseLimit(ctx)
	res, err := m.callTool(callCtx, toolSession.server, params)
	mcpCallDurationSeconds.WithLabelValues(server).Observe(time.Since(start).Seconds())

	switch {
	case err != nil:
		mcpCallsTotal.WithLabelValues(server, mcpOutcomeError).Inc()
		if responseTooLarge.Load() {
			err = errMcpResponseTooLarge
		}
		return nil, fmt.Errorf("CallTool: failed to call MCP tool: %w", err)
	case res.IsError:
		mcpCallsTotal.WithLabelValues(server, mcpOutcomeToolError).Inc()
	default:
		mcpCallsTotal.WithLabelValues(server, mcpOutcomeOK).Inc()
	}

	return m.buildClientEvent(ctx, action, mcpTool, res), nil
}

func (m *manager) callTool(ctx context.Context, server *serverSession, params *mcp.CallToolParams) (*mcp.CallToolResult, error) {
	failuresSeen := server.failures.Load()
	session := server.current()
	res, err := session.CallTool(ctx, params)

	if !m.reconnect || ctx.Err() != nil || !errors.Is(err, mcp.ErrConnectionClosed) {
		return res, err
	}

	// A server error with code -32003 or -32004 also matches ErrConnectionClosed.
	// Only a closed connection fails the Ping without sending it.
	if !errors.Is(session.Ping(ctx, nil), mcp.ErrConnectionClosed) {
		return res, err
	}

	reconnectCtx, cancel := context.WithCancel(ctx)
	defer cancel()
	defer context.AfterFunc(m.ctx, cancel)()

	session, reconnectErr := server.reconnect(reconnectCtx, session, failuresSeen, err)
	if reconnectErr != nil {
		return nil, fmt.Errorf("%w (reconnect failed: %w)", err, reconnectErr)
	}

	return session.CallTool(ctx, params)
}

func (m *manager) buildClientEvent(ctx context.Context, action *pb.Action, mcpTool *pb.RunMCPTool, res *mcp.CallToolResult) *pb.ClientEvent {
	var texts, unsupportedTypes []string
	for _, c := range res.Content {
		if textContent, ok := c.(*mcp.TextContent); ok {
			texts = append(texts, textContent.Text)
		} else {
			unsupportedTypes = append(unsupportedTypes, reflect.TypeOf(c).String())
		}
	}

	if len(unsupportedTypes) > 0 {
		log.WithContextFields(ctx, log.Fields{
			"name":          mcpTool.Name,
			"request_id":    action.RequestID,
			"content_types": unsupportedTypes,
		}).Info("MCP tool response content type not supported")
	}

	var content string
	switch {
	case len(res.Content) == 0:
		content = "MCP tool response is empty"
	case len(texts) == 0:
		content = "MCP tool response content type not supported"
	default:
		content = strings.Join(texts, "\n")
	}

	response := &pb.PlainTextResponse{}
	if res.IsError {
		response.Error = content
	} else {
		response.Response = content
	}

	return &pb.ClientEvent{
		Response: &pb.ClientEvent_ActionResponse{
			ActionResponse: &pb.ActionResponse{
				RequestID: action.RequestID,
				ResponseType: &pb.ActionResponse_PlainTextResponse{
					PlainTextResponse: response,
				},
			},
		},
	}
}

func (m *manager) Close() error {
	if m == nil {
		return nil
	}

	// Cancel first, so a reconnect in progress returns and releases the server's lock.
	m.cancel()

	var errs []error
	for _, s := range m.serverSessions {
		errs = append(errs, s.close())
	}

	return errors.Join(errs...)
}

// reportMcpInitFailure records a server whose tools are missing from the run.
func reportMcpInitFailure(sess *session, serverName string, err error) {
	mcpInitFailuresTotal.WithLabelValues(mcpServerLabel(serverName)).Inc()
	sess.logger().WithError(err).WithFields(log.Fields{"server": serverName}).Warn("Failed to initialize MCP server")
}

func reportMcpReconnect(sess *session, serverName string, cause, err error) {
	outcome := mcpOutcomeOK
	if err != nil {
		outcome = mcpOutcomeError
	}

	mcpReconnectsTotal.WithLabelValues(mcpServerLabel(serverName), outcome).Inc()
	sess.logger().WithError(cause).WithFields(log.Fields{
		"server":          serverName,
		"outcome":         outcome,
		"reconnect_error": err,
	}).Warn("Reconnecting to MCP server after the connection closed")
}
