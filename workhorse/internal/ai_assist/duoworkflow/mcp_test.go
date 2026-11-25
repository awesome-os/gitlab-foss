package duoworkflow

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelcontextprotocol/go-sdk/mcp"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	pb "gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/clients/gopb/contract"

	"gitlab.com/gitlab-org/gitlab/workhorse/internal/api"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/secret"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/testhelper"
)

func TestRoundTripper_RoundTrip(t *testing.T) {
	t.Run("adds custom headers", func(t *testing.T) {
		var capturedRequest *http.Request
		var transportFunc = func(req *http.Request) (*http.Response, error) {
			capturedRequest = req
			return &http.Response{
				StatusCode: 200,
				Body:       http.NoBody,
				Header:     make(http.Header),
			}, nil
		}

		rt := &roundTripper{
			next: &mockTransportFunc{fn: transportFunc},
			headers: map[string]string{
				"Authorization":   "Bearer test-token",
				"X-Custom-Header": "custom-value",
			},
			session: newSession(httptest.NewRequest("GET", "/", nil)),
		}

		req := httptest.NewRequest("GET", "http://example.com", nil)
		r, err := rt.RoundTrip(req)
		require.NoError(t, err)
		require.NoError(t, r.Body.Close())

		require.NotNil(t, capturedRequest)
		assert.Equal(t, "Bearer test-token", capturedRequest.Header.Get("Authorization"))
		assert.Equal(t, "custom-value", capturedRequest.Header.Get("X-Custom-Header"))
		assert.Equal(t, "GitLab-Workhorse-Mcp-Client", capturedRequest.Header.Get("User-Agent"))
	})

	t.Run("sets X-Forwarded-For from original request", func(t *testing.T) {
		var capturedRequest *http.Request
		var transportFunc = func(req *http.Request) (*http.Response, error) {
			capturedRequest = req
			return &http.Response{
				StatusCode: 200,
				Body:       http.NoBody,
				Header:     make(http.Header),
			}, nil
		}

		originalReq := httptest.NewRequest("GET", "/test", nil)
		originalReq.RemoteAddr = "192.0.2.1:1234"

		rt := &roundTripper{
			next:    &mockTransportFunc{fn: transportFunc},
			headers: map[string]string{},
			session: newSession(originalReq),
		}

		req := httptest.NewRequest("GET", "http://example.com", nil)
		r, err := rt.RoundTrip(req)
		require.NoError(t, err)
		require.NoError(t, r.Body.Close())

		require.NotNil(t, capturedRequest)
		assert.Equal(t, "192.0.2.1", capturedRequest.Header.Get("X-Forwarded-For"))
	})

	t.Run("appends to existing X-Forwarded-For", func(t *testing.T) {
		var capturedRequest *http.Request
		var transportFunc = func(req *http.Request) (*http.Response, error) {
			capturedRequest = req
			return &http.Response{
				StatusCode: 200,
				Body:       http.NoBody,
				Header:     make(http.Header),
			}, nil
		}

		originalReq := httptest.NewRequest("GET", "/test", nil)
		originalReq.RemoteAddr = "192.0.2.1:1234"
		originalReq.Header.Set("X-Forwarded-For", "10.0.0.1")

		rt := &roundTripper{
			next:    &mockTransportFunc{fn: transportFunc},
			headers: map[string]string{},
			session: newSession(originalReq),
		}

		req := httptest.NewRequest("GET", "http://example.com", nil)
		r, err := rt.RoundTrip(req)
		require.NoError(t, err)
		require.NoError(t, r.Body.Close())

		require.NotNil(t, capturedRequest)
		assert.Equal(t, "10.0.0.1, 192.0.2.1", capturedRequest.Header.Get("X-Forwarded-For"))
	})

	t.Run("handles invalid RemoteAddr gracefully", func(t *testing.T) {
		var capturedRequest *http.Request
		var transportFunc = func(req *http.Request) (*http.Response, error) {
			capturedRequest = req
			return &http.Response{
				StatusCode: 200,
				Body:       http.NoBody,
				Header:     make(http.Header),
			}, nil
		}

		originalReq := httptest.NewRequest("GET", "/test", nil)
		originalReq.RemoteAddr = "invalid-address"

		rt := &roundTripper{
			next:    &mockTransportFunc{fn: transportFunc},
			headers: map[string]string{},
			session: newSession(originalReq),
		}

		req := httptest.NewRequest("GET", "http://example.com", nil)
		r, err := rt.RoundTrip(req)
		require.NoError(t, err)
		require.NoError(t, r.Body.Close())

		require.NotNil(t, capturedRequest)
		assert.Empty(t, capturedRequest.Header.Get("X-Forwarded-For"))
	})

	t.Run("wraps response body with limited reader", func(t *testing.T) {
		responseBody := "This is a test response body that should be limited"
		var transportFunc = func(_ *http.Request) (*http.Response, error) {
			return &http.Response{
				StatusCode: 200,
				Body:       io.NopCloser(strings.NewReader(responseBody)),
				Header:     make(http.Header),
			}, nil
		}

		rt := &roundTripper{
			next:    &mockTransportFunc{fn: transportFunc},
			headers: map[string]string{},
			session: newSession(httptest.NewRequest("GET", "/", nil)),
		}

		req := httptest.NewRequest("GET", "http://example.com", nil)
		resp, err := rt.RoundTrip(req)
		require.NoError(t, err)
		require.NotNil(t, resp)
		defer resp.Body.Close()

		_, ok := resp.Body.(*limitedReadCloser)
		require.True(t, ok, "Response body should be wrapped with limitedReadCloser")

		body, err := io.ReadAll(resp.Body)
		require.NoError(t, err)
		assert.Equal(t, responseBody, string(body))
	})

	t.Run("limits response body to ActionResponseBodyLimit", func(t *testing.T) {
		tests := []struct {
			name        string
			contentType string
			size        int
			wantErr     bool
		}{
			{name: "stream at the limit", contentType: "text/event-stream", size: ActionResponseBodyLimit},
			{name: "stream past the limit", contentType: "text/event-stream", size: ActionResponseBodyLimit + 1, wantErr: true},
			{name: "JSON at the limit", contentType: "application/json", size: ActionResponseBodyLimit},
			{name: "JSON past the limit", contentType: "application/json; charset=utf-8", size: ActionResponseBodyLimit + 1, wantErr: true},
		}

		for _, tt := range tests {
			t.Run(tt.name, func(t *testing.T) {
				rt := &roundTripper{
					next: &mockTransportFunc{fn: func(_ *http.Request) (*http.Response, error) {
						return &http.Response{
							StatusCode: 200,
							Body:       io.NopCloser(strings.NewReader(strings.Repeat("x", tt.size))),
							Header:     http.Header{"Content-Type": {tt.contentType}},
						}, nil
					}},
					headers: map[string]string{},
					session: newSession(httptest.NewRequest("GET", "/", nil)),
				}

				ctx, hit := trackResponseLimit(context.Background())
				resp, err := rt.RoundTrip(httptest.NewRequest("GET", "http://example.com", nil).WithContext(ctx))

				var body []byte
				if err == nil {
					defer resp.Body.Close()
					body, err = io.ReadAll(resp.Body)
				}

				if tt.wantErr {
					require.ErrorIs(t, err, errResponseBodySizeLimitExceeded)
					require.LessOrEqual(t, len(body), ActionResponseBodyLimit)
				} else {
					require.NoError(t, err)
					require.Len(t, body, tt.size)
				}
				require.Equal(t, tt.wantErr, hit.Load())
			})
		}
	})

	t.Run("includes X-Duo-Workflow-Session-Id once the workflow ID is set", func(t *testing.T) {
		var capturedRequest *http.Request
		var transportFunc = func(req *http.Request) (*http.Response, error) {
			capturedRequest = req
			return &http.Response{
				StatusCode: 200,
				Body:       http.NoBody,
				Header:     make(http.Header),
			}, nil
		}

		sess := newSession(httptest.NewRequest("GET", "/", nil))
		rt := &roundTripper{
			next:    &mockTransportFunc{fn: transportFunc},
			headers: map[string]string{},
			session: sess,
		}

		// Before the workflow ID is set — header should be absent
		req := httptest.NewRequest("GET", "http://example.com", nil)
		r, err := rt.RoundTrip(req)
		require.NoError(t, err)
		require.NoError(t, r.Body.Close())
		assert.Empty(t, capturedRequest.Header.Get("X-Duo-Workflow-Session-Id"))

		// After setting workflowID — header should be present
		sess.setWorkflowID("test-workflow-id-123")

		req = httptest.NewRequest("GET", "http://example.com", nil)
		r, err = rt.RoundTrip(req)
		require.NoError(t, err)
		require.NoError(t, r.Body.Close())
		assert.Equal(t, "test-workflow-id-123", capturedRequest.Header.Get("X-Duo-Workflow-Session-Id"))
	})
}

func TestNewMcpManager(t *testing.T) {
	testhelper.ConfigureSecret()

	t.Run("successful initialization with single server", func(t *testing.T) {
		mcpServer := setupMockMcpServer(t, "", []mcpTool{
			{Name: "test_tool", Description: "A test tool"},
		})

		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"test-server": {
				URL:     mcpServer.URL,
				Headers: map[string]string{},
				Tools:   &([]string{"test_tool"}),
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)

		require.NoError(t, err)
		require.NotNil(t, mgr)
		assert.Len(t, mgr.tools, 1)
		assert.Equal(t, "test-server_test_tool", mgr.tools[0].Name)
		assert.Len(t, mgr.toolSessionsByName, 1)
		assert.Len(t, mgr.serverSessions, 1)
		assert.Empty(t, mgr.preApprovedTools)
	})

	t.Run("successful initialization with multiple servers", func(t *testing.T) {
		mcpServer1 := setupMockMcpServer(t, "", []mcpTool{
			{Name: "tool1", Description: "Tool 1"},
		})
		mcpServer2 := setupMockMcpServer(t, "", []mcpTool{
			{Name: "tool2", Description: "Tool 2"},
		})

		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"server1": {
				URL:     mcpServer1.URL,
				Headers: map[string]string{},
				Tools:   &([]string{"tool1"}),
			},
			"server2": {
				URL:     mcpServer2.URL,
				Headers: map[string]string{},
				Tools:   &([]string{"tool2"}),
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)

		require.NoError(t, err)
		require.NotNil(t, mgr)
		assert.Len(t, mgr.tools, 2)
		assert.Len(t, mgr.toolSessionsByName, 2)
		assert.Len(t, mgr.serverSessions, 2)
	})

	t.Run("filters tools based on config", func(t *testing.T) {
		mcpServer := setupMockMcpServer(t, "", []mcpTool{
			{Name: "allowed_tool", Description: "Allowed tool"},
			{Name: "blocked_tool", Description: "Blocked tool"},
		})

		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"test-server": {
				URL:     mcpServer.URL,
				Headers: map[string]string{},
				Tools:   &([]string{"allowed_tool"}),
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)

		require.NoError(t, err)
		require.NotNil(t, mgr)
		assert.Len(t, mgr.tools, 1)
		assert.Equal(t, "test-server_allowed_tool", mgr.tools[0].Name)
		assert.Empty(t, mgr.preApprovedTools)
	})

	t.Run("includes preapproved tools when configured", func(t *testing.T) {
		mcpServer := setupMockMcpServer(t, "", []mcpTool{
			{Name: "tool1", Description: "Tool 1"},
			{Name: "tool2", Description: "Tool 2"},
		})

		req := httptest.NewRequest("GET", "/test", nil)

		preApprovedTools := []string{"tool1"}
		servers := map[string]api.McpServerConfig{
			"test-server": {
				URL:              mcpServer.URL,
				Headers:          map[string]string{},
				Tools:            &([]string{"tool1", "tool2"}),
				PreApprovedTools: &preApprovedTools,
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)

		require.NoError(t, err)
		require.NotNil(t, mgr)
		assert.Len(t, mgr.tools, 2)
		assert.Len(t, mgr.preApprovedTools, 1)
		assert.Equal(t, "test-server_tool1", mgr.preApprovedTools[0])
	})

	t.Run("only includes preapproved tools that are also in enabled tools", func(t *testing.T) {
		mcpServer := setupMockMcpServer(t, "", []mcpTool{
			{Name: "tool1", Description: "Tool 1"},
			{Name: "tool2", Description: "Tool 2"},
		})

		req := httptest.NewRequest("GET", "/test", nil)

		preApprovedTools := []string{"tool1", "tool3"}
		servers := map[string]api.McpServerConfig{
			"test-server": {
				URL:              mcpServer.URL,
				Headers:          map[string]string{},
				Tools:            &([]string{"tool1"}),
				PreApprovedTools: &preApprovedTools,
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)

		require.NoError(t, err)
		require.NotNil(t, mgr)
		assert.Len(t, mgr.tools, 1)
		assert.Len(t, mgr.preApprovedTools, 1)
		assert.Equal(t, "test-server_tool1", mgr.preApprovedTools[0])
	})

	t.Run("includes all tools when Tools config is empty", func(t *testing.T) {
		mcpServer := setupMockMcpServer(t, "", []mcpTool{
			{Name: "tool1", Description: "Tool 1"},
			{Name: "tool2", Description: "Tool 2"},
		})

		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"test-server": {
				URL:     mcpServer.URL,
				Headers: map[string]string{},
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)

		require.NoError(t, err)
		require.NotNil(t, mgr)
		assert.Len(t, mgr.tools, 2)
	})

	t.Run("filters all tools when Tools config is empty", func(t *testing.T) {
		mcpServer := setupMockMcpServer(t, "gitlab", []mcpTool{
			{Name: "tool1", Description: "Tool 1"},
			{Name: "tool2", Description: "Tool 2"},
		})

		apiURL, err := url.Parse(mcpServer.URL)
		require.NoError(t, err)

		rails := api.NewAPI(apiURL, "test-version", http.DefaultTransport)
		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"gitlab": {
				URL:     mcpServer.URL,
				Headers: map[string]string{},
				Tools:   &([]string{}),
			},
		}

		mgr, err := newMcpManager(rails, newSession(req), servers, 0, false)

		require.NoError(t, err)
		require.NotNil(t, mgr)
		assert.Empty(t, mgr.tools)
	})

	t.Run("returns nothing when servers map is empty", func(t *testing.T) {
		req := httptest.NewRequest("GET", "/test", nil)

		mgr, err := newMcpManager(nil, newSession(req), map[string]api.McpServerConfig{}, 0, false)

		require.NoError(t, err)
		require.Nil(t, mgr)
	})

	t.Run("continues with partial success when one server fails", func(t *testing.T) {
		mcpServer := setupMockMcpServer(t, "", []mcpTool{
			{Name: "tool1", Description: "Tool 1"},
		})

		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"good-server": {
				URL:     mcpServer.URL,
				Headers: map[string]string{},
				Tools:   &([]string{"tool1"}),
			},
			"bad-server": {
				URL:     "http://localhost:1", // Use a port that's likely to be refused
				Headers: map[string]string{},
				Tools:   &([]string{"tool2"}),
			},
		}

		initFailures := counterVecValue(t, mcpInitFailuresTotal, mcpServerCatalog)

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)

		require.Error(t, err)
		require.NotNil(t, mgr)
		assert.Len(t, mgr.tools, 1)
		assert.Contains(t, err.Error(), "failed to initialize MCP session bad-server")
		assert.InDelta(t, initFailures+1, counterVecValue(t, mcpInitFailuresTotal, mcpServerCatalog), 0)
	})
}

func TestManager_HasTool(t *testing.T) {
	t.Run("returns true for existing tool", func(t *testing.T) {
		mgr := &manager{
			toolSessionsByName: map[string]*toolSession{
				"test_tool": {},
			},
		}

		assert.True(t, mgr.HasTool("test_tool"))
	})

	t.Run("returns false for non-existing tool", func(t *testing.T) {
		mgr := &manager{
			toolSessionsByName: map[string]*toolSession{
				"test_tool": {},
			},
		}

		assert.False(t, mgr.HasTool("other_tool"))
	})

	t.Run("returns false when manager is nil", func(t *testing.T) {
		var mgr *manager
		assert.False(t, mgr.HasTool("test_tool"))
	})
}

func TestManager_Tools(t *testing.T) {
	t.Run("returns tools list", func(t *testing.T) {
		tools := []*pb.McpTool{
			{Name: "tool1", Description: "Tool 1"},
			{Name: "tool2", Description: "Tool 2"},
		}

		mgr := &manager{
			tools: tools,
		}

		result := mgr.Tools()
		assert.Equal(t, tools, result)
		assert.Len(t, result, 2)
	})

	t.Run("returns nil when manager is nil", func(t *testing.T) {
		var mgr *manager
		assert.Nil(t, mgr.Tools())
	})

	t.Run("returns empty list when no tools", func(t *testing.T) {
		mgr := &manager{
			tools: []*pb.McpTool{},
		}

		result := mgr.Tools()
		assert.NotNil(t, result)
		assert.Empty(t, result)
	})
}

func TestManager_PreApprovedTools(t *testing.T) {
	t.Run("returns preapproved tools list", func(t *testing.T) {
		preApprovedTools := []string{"tool1", "tool2"}

		mgr := &manager{
			preApprovedTools: preApprovedTools,
		}

		result := mgr.PreApprovedTools()
		assert.Equal(t, preApprovedTools, result)
		assert.Len(t, result, 2)
	})

	t.Run("returns nil when manager is nil", func(t *testing.T) {
		var mgr *manager
		assert.Nil(t, mgr.PreApprovedTools())
	})

	t.Run("returns empty list when no preapproved tools", func(t *testing.T) {
		mgr := &manager{
			preApprovedTools: []string{},
		}

		result := mgr.PreApprovedTools()
		assert.NotNil(t, result)
		assert.Empty(t, result)
	})
}

func TestManager_CallTool(t *testing.T) {
	t.Run("successfully calls tool with valid arguments", func(t *testing.T) {
		mcpServer := setupMockMcpServerWithCallHandler(t, "", []mcpTool{
			{Name: "test_tool", Description: "A test tool"},
		}, func(name string, args map[string]any) (string, bool, error) {
			assert.Equal(t, "test_tool", name)
			assert.Equal(t, "123", args["issue_id"])
			return `{"id": 123, "title": "Test Issue"}`, false, nil
		})

		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"test-server": {
				URL:     mcpServer.URL,
				Headers: map[string]string{},
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)
		require.NoError(t, err)

		action := &pb.Action{
			RequestID: "req-mcp-123",
			Action: &pb.Action_RunMCPTool{
				RunMCPTool: &pb.RunMCPTool{
					Name: "test-server_test_tool",
					Args: `{"issue_id": "123"}`,
				},
			},
		}

		calls := counterVecValue(t, mcpCallsTotal, mcpServerCatalog, mcpOutcomeOK)

		result, err := mgr.CallTool(context.Background(), action)

		require.NoError(t, err)
		require.NotNil(t, result)
		plainTextResp := result.GetActionResponse().GetPlainTextResponse()
		assert.Contains(t, plainTextResp.Response, "Test Issue")
		assert.Empty(t, plainTextResp.Error)
		assert.InDelta(t, calls+1, counterVecValue(t, mcpCallsTotal, mcpServerCatalog, mcpOutcomeOK), 0)
	})

	t.Run("returns error for unknown tool", func(t *testing.T) {
		mgr := &manager{
			toolSessionsByName: map[string]*toolSession{},
		}

		action := &pb.Action{
			RequestID: "req-mcp-123",
			Action: &pb.Action_RunMCPTool{
				RunMCPTool: &pb.RunMCPTool{
					Name: "unknown_tool",
					Args: `{}`,
				},
			},
		}

		result, err := mgr.CallTool(context.Background(), action)

		require.Error(t, err)
		require.Nil(t, result)
		assert.Contains(t, err.Error(), "unknown tool")
	})

	t.Run("returns error for invalid JSON arguments", func(t *testing.T) {
		mgr := &manager{
			toolSessionsByName: map[string]*toolSession{
				"test_tool": {},
			},
		}

		action := &pb.Action{
			RequestID: "req-mcp-123",
			Action: &pb.Action_RunMCPTool{
				RunMCPTool: &pb.RunMCPTool{
					Name: "test_tool",
					Args: `invalid json`,
				},
			},
		}

		result, err := mgr.CallTool(context.Background(), action)

		require.Error(t, err)
		require.Nil(t, result)
		assert.Contains(t, err.Error(), "failed to unmarshal MCP args")
	})

	t.Run("handles MCP error response", func(t *testing.T) {
		mcpServer := setupMockMcpServerWithCallHandler(t, "", []mcpTool{
			{Name: "test_tool", Description: "A test tool"},
		}, func(_ string, _ map[string]any) (string, bool, error) {
			return "Tool execution failed", true, nil
		})

		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"test-server": {
				URL:     mcpServer.URL,
				Headers: map[string]string{},
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)
		require.NoError(t, err)

		action := &pb.Action{
			RequestID: "req-mcp-123",
			Action: &pb.Action_RunMCPTool{
				RunMCPTool: &pb.RunMCPTool{
					Name: "test-server_test_tool",
					Args: `{}`,
				},
			},
		}

		toolErrors := counterVecValue(t, mcpCallsTotal, mcpServerCatalog, mcpOutcomeToolError)

		result, err := mgr.CallTool(context.Background(), action)

		require.NoError(t, err)
		require.NotNil(t, result)
		plainTextResp := result.GetActionResponse().GetPlainTextResponse()
		assert.Equal(t, "Tool execution failed", plainTextResp.Error)
		assert.Empty(t, plainTextResp.Response)
		assert.InDelta(t, toolErrors+1, counterVecValue(t, mcpCallsTotal, mcpServerCatalog, mcpOutcomeToolError), 0)
	})

	t.Run("handles empty MCP response", func(t *testing.T) {
		mcpServer := setupMockMcpServerWithCallHandler(t, "", []mcpTool{
			{Name: "test_tool", Description: "A test tool"},
		}, func(_ string, _ map[string]any) (string, bool, error) {
			return "", false, nil
		})

		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"test-server": {
				URL:     mcpServer.URL,
				Headers: map[string]string{},
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)
		require.NoError(t, err)

		action := &pb.Action{
			RequestID: "req-mcp-123",
			Action: &pb.Action_RunMCPTool{
				RunMCPTool: &pb.RunMCPTool{
					Name: "test-server_test_tool",
					Args: `{}`,
				},
			},
		}

		result, err := mgr.CallTool(context.Background(), action)

		require.NoError(t, err)
		require.NotNil(t, result)
		plainTextResp := result.GetActionResponse().GetPlainTextResponse()
		assert.Equal(t, "MCP tool response is empty", plainTextResp.Response)
	})
}

// newSdkMcpServer serves one tool, "t", from a go-sdk MCP server, so the
// response is encoded exactly as a real server encodes it.
func newSdkMcpServer(t *testing.T, opts *mcp.StreamableHTTPOptions, result func() *mcp.CallToolResult) *manager {
	t.Helper()

	srv := mcp.NewServer(&mcp.Implementation{Name: "test", Version: "v1"}, nil)
	srv.AddTool(&mcp.Tool{Name: "t", InputSchema: map[string]any{"type": "object"}},
		func(context.Context, *mcp.CallToolRequest) (*mcp.CallToolResult, error) { return result(), nil })

	ts := httptest.NewServer(mcp.NewStreamableHTTPHandler(func(*http.Request) *mcp.Server { return srv }, opts))
	t.Cleanup(ts.Close)

	mgr, err := newMcpManager(nil, newSession(httptest.NewRequest(http.MethodGet, "/test", nil)),
		map[string]api.McpServerConfig{"ext": {URL: ts.URL}}, 0, false)
	require.NoError(t, err)
	t.Cleanup(func() { _ = mgr.Close() })

	return mgr
}

func callSdkTool(t *testing.T, mgr *manager) (*pb.PlainTextResponse, error) {
	t.Helper()

	event, err := mgr.CallTool(context.Background(), &pb.Action{
		RequestID: "req-mcp",
		Action:    &pb.Action_RunMCPTool{RunMCPTool: &pb.RunMCPTool{Name: "ext_t", Args: "{}"}},
	})

	return event.GetActionResponse().GetPlainTextResponse(), err
}

func TestManager_CallTool_contentParts(t *testing.T) {
	image := &mcp.ImageContent{Data: []byte("png"), MIMEType: "image/png"}

	tests := []struct {
		name    string
		content []mcp.Content
		isError bool
		want    string
	}{
		{
			name:    "joins every text part",
			content: []mcp.Content{&mcp.TextContent{Text: "one"}, &mcp.TextContent{Text: "two"}},
			want:    "one\ntwo",
		},
		{
			name:    "skips parts that are not text",
			content: []mcp.Content{image, &mcp.TextContent{Text: "the answer"}},
			want:    "the answer",
		},
		{
			name:    "reports a response with no text",
			content: []mcp.Content{image},
			want:    "MCP tool response content type not supported",
		},
		{
			name:    "joins the parts of a tool error",
			content: []mcp.Content{&mcp.TextContent{Text: "not found"}, &mcp.TextContent{Text: "check the ID"}},
			isError: true,
			want:    "not found\ncheck the ID",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mgr := newSdkMcpServer(t, nil, func() *mcp.CallToolResult {
				return &mcp.CallToolResult{Content: tt.content, IsError: tt.isError}
			})

			resp, err := callSdkTool(t, mgr)

			require.NoError(t, err)
			if tt.isError {
				require.Equal(t, tt.want, resp.GetError())
				require.Empty(t, resp.GetResponse())
			} else {
				require.Equal(t, tt.want, resp.GetResponse())
				require.Empty(t, resp.GetError())
			}
		})
	}
}

func TestManager_CallTool_responseTooLarge(t *testing.T) {
	tests := []struct {
		name string
		opts *mcp.StreamableHTTPOptions
	}{
		{name: "SSE response"},
		{name: "JSON response", opts: &mcp.StreamableHTTPOptions{JSONResponse: true}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var calls atomic.Int32
			mgr := newSdkMcpServer(t, tt.opts, func() *mcp.CallToolResult {
				text := "small"
				if calls.Add(1) == 1 {
					text = strings.Repeat("a", ActionResponseBodyLimit)
				}
				return &mcp.CallToolResult{Content: []mcp.Content{&mcp.TextContent{Text: text}}}
			})

			_, err := callSdkTool(t, mgr)
			require.ErrorIs(t, err, errResponseBodySizeLimitExceeded)

			resp, err := callSdkTool(t, mgr)
			require.NoError(t, err, "the session should survive an oversized response")
			require.Equal(t, "small", resp.GetResponse())
		})
	}
}

func TestManager_CallTool_concurrentCallsOnOneServer(t *testing.T) {
	const calls = 3

	// Every call is held until all of them have reached the server, so the
	// test only passes if one session carries the calls concurrently.
	var arrived sync.WaitGroup
	arrived.Add(calls)
	allArrived := make(chan struct{})
	go func() {
		arrived.Wait()
		close(allArrived)
	}()

	mcpServer := setupMockMcpServerWithCallHandler(t, "", []mcpTool{
		{Name: "slow_tool", Description: "A slow tool"},
	}, func(_ string, args map[string]any) (string, bool, error) {
		arrived.Done()
		select {
		case <-allArrived:
		case <-time.After(5 * time.Second):
			return "", false, errors.New("calls were not concurrent")
		}
		return fmt.Sprint(args["n"]), false, nil
	})

	servers := map[string]api.McpServerConfig{
		"test-server": {URL: mcpServer.URL, Headers: map[string]string{}},
	}
	mgr, err := newMcpManager(nil, newSession(httptest.NewRequest("GET", "/test", nil)), servers, 0, false)
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, mgr.Close()) })

	results := make([]*pb.ClientEvent, calls)
	errs := make([]error, calls)

	var wg sync.WaitGroup
	for i := range calls {
		wg.Go(func() {
			action := &pb.Action{
				RequestID: fmt.Sprint(i),
				Action: &pb.Action_RunMCPTool{
					RunMCPTool: &pb.RunMCPTool{Name: "test-server_slow_tool", Args: fmt.Sprintf(`{"n": "%d"}`, i)},
				},
			}

			results[i], errs[i] = mgr.CallTool(context.Background(), action)
		})
	}
	wg.Wait()

	for i := range calls {
		require.NoError(t, errs[i])
		require.Equal(t, fmt.Sprint(i), results[i].GetActionResponse().GetPlainTextResponse().Response)
	}
}

// setupMcpServerClosingFirstCall answers the first tools/call with a plain-text
// 401, which closes the client's connection. acceptSession runs for the nth
// session a client opens, and rejects it by returning false.
func setupMcpServerClosingFirstCall(t *testing.T, acceptSession func(n int32) bool) (*httptest.Server, *atomic.Int32) {
	var sessions atomic.Int32
	var closed atomic.Bool

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if !assert.NoError(t, err) {
			return
		}
		r.Body = io.NopCloser(bytes.NewReader(body))

		switch {
		case bytes.Contains(body, []byte(`"method":"initialize"`)) && !acceptSession(sessions.Add(1)):
			http.Error(w, "Unavailable", http.StatusServiceUnavailable)
		case bytes.Contains(body, []byte(`"method":"tools/call"`)) && closed.CompareAndSwap(false, true):
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
		default:
			handleMcpRequest(t, w, r, "", []mcpTool{{Name: "echo"}}, func(_ string, args map[string]any) (string, bool, error) {
				return fmt.Sprint(args["n"]), false, nil
			})
		}
	}))
	t.Cleanup(server.Close)

	return server, &sessions
}

func acceptAllSessions(int32) bool { return true }

func newReconnectTestManager(t *testing.T, serverURL string, reconnect bool) *manager {
	servers := map[string]api.McpServerConfig{"test-server": {URL: serverURL}}
	mgr, err := newMcpManager(nil, newSession(httptest.NewRequest("GET", "/test", nil)), servers, 0, reconnect)
	require.NoError(t, err)

	return mgr
}

func callEcho(mgr *manager, n int) (*pb.ClientEvent, error) {
	return mgr.CallTool(context.Background(), &pb.Action{
		RequestID: fmt.Sprint(n),
		Action: &pb.Action_RunMCPTool{
			RunMCPTool: &pb.RunMCPTool{Name: "test-server_echo", Args: fmt.Sprintf(`{"n": "%d"}`, n)},
		},
	})
}

func TestManager_CallTool_reconnectsAfterConnectionCloses(t *testing.T) {
	server, sessions := setupMcpServerClosingFirstCall(t, acceptAllSessions)
	mgr := newReconnectTestManager(t, server.URL, true)
	t.Cleanup(func() { require.NoError(t, mgr.Close()) })

	reconnects := counterVecValue(t, mcpReconnectsTotal, mcpServerCatalog, mcpOutcomeOK)
	calls := counterVecValue(t, mcpCallsTotal, mcpServerCatalog, mcpOutcomeOK)

	_, err := callEcho(mgr, 1)
	require.Error(t, err)
	require.NotErrorIs(t, err, mcp.ErrConnectionClosed, "a call the server received is not retried")

	result, err := callEcho(mgr, 2)
	require.NoError(t, err)
	require.Equal(t, "2", result.GetActionResponse().GetPlainTextResponse().Response)

	require.Equal(t, int32(2), sessions.Load())
	require.InDelta(t, reconnects+1, counterVecValue(t, mcpReconnectsTotal, mcpServerCatalog, mcpOutcomeOK), 0)
	require.InDelta(t, calls+1, counterVecValue(t, mcpCallsTotal, mcpServerCatalog, mcpOutcomeOK), 0)
}

func TestManager_CallTool_doesNotReconnectWhenDisabled(t *testing.T) {
	server, sessions := setupMcpServerClosingFirstCall(t, acceptAllSessions)
	mgr := newReconnectTestManager(t, server.URL, false)
	t.Cleanup(func() { require.NoError(t, mgr.Close()) })

	_, err := callEcho(mgr, 1)
	require.Error(t, err)

	_, err = callEcho(mgr, 2)
	require.ErrorIs(t, err, mcp.ErrConnectionClosed)
	require.Equal(t, int32(1), sessions.Load())
}

func TestManager_CallTool_concurrentCallsShareOneReconnect(t *testing.T) {
	const calls = 5

	var started sync.WaitGroup
	started.Add(calls)

	// The new session is held until every call has started, so the calls overlap the reconnect.
	server, sessions := setupMcpServerClosingFirstCall(t, func(n int32) bool {
		if n == 2 {
			started.Wait()
		}
		return true
	})
	mgr := newReconnectTestManager(t, server.URL, true)
	t.Cleanup(func() { require.NoError(t, mgr.Close()) })

	_, err := callEcho(mgr, 0)
	require.Error(t, err)

	reconnects := counterVecValue(t, mcpReconnectsTotal, mcpServerCatalog, mcpOutcomeOK)
	results := make([]*pb.ClientEvent, calls)
	errs := make([]error, calls)

	var wg sync.WaitGroup
	for i := range calls {
		wg.Go(func() {
			started.Done()
			results[i], errs[i] = callEcho(mgr, i)
		})
	}
	wg.Wait()

	for i := range calls {
		require.NoError(t, errs[i])
		require.Equal(t, fmt.Sprint(i), results[i].GetActionResponse().GetPlainTextResponse().Response)
	}
	require.Equal(t, int32(2), sessions.Load())
	require.InDelta(t, reconnects+1, counterVecValue(t, mcpReconnectsTotal, mcpServerCatalog, mcpOutcomeOK), 0)
}

func TestManager_CallTool_failedReconnect(t *testing.T) {
	server, sessions := setupMcpServerClosingFirstCall(t, func(n int32) bool { return n != 2 })
	mgr := newReconnectTestManager(t, server.URL, true)
	t.Cleanup(func() { require.NoError(t, mgr.Close()) })

	failures := counterVecValue(t, mcpReconnectsTotal, mcpServerCatalog, mcpOutcomeError)

	_, err := callEcho(mgr, 1)
	require.Error(t, err)

	_, err = callEcho(mgr, 2)
	require.ErrorIs(t, err, mcp.ErrConnectionClosed)
	require.ErrorContains(t, err, "reconnect failed")
	require.InDelta(t, failures+1, counterVecValue(t, mcpReconnectsTotal, mcpServerCatalog, mcpOutcomeError), 0)

	result, err := callEcho(mgr, 3)
	require.NoError(t, err, "the next call tries to reconnect again")
	require.Equal(t, "3", result.GetActionResponse().GetPlainTextResponse().Response)
	require.Equal(t, int32(3), sessions.Load())
}

func TestServerSession_reconnect_sharesFailureWithEarlierCalls(t *testing.T) {
	server, sessions := setupMcpServerClosingFirstCall(t, func(n int32) bool { return n == 1 })
	mgr := newReconnectTestManager(t, server.URL, true)
	t.Cleanup(func() { require.NoError(t, mgr.Close()) })

	_, cause := callEcho(mgr, 0)
	require.Error(t, cause)

	s := mgr.serverSessions[0]
	broken := s.current()
	failures := counterVecValue(t, mcpReconnectsTotal, mcpServerCatalog, mcpOutcomeError)

	_, first := s.reconnect(t.Context(), broken, 0, cause)
	require.Error(t, first)

	_, shared := s.reconnect(t.Context(), broken, 0, cause)
	require.Same(t, first, shared, "a call that started before the failure gets its error")
	require.Equal(t, int32(2), sessions.Load())
	require.InDelta(t, failures+1, counterVecValue(t, mcpReconnectsTotal, mcpServerCatalog, mcpOutcomeError), 0)

	_, err := s.reconnect(t.Context(), broken, 1, cause)
	require.Error(t, err)
	require.Equal(t, int32(3), sessions.Load(), "a call that started after the failure tries again")
}

func TestManager_CallTool_doesNotReconnectAfterClose(t *testing.T) {
	server, sessions := setupMcpServerClosingFirstCall(t, acceptAllSessions)
	mgr := newReconnectTestManager(t, server.URL, true)
	require.NoError(t, mgr.Close())

	_, err := callEcho(mgr, 1)
	require.ErrorIs(t, err, mcp.ErrConnectionClosed)
	require.Equal(t, int32(1), sessions.Load())
}

func TestManager_Close_stopsReconnectInProgress(t *testing.T) {
	reconnecting := make(chan struct{})
	release := make(chan struct{})
	server, _ := setupMcpServerClosingFirstCall(t, func(n int32) bool {
		if n == 2 {
			close(reconnecting)
			<-release
		}
		return true
	})
	t.Cleanup(func() { close(release) })
	mgr := newReconnectTestManager(t, server.URL, true)

	_, err := callEcho(mgr, 0)
	require.Error(t, err)

	done := make(chan error, 1)
	go func() {
		_, err := callEcho(mgr, 1)
		done <- err
	}()
	<-reconnecting

	start := time.Now()
	require.NoError(t, mgr.Close())
	require.Less(t, time.Since(start), 2*time.Second, "Close waited for the reconnect")
	require.ErrorContains(t, <-done, "reconnect failed")
}

func TestManager_CallTool_canceledCallStopsReconnect(t *testing.T) {
	reconnecting := make(chan struct{})
	release := make(chan struct{})
	server, sessions := setupMcpServerClosingFirstCall(t, func(n int32) bool {
		if n == 2 {
			close(reconnecting)
			<-release
		}
		return true
	})
	t.Cleanup(func() { close(release) })
	mgr := newReconnectTestManager(t, server.URL, true)
	t.Cleanup(func() { require.NoError(t, mgr.Close()) })

	_, cause := callEcho(mgr, 0)
	require.Error(t, cause)

	s := mgr.serverSessions[0]
	broken := s.current()

	ctx, cancel := context.WithCancel(context.Background())
	action := &pb.Action{Action: &pb.Action_RunMCPTool{RunMCPTool: &pb.RunMCPTool{Name: "test-server_echo", Args: `{"n": "1"}`}}}
	done := make(chan error, 1)
	go func() {
		_, err := mgr.CallTool(ctx, action)
		done <- err
	}()
	<-reconnecting
	cancel()

	select {
	case err := <-done:
		require.ErrorIs(t, err, context.Canceled)
		require.ErrorContains(t, err, "reconnect failed")
	case <-time.After(2 * time.Second):
		t.Fatal("the canceled call waited for the reconnect")
	}

	_, err := s.reconnect(t.Context(), broken, 0, cause)
	require.NoError(t, err, "a call that started before the canceled attempt does not get its error")

	result, err := callEcho(mgr, 2)
	require.NoError(t, err)
	require.Equal(t, "2", result.GetActionResponse().GetPlainTextResponse().Response)
	require.Equal(t, int32(3), sessions.Load())
}

func TestManager_CallTool_doesNotReconnectForCanceledCall(t *testing.T) {
	server, sessions := setupMcpServerClosingFirstCall(t, acceptAllSessions)
	mgr := newReconnectTestManager(t, server.URL, true)
	t.Cleanup(func() { require.NoError(t, mgr.Close()) })

	_, err := callEcho(mgr, 0)
	require.Error(t, err)

	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	action := &pb.Action{Action: &pb.Action_RunMCPTool{RunMCPTool: &pb.RunMCPTool{Name: "test-server_echo", Args: `{"n": "1"}`}}}

	// A canceled call can still get ErrConnectionClosed, because the SDK picks at random between the two.
	for range 20 {
		_, err = mgr.CallTool(ctx, action)
		require.Error(t, err)
	}
	require.Equal(t, int32(1), sessions.Load())
}

func TestManager_CallTool_serverClosingErrorCode(t *testing.T) {
	tests := []struct {
		name         string
		closingPing  bool
		wantCalls    int32
		wantSessions int32
	}{
		{name: "ping answered, call not sent again", wantCalls: 1, wantSessions: 1},
		{name: "ping also closing, call sent only once more", closingPing: true, wantCalls: 2, wantSessions: 2},
	}

	for _, tt := range tests {
		for _, code := range []int{-32003, -32004} {
			t.Run(fmt.Sprintf("%s/%d", tt.name, code), func(t *testing.T) {
				server, sessions, calls := setupMcpServerAnsweringClosingCode(t, code, tt.closingPing)
				mgr := newReconnectTestManager(t, server.URL, true)
				t.Cleanup(func() { require.NoError(t, mgr.Close()) })

				_, err := callEcho(mgr, 1)

				require.ErrorContains(t, err, "closing")
				require.Equal(t, tt.wantCalls, calls.Load())
				require.Equal(t, tt.wantSessions, sessions.Load())
			})
		}
	}
}

func setupMcpServerAnsweringClosingCode(t *testing.T, code int, closingPing bool) (server *httptest.Server, sessions, calls *atomic.Int32) {
	sessions, calls = new(atomic.Int32), new(atomic.Int32)
	server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if !assert.NoError(t, err) {
			return
		}
		r.Body = io.NopCloser(bytes.NewReader(body))

		var msg struct {
			ID     json.RawMessage `json:"id"`
			Method string          `json:"method"`
		}
		_ = json.Unmarshal(body, &msg)

		closing := fmt.Sprintf(`{"jsonrpc":"2.0","id":%s,"error":{"code":%d,"message":"closing"}}`, msg.ID, code)
		switch msg.Method {
		case "ping":
			w.Header().Set("Content-Type", "application/json")
			if closingPing {
				fmt.Fprint(w, closing)
			} else {
				fmt.Fprintf(w, `{"jsonrpc":"2.0","id":%s,"result":{}}`, msg.ID)
			}
		case "tools/call":
			calls.Add(1)
			w.Header().Set("Content-Type", "application/json")
			fmt.Fprint(w, closing)
		default:
			if bytes.Contains(body, []byte(`"method":"initialize"`)) {
				sessions.Add(1)
			}
			handleMcpRequest(t, w, r, "", []mcpTool{{Name: "echo"}}, nil)
		}
	}))
	t.Cleanup(server.Close)

	return server, sessions, calls
}

func TestServerSession_connectWithin_stopsWaitingAtTimeout(t *testing.T) {
	release := make(chan struct{})
	var initialized atomic.Bool
	// The session ID makes the SDK send a DELETE after the failed Connect, which also stalls.
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if initialized.CompareAndSwap(false, true) {
			w.Header().Set("Mcp-Session-Id", "stalled")
			handleMcpRequest(t, w, r, "", nil, nil)
			return
		}
		<-release
	}))
	t.Cleanup(server.Close)
	t.Cleanup(func() { close(release) })

	s := &serverSession{
		name: "test-server",
		cfg:  api.McpServerConfig{URL: server.URL},
		sess: newSession(httptest.NewRequest("GET", "/test", nil)),
	}

	start := time.Now()
	_, err := s.connectWithin(t.Context(), 100*time.Millisecond)

	require.ErrorIs(t, err, context.DeadlineExceeded)
	require.Less(t, time.Since(start), 2*time.Second, "the SDK's cleanup must not hold the caller")
}

func TestServerSession_connectWithin_returnsPanicAsError(t *testing.T) {
	s := &serverSession{name: gitlabServerName, sess: newSession(httptest.NewRequest("GET", "/test", nil))}

	_, err := s.connectWithin(t.Context(), time.Second)

	require.ErrorContains(t, err, "panic")
}

func TestManager_Close(t *testing.T) {
	t.Run("closes all sessions successfully", func(t *testing.T) {
		mcpServer := setupMockMcpServer(t, "", []mcpTool{
			{Name: "test_tool", Description: "A test tool"},
		})

		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"test-server": {
				URL:     mcpServer.URL,
				Headers: map[string]string{},
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)
		require.NoError(t, err)

		err = mgr.Close()
		assert.NoError(t, err)
	})

	t.Run("returns nil when manager is nil", func(t *testing.T) {
		var mgr *manager
		err := mgr.Close()
		assert.NoError(t, err)
	})
}

// Helper types and functions for testing

type mockTransportFunc struct {
	fn func(*http.Request) (*http.Response, error)
}

func (m *mockTransportFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return m.fn(req)
}

type mcpTool struct {
	Name        string
	Description string
}

func setupMockMcpServer(t *testing.T, name string, tools []mcpTool) *httptest.Server {
	return setupMockMcpServerWithCallHandler(t, name, tools, nil)
}

func setupMockMcpServerWithCallHandler(t *testing.T, name string, tools []mcpTool, callHandler func(string, map[string]any) (string, bool, error)) *httptest.Server {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handleMcpRequest(t, w, r, name, tools, callHandler)
	}))
	t.Cleanup(func() {
		server.Close()
	})
	return server
}

func handleMcpRequest(t *testing.T, w http.ResponseWriter, r *http.Request, name string, tools []mcpTool, callHandler func(string, map[string]any) (string, bool, error)) {
	w.Header().Set("Content-Type", "application/json")

	if name == "gitlab" {
		assert.Contains(t, r.URL.Path, "/api/v4/mcp")
	}
	if name == "orbit" {
		assert.Contains(t, r.URL.Path, "/api/v4/orbit/mcp")
	}

	if r.Method != "POST" {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	var request map[string]any
	err := json.NewDecoder(r.Body).Decode(&request)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	method, ok := request["method"].(string)
	if !ok {
		w.WriteHeader(http.StatusBadRequest)
		return
	}

	switch method {
	case "initialize":
		response := map[string]any{
			"jsonrpc": "2.0",
			"id":      request["id"],
			"result": map[string]any{
				"protocolVersion": "2024-11-05",
				"capabilities":    map[string]any{},
				"serverInfo": map[string]any{
					"name":    "test-server",
					"version": "1.0.0",
				},
			},
		}
		json.NewEncoder(w).Encode(response)

	case "notifications/initialized":
		// MCP spec requires 202 Accepted with no body for JSON-RPC notifications
		// See: https://modelcontextprotocol.io/specification/2025-03-26/basic/transports
		w.WriteHeader(http.StatusAccepted)

	case "tools/list":
		var toolsList []map[string]any
		for _, tool := range tools {
			toolsList = append(toolsList, map[string]any{
				"name":        tool.Name,
				"description": tool.Description,
				"inputSchema": map[string]any{
					"type":       "object",
					"properties": map[string]any{},
				},
			})
		}
		response := map[string]any{
			"jsonrpc": "2.0",
			"id":      request["id"],
			"result": map[string]any{
				"tools": toolsList,
			},
		}
		json.NewEncoder(w).Encode(response)

	case "tools/call":
		if callHandler == nil {
			w.WriteHeader(http.StatusNotImplemented)
			return
		}
		params, ok := request["params"].(map[string]any)
		if !ok {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		name, _ := params["name"].(string)
		arguments, _ := params["arguments"].(map[string]any)
		content, isError, err := callHandler(name, arguments)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			json.NewEncoder(w).Encode(map[string]any{
				"jsonrpc": "2.0",
				"id":      request["id"],
				"error": map[string]any{
					"code":    -32603,
					"message": err.Error(),
				},
			})
			return
		}
		var resultContent []map[string]any
		if content != "" {
			resultContent = append(resultContent, map[string]any{
				"type": "text",
				"text": content,
			})
		}
		response := map[string]any{
			"jsonrpc": "2.0",
			"id":      request["id"],
			"result": map[string]any{
				"content": resultContent,
				"isError": isError,
			},
		}
		json.NewEncoder(w).Encode(response)

	default:
		w.WriteHeader(http.StatusNotImplemented)
	}
}

func TestBuildSession(t *testing.T) {
	t.Run("builds session for a server", func(t *testing.T) {
		mcpServer := setupMockMcpServer(t, "", []mcpTool{})

		req := httptest.NewRequest("GET", "/test", nil)

		serverCfg := api.McpServerConfig{
			URL:     mcpServer.URL,
			Headers: map[string]string{},
		}

		session, err := buildSession(t.Context(), nil, newSession(req), "server-name", serverCfg)

		require.NoError(t, err)
		require.NotNil(t, session)
		assert.Equal(t, "server-name", session.name)
		assert.NotNil(t, session.current())
	})

	t.Run("returns error on connection failure", func(t *testing.T) {
		req := httptest.NewRequest("GET", "/test", nil)

		serverCfg := api.McpServerConfig{
			URL:     "http://localhost:1", // Use a port that's likely to be refused
			Headers: map[string]string{},
		}

		session, err := buildSession(t.Context(), nil, newSession(req), "test-server", serverCfg)

		require.Error(t, err)
		require.Nil(t, session)
	})
}

func TestManager_addTools(t *testing.T) {
	t.Run("successfully builds tools from server", func(t *testing.T) {
		mcpServer := setupMockMcpServer(t, "", []mcpTool{
			{Name: "tool1", Description: "Tool 1"},
			{Name: "tool2", Description: "Tool 2"},
		})

		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"test-server": {
				URL:     mcpServer.URL,
				Headers: map[string]string{},
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)

		require.NoError(t, err)
		require.NotNil(t, mgr)
		assert.Len(t, mgr.tools, 2)
		assert.Equal(t, "test-server_tool1", mgr.tools[0].Name)
		assert.Equal(t, "test-server_tool2", mgr.tools[1].Name)
	})

	t.Run("handles error from ListTools", func(t *testing.T) {
		// Create a server that returns an error for tools/list
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")

			var request map[string]any
			err := json.NewDecoder(r.Body).Decode(&request)
			if err != nil {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			method, ok := request["method"].(string)
			if !ok {
				w.WriteHeader(http.StatusBadRequest)
				return
			}

			switch method {
			case "initialize":
				response := map[string]any{
					"jsonrpc": "2.0",
					"id":      request["id"],
					"result": map[string]any{
						"protocolVersion": "2024-11-05",
						"capabilities":    map[string]any{},
						"serverInfo": map[string]any{
							"name":    "test-server",
							"version": "1.0.0",
						},
					},
				}
				json.NewEncoder(w).Encode(response)
			case "notifications/initialized":
				// MCP spec requires 202 Accepted with no body for JSON-RPC notifications
				// See: https://modelcontextprotocol.io/specification/2025-03-26/basic/transports
				w.WriteHeader(http.StatusAccepted)
			case "tools/list":
				w.WriteHeader(http.StatusInternalServerError)
			}
		}))
		defer server.Close()

		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"test-server": {
				URL:     server.URL,
				Headers: map[string]string{},
				Tools:   &([]string{}),
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)

		require.Error(t, err)
		require.NotNil(t, mgr)
		assert.Contains(t, err.Error(), "failed to list tools")
	})
}

func TestBuildSession_orbitRouting(t *testing.T) {
	testhelper.ConfigureSecret()

	t.Run("routes orbit server to /api/v4/orbit/mcp", func(t *testing.T) {
		mcpServer := setupMockMcpServer(t, "orbit", []mcpTool{
			{Name: "query_graph", Description: "Query the knowledge graph"},
		})

		apiURL, err := url.Parse(mcpServer.URL)
		require.NoError(t, err)

		rails := api.NewAPI(apiURL, "test-version", http.DefaultTransport)
		req := httptest.NewRequest("GET", "/test", nil)

		tools := []string{"query_graph"}
		serverCfg := api.McpServerConfig{
			Headers:          map[string]string{"Authorization": "Bearer test-token"},
			Tools:            &tools,
			PreApprovedTools: &tools,
		}

		session, err := buildSession(t.Context(), rails, newSession(req), "orbit", serverCfg)

		require.NoError(t, err)
		require.NotNil(t, session)
		assert.Equal(t, "orbit", session.name)
	})

	t.Run("routes gitlab server to /api/v4/mcp", func(t *testing.T) {
		mcpServer := setupMockMcpServer(t, "gitlab", []mcpTool{
			{Name: "search", Description: "Search"},
		})

		apiURL, err := url.Parse(mcpServer.URL)
		require.NoError(t, err)

		rails := api.NewAPI(apiURL, "test-version", http.DefaultTransport)
		req := httptest.NewRequest("GET", "/test", nil)

		serverCfg := api.McpServerConfig{
			Headers: map[string]string{"Authorization": "Bearer test-token"},
		}

		session, err := buildSession(t.Context(), rails, newSession(req), "gitlab", serverCfg)

		require.NoError(t, err)
		require.NotNil(t, session)
		assert.Equal(t, "gitlab", session.name)
	})
}

func TestBuildSession_signsInternalRequestsWithWorkhorseJWT(t *testing.T) {
	testhelper.ConfigureSecret()

	for _, serverName := range []string{gitlabServerName, orbitServerName} {
		t.Run(serverName, func(t *testing.T) {
			var jwtHeader string
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				jwtHeader = r.Header.Get(secret.RequestHeader)
				handleMcpRequest(t, w, r, serverName, []mcpTool{{Name: "tool1", Description: "desc"}}, nil)
			}))
			t.Cleanup(server.Close)

			apiURL, err := url.Parse(server.URL)
			require.NoError(t, err)

			rails := api.NewAPI(apiURL, "test-version", http.DefaultTransport)
			req := httptest.NewRequest("GET", "/test", nil)

			session, err := buildSession(t.Context(), rails, newSession(req), serverName, api.McpServerConfig{})
			require.NoError(t, err)
			require.NotNil(t, session)

			assert.NotEmpty(t, jwtHeader)
		})
	}
}

func TestBuildSession_sendsWorkflowIDOnlyToInternalServers(t *testing.T) {
	testhelper.ConfigureSecret()

	tests := []struct {
		serverName string
		want       string
	}{
		{serverName: gitlabServerName, want: "workflow-123"},
		{serverName: orbitServerName, want: "workflow-123"},
		{serverName: "external-server", want: ""},
	}

	for _, tt := range tests {
		t.Run(tt.serverName, func(t *testing.T) {
			var workflowIDHeader string
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				workflowIDHeader = r.Header.Get("X-Gitlab-Duo-Workflow-Id")
				handleMcpRequest(t, w, r, tt.serverName, []mcpTool{{Name: "tool1", Description: "desc"}}, nil)
			}))
			t.Cleanup(server.Close)

			apiURL, err := url.Parse(server.URL)
			require.NoError(t, err)

			rails := api.NewAPI(apiURL, "test-version", http.DefaultTransport)
			req := httptest.NewRequest("GET", "/test", nil)
			sess := newSession(req)
			sess.setWorkflowID("workflow-123")

			session, err := buildSession(t.Context(), rails, sess, tt.serverName, api.McpServerConfig{URL: server.URL})
			require.NoError(t, err)
			require.NotNil(t, session)

			assert.Equal(t, tt.want, workflowIDHeader)
		})
	}
}

func TestNewMcpManager_orbitAndGitlabServers(t *testing.T) {
	testhelper.ConfigureSecret()

	t.Run("initializes both gitlab and orbit servers with correct routing", func(t *testing.T) {
		gitlabServer := setupMockMcpServer(t, "gitlab", []mcpTool{
			{Name: "search", Description: "Search code"},
		})
		orbitServer := setupMockMcpServer(t, "orbit", []mcpTool{
			{Name: "query_graph", Description: "Query the knowledge graph"},
			{Name: "get_graph_schema", Description: "Get the graph schema"},
		})

		// Use a mux to route both gitlab and orbit paths on the same server
		mux := http.NewServeMux()
		mux.HandleFunc("/api/v4/mcp", func(w http.ResponseWriter, r *http.Request) {
			handleMcpRequest(t, w, r, "gitlab", []mcpTool{
				{Name: "search", Description: "Search code"},
			}, nil)
		})
		mux.HandleFunc("/api/v4/orbit/mcp", func(w http.ResponseWriter, r *http.Request) {
			handleMcpRequest(t, w, r, "orbit", []mcpTool{
				{Name: "query_graph", Description: "Query the knowledge graph"},
				{Name: "get_graph_schema", Description: "Get the graph schema"},
			}, nil)
		})
		combinedServer := httptest.NewServer(mux)
		t.Cleanup(func() { combinedServer.Close() })

		combinedURL, err := url.Parse(combinedServer.URL)
		require.NoError(t, err)

		rails := api.NewAPI(combinedURL, "test-version", http.DefaultTransport)
		req := httptest.NewRequest("GET", "/test", nil)

		gitlabTools := []string{"search"}
		orbitTools := []string{"query_graph", "get_graph_schema"}
		servers := map[string]api.McpServerConfig{
			"gitlab": {
				Headers:          map[string]string{"Authorization": "Bearer gitlab-token"},
				Tools:            &gitlabTools,
				PreApprovedTools: &gitlabTools,
				Trusted:          true,
			},
			"orbit": {
				Headers:          map[string]string{"Authorization": "Bearer orbit-token"},
				Tools:            &orbitTools,
				PreApprovedTools: &orbitTools,
			},
		}

		_ = gitlabServer
		_ = orbitServer

		mgr, err := newMcpManager(rails, newSession(req), servers, 0, false)

		require.NoError(t, err)
		require.NotNil(t, mgr)
		assert.Len(t, mgr.tools, 3)

		toolsByName := make(map[string]*pb.McpTool)
		for _, tool := range mgr.tools {
			toolsByName[tool.Name] = tool
		}

		assert.Contains(t, toolsByName, "gitlab_search")
		assert.Contains(t, toolsByName, "orbit_query_graph")
		assert.Contains(t, toolsByName, "orbit_get_graph_schema")

		assert.Len(t, mgr.preApprovedTools, 3)
		assert.Contains(t, mgr.preApprovedTools, "gitlab_search")
		assert.Contains(t, mgr.preApprovedTools, "orbit_query_graph")
		assert.Contains(t, mgr.preApprovedTools, "orbit_get_graph_schema")
	})
}

func TestManager_addTools_propagatesTrustedFlag(t *testing.T) {
	t.Run("sets Trusted on tools from trusted server", func(t *testing.T) {
		mcpServer := setupMockMcpServer(t, "", []mcpTool{
			{Name: "tool1", Description: "Tool 1"},
		})

		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"trusted-server": {
				URL:     mcpServer.URL,
				Headers: map[string]string{},
				Trusted: true,
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)

		require.NoError(t, err)
		require.NotNil(t, mgr)
		require.Len(t, mgr.tools, 1)
		require.NotNil(t, mgr.tools[0].Trusted)
		assert.True(t, *mgr.tools[0].Trusted)
	})

	t.Run("sets Trusted false on tools from untrusted server", func(t *testing.T) {
		mcpServer := setupMockMcpServer(t, "", []mcpTool{
			{Name: "tool1", Description: "Tool 1"},
		})

		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"untrusted-server": {
				URL:     mcpServer.URL,
				Headers: map[string]string{},
				Trusted: false,
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)

		require.NoError(t, err)
		require.NotNil(t, mgr)
		require.Len(t, mgr.tools, 1)
		require.NotNil(t, mgr.tools[0].Trusted)
		assert.False(t, *mgr.tools[0].Trusted)
	})

	t.Run("mixed trusted and untrusted servers", func(t *testing.T) {
		trustedServer := setupMockMcpServer(t, "", []mcpTool{
			{Name: "safe_tool", Description: "Safe tool"},
		})
		untrustedServer := setupMockMcpServer(t, "", []mcpTool{
			{Name: "ext_tool", Description: "External tool"},
		})

		req := httptest.NewRequest("GET", "/test", nil)

		servers := map[string]api.McpServerConfig{
			"internal": {
				URL:     trustedServer.URL,
				Headers: map[string]string{},
				Trusted: true,
			},
			"external": {
				URL:     untrustedServer.URL,
				Headers: map[string]string{},
				Trusted: false,
			},
		}

		mgr, err := newMcpManager(nil, newSession(req), servers, 0, false)

		require.NoError(t, err)
		require.NotNil(t, mgr)
		require.Len(t, mgr.tools, 2)

		toolsByName := make(map[string]*pb.McpTool)
		for _, tool := range mgr.tools {
			toolsByName[tool.Name] = tool
		}

		require.NotNil(t, toolsByName["internal_safe_tool"].Trusted)
		assert.True(t, *toolsByName["internal_safe_tool"].Trusted)

		require.NotNil(t, toolsByName["external_ext_tool"].Trusted)
		assert.False(t, *toolsByName["external_ext_tool"].Trusted)
	})
}

func TestNewMcpManager_SetsUpServersConcurrently(t *testing.T) {
	const serverCount = 2

	// Each server holds its initialize request until every server has
	// received one, which only happens when they are set up concurrently.
	arrived := make(chan struct{}, serverCount)
	allArrived := make(chan struct{})
	go func() {
		for range serverCount {
			select {
			case <-arrived:
			case <-t.Context().Done():
				return
			}
		}
		close(allArrived)
	}()

	newServer := func(tool string) *httptest.Server {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			body, err := io.ReadAll(r.Body)
			if !assert.NoError(t, err) {
				return
			}
			r.Body = io.NopCloser(bytes.NewReader(body))

			if bytes.Contains(body, []byte(`"method":"initialize"`)) {
				select {
				case arrived <- struct{}{}:
				default:
				}

				select {
				case <-allArrived:
				case <-time.After(5 * time.Second):
					w.WriteHeader(http.StatusServiceUnavailable)
					return
				}
			}

			handleMcpRequest(t, w, r, "", []mcpTool{{Name: tool}}, nil)
		}))
		t.Cleanup(server.Close)
		return server
	}

	servers := map[string]api.McpServerConfig{
		"server1": {URL: newServer("tool1").URL},
		"server2": {URL: newServer("tool2").URL},
	}

	mgr, err := newMcpManager(nil, newSession(httptest.NewRequest("GET", "/test", nil)), servers, 0, false)

	require.NoError(t, err)
	require.Len(t, mgr.tools, serverCount)
	require.NoError(t, mgr.Close())
}

func TestNewMcpManager_OrdersToolsByServerName(t *testing.T) {
	servers := map[string]api.McpServerConfig{
		"b-server": {URL: setupMockMcpServer(t, "", []mcpTool{{Name: "tool"}}).URL},
		"a-server": {URL: setupMockMcpServer(t, "", []mcpTool{{Name: "tool"}}).URL},
		"c-server": {URL: setupMockMcpServer(t, "", []mcpTool{{Name: "tool"}}).URL},
	}

	// Map iteration order is random, so repeat to catch an order that
	// depends on it.
	for range 5 {
		mgr, err := newMcpManager(nil, newSession(httptest.NewRequest("GET", "/test", nil)), servers, 0, false)
		require.NoError(t, err)

		var names []string
		for _, tool := range mgr.Tools() {
			names = append(names, tool.Name)
		}
		require.Equal(t, []string{"a-server_tool", "b-server_tool", "c-server_tool"}, names)
		require.NoError(t, mgr.Close())
	}
}

func TestNewMcpManager_ReusesConnectionsToExternalServers(t *testing.T) {
	var connections atomic.Int32

	server := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handleMcpRequest(t, w, r, "", []mcpTool{{Name: "tool"}}, nil)
	}))
	server.Config.ConnState = func(_ net.Conn, state http.ConnState) {
		if state == http.StateNew {
			connections.Add(1)
		}
	}
	server.Start()
	t.Cleanup(server.Close)

	servers := map[string]api.McpServerConfig{"external": {URL: server.URL}}

	for range 2 {
		mgr, err := newMcpManager(nil, newSession(httptest.NewRequest("GET", "/test", nil)), servers, 0, false)
		require.NoError(t, err)
		require.NoError(t, mgr.Close())
	}

	require.Equal(t, int32(1), connections.Load(), "the second session should reuse the first session's connection")
}

func TestManager_CallTool_keepsServerAfterRejectedCall(t *testing.T) {
	var sawDiscover atomic.Bool
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if !assert.NoError(t, err) {
			return
		}
		r.Body = io.NopCloser(bytes.NewReader(body))

		var msg struct {
			ID     json.RawMessage `json:"id"`
			Method string          `json:"method"`
		}
		_ = json.Unmarshal(body, &msg)
		if msg.Method == "server/discover" {
			sawDiscover.Store(true)
		}

		if bytes.Contains(body, []byte(`"name":"denied"`)) {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusForbidden)
			fmt.Fprintf(w, `{"jsonrpc":"2.0","id":%s,"error":{"code":-32002,"message":"Tool denied by policy"}}`, msg.ID)
			return
		}

		handleMcpRequest(t, w, r, "", []mcpTool{{Name: "allowed"}, {Name: "denied"}}, func(string, map[string]any) (string, bool, error) {
			return "ok", false, nil
		})
	}))
	t.Cleanup(server.Close)

	servers := map[string]api.McpServerConfig{"test-server": {URL: server.URL}}
	mgr, err := newMcpManager(nil, newSession(httptest.NewRequest("GET", "/test", nil)), servers, 0, false)
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, mgr.Close()) })

	call := func(tool string) (*pb.ClientEvent, error) {
		action := &pb.Action{Action: &pb.Action_RunMCPTool{RunMCPTool: &pb.RunMCPTool{Name: "test-server_" + tool, Args: `{}`}}}
		return mgr.CallTool(context.Background(), action)
	}

	_, err = call("denied")
	require.ErrorContains(t, err, "Tool denied by policy")

	res, err := call("allowed")
	require.NoError(t, err)
	require.Equal(t, "ok", res.GetActionResponse().GetPlainTextResponse().GetResponse())

	require.False(t, sawDiscover.Load(), "the pinned protocol version skips server/discover")
}

// newStalledMcpServer stalls every request from the first call to method on; abandoned closes when the client cancels that call.
func newStalledMcpServer(t *testing.T, method string) (server *httptest.Server, abandoned, deleted <-chan struct{}, release func()) {
	releaseCh := make(chan struct{})
	release = sync.OnceFunc(func() { close(releaseCh) })
	abandonedCh := make(chan struct{})
	deletedCh := make(chan struct{})
	markDeleted := sync.OnceFunc(func() { close(deletedCh) })
	var stalled atomic.Bool

	server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodDelete {
			markDeleted()
		}

		body, err := io.ReadAll(r.Body)
		if !assert.NoError(t, err) {
			return
		}
		r.Body = io.NopCloser(bytes.NewReader(body))

		if stalled.Load() || bytes.Contains(body, []byte(`"method":"`+method+`"`)) {
			first := !stalled.Swap(true)
			select {
			case <-r.Context().Done():
				if first {
					close(abandonedCh)
				}
			case <-releaseCh:
			}
			return
		}

		w.Header().Set("Mcp-Session-Id", "stalled")
		handleMcpRequest(t, w, r, "", []mcpTool{{Name: "tool"}}, nil)
	}))
	t.Cleanup(server.Close)
	t.Cleanup(release)

	return server, abandonedCh, deletedCh, release
}

func TestNewMcpManager_SetupTimeout(t *testing.T) {
	tests := []struct {
		method string
		// Only a server that connected before the deadline leaves a session for Workhorse to close.
		connects bool
	}{
		{method: "initialize"},
		{method: "tools/list", connects: true},
	}

	for _, tt := range tests {
		t.Run("skips a server that stalls on "+tt.method, func(t *testing.T) {
			stalledServer, abandoned, deleted, release := newStalledMcpServer(t, tt.method)
			workingServer := setupMockMcpServerWithCallHandler(t, "", []mcpTool{{Name: "tool"}}, func(string, map[string]any) (string, bool, error) {
				return "ok", false, nil
			})
			// "stalled" sorts first, so the working server is awaited after the deadline has passed.
			servers := map[string]api.McpServerConfig{
				"stalled": {URL: stalledServer.URL},
				"working": {URL: workingServer.URL},
			}
			failures := counterVecValue(t, mcpInitFailuresTotal, mcpServerCatalog)

			start := time.Now()
			mgr, err := newMcpManager(nil, newSession(httptest.NewRequest("GET", "/test", nil)), servers, 100*time.Millisecond, false)
			elapsed := time.Since(start)
			t.Cleanup(func() { require.NoError(t, mgr.Close()) })

			require.ErrorIs(t, err, context.DeadlineExceeded)
			require.Less(t, elapsed, 2*time.Second)
			require.InDelta(t, failures+1, counterVecValue(t, mcpInitFailuresTotal, mcpServerCatalog), 0)
			require.Len(t, mgr.Tools(), 1)
			require.Equal(t, "working_tool", mgr.Tools()[0].Name)
			requireClosed(t, abandoned, "the stalled request was not canceled at the deadline")

			if tt.connects {
				release()
				requireClosed(t, deleted, "the abandoned session was not closed")
			}

			action := &pb.Action{Action: &pb.Action_RunMCPTool{RunMCPTool: &pb.RunMCPTool{Name: "working_tool", Args: `{}`}}}
			res, err := mgr.CallTool(context.Background(), action)
			require.NoError(t, err)
			require.Equal(t, "ok", res.GetActionResponse().GetPlainTextResponse().GetResponse())
		})
	}

	t.Run("waits for a slow server without a deadline", func(t *testing.T) {
		server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			time.Sleep(200 * time.Millisecond)
			handleMcpRequest(t, w, r, "", []mcpTool{{Name: "tool"}}, nil)
		}))
		t.Cleanup(server.Close)

		mgr, err := newMcpManager(nil, newSession(httptest.NewRequest("GET", "/test", nil)), map[string]api.McpServerConfig{"slow": {URL: server.URL}}, 0, false)

		require.NoError(t, err)
		require.Len(t, mgr.Tools(), 1)
		require.NoError(t, mgr.Close())
	})
}

func requireClosed(t *testing.T, ch <-chan struct{}, msg string) {
	t.Helper()

	select {
	case <-ch:
	case <-time.After(2 * time.Second):
		require.Fail(t, msg)
	}
}
