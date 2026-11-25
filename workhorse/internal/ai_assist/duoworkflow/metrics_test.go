package duoworkflow

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/testutil"
	"github.com/stretchr/testify/require"
	pb "gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/clients/gopb/contract"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"gitlab.com/gitlab-org/gitlab/workhorse/internal/api"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/testhelper"
)

// counterValue returns the current float64 value of a prometheus.Counter.
func counterValue(t *testing.T, c prometheus.Counter) float64 {
	t.Helper()
	return testutil.ToFloat64(c)
}

// counterVecValue returns the current float64 value of a single label combination
// on a *prometheus.CounterVec.
func counterVecValue(t *testing.T, cv *prometheus.CounterVec, labels ...string) float64 {
	t.Helper()
	return testutil.ToFloat64(cv.WithLabelValues(labels...))
}

// newTestStreamManager returns a streamManager wrapping the given mock stream.
// The gRPC client is real but never dialed, since grpc.NewClient connects
// lazily, so that Close behaves like it does in production.
func newTestStreamManager(t *testing.T, wf workflowStream) *streamManager {
	t.Helper()

	client, err := NewClient(&api.DuoWorkflowServiceConfig{URI: "localhost:1"}, "test-agent", "")
	require.NoError(t, err)

	return &streamManager{
		wf:      wf,
		client:  client,
		session: newSession(httptest.NewRequest(http.MethodGet, "/", nil)),
	}
}

// testDuoWorkflowConfig builds a minimal *api.DuoWorkflow pointing at the given
// in-process test gRPC server (insecure, no auth headers needed).
func testDuoWorkflowConfig(server *testServer) *api.DuoWorkflow {
	return &api.DuoWorkflow{
		Service: &api.DuoWorkflowServiceConfig{
			URI:    server.Addr,
			Secure: false,
		},
	}
}

// dialTestHandler starts a full HTTP/WebSocket server backed by the given handler
// and returns an open WebSocket connection to it.
func dialTestHandler(t *testing.T, h http.Handler) *websocket.Conn {
	t.Helper()
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/"
	conn, resp, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if resp != nil {
		_ = resp.Body.Close()
	}
	require.NoError(t, err)
	t.Cleanup(func() { _ = conn.Close() })
	return conn
}

// setupHandlerWithGRPC wires together the API server and the gRPC test server and
// returns a ready-to-use Handler.Build() http.Handler.
func setupHandlerWithGRPC(t *testing.T, grpcServer *testServer) http.Handler {
	t.Helper()
	responseBody := fmt.Sprintf(`{
		"DuoWorkflow": {
			"Service": {
				"URI": "%s",
				"Headers": {},
				"Secure": false
			}
		}
	}`, grpcServer.Addr)

	apiServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		writeRailsAnswer(t, w, r, responseBody)
	}))
	t.Cleanup(apiServer.Close)

	apiURL, err := url.Parse(apiServer.URL)
	require.NoError(t, err)
	apiClient := api.NewAPI(apiURL, "test-version", http.DefaultTransport)

	return NewHandler(apiClient, initRdb(t), http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {}), "").Build()
}

func TestConnectionsOpen(t *testing.T) {
	testhelper.ConfigureSecret()

	grpcServer := setupTestServer(t)
	started := make(chan struct{})
	released := make(chan struct{})
	grpcServer.execWorkflowHandler = func(_ pb.DuoWorkflow_ExecuteWorkflowServer) error {
		close(started)
		<-released
		return nil
	}
	handler := setupHandlerWithGRPC(t, grpcServer)

	openWebSocketConns := func() float64 {
		return testutil.ToFloat64(connectionsOpen.WithLabelValues(transportWebSocket))
	}

	before := openWebSocketConns()
	sessionLabels := map[string]string{"transport": transportWebSocket}
	sessionsBefore := histogramSampleCount(t, "gitlab_workhorse_duo_workflow_session_duration_seconds", sessionLabels)

	conn := dialTestHandler(t, handler)

	require.Eventually(t, func() bool {
		return openWebSocketConns() == before+1
	}, 5*time.Second, time.Millisecond,
		"connectionsOpen should increment while a connection is open")

	// The runner only starts once the client sends its StartRequest.
	payload, err := marshaler.Marshal(&pb.ClientEvent{
		Response: &pb.ClientEvent_StartRequest{
			StartRequest: &pb.StartWorkflowRequest{WorkflowID: "1", Goal: "test goal"},
		},
	})
	require.NoError(t, err)
	require.NoError(t, conn.WriteMessage(websocket.TextMessage, payload))
	select {
	case <-started:
	case <-time.After(5 * time.Second):
		t.Fatal("the runner did not open a Duo Workflow Service stream")
	}
	require.Eventually(t, func() bool {
		return openWebSocketConns() == before+1
	}, 5*time.Second, time.Millisecond,
		"connectionsOpen should count the runner once it takes over")

	close(released)
	require.NoError(t, conn.Close())

	require.Eventually(t, func() bool {
		return openWebSocketConns() == before
	}, 15*time.Second, time.Millisecond,
		"connectionsOpen should return to its previous value once the connection closes")
	require.Equal(t, sessionsBefore+1, histogramSampleCount(t, "gitlab_workhorse_duo_workflow_session_duration_seconds", sessionLabels),
		"the session duration should be observed once the runner is closed")
}

// histogramSampleCount returns the number of observations across every series
// of the histogram that carries the given labels.
func histogramSampleCount(t *testing.T, name string, labels map[string]string) uint64 {
	t.Helper()

	families, err := prometheus.DefaultGatherer.Gather()
	require.NoError(t, err)

	var total uint64
	for _, f := range families {
		if f.GetName() != name {
			continue
		}
		for _, m := range f.GetMetric() {
			matched := 0
			for _, l := range m.GetLabel() {
				if v, ok := labels[l.GetName()]; ok && v == l.GetValue() {
					matched++
				}
			}
			if matched == len(labels) {
				total += m.GetHistogram().GetSampleCount()
			}
		}
	}

	return total
}

func TestMcpServerLabel(t *testing.T) {
	for _, name := range []string{gitlabServerName, orbitServerName, slackServerName} {
		require.Equal(t, name, mcpServerLabel(name))
	}

	require.Equal(t, mcpServerCatalog, mcpServerLabel("my_company_jira"))
}

func TestHTTPMethodLabel(t *testing.T) {
	for _, method := range []string{http.MethodGet, http.MethodHead, http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete, http.MethodOptions} {
		require.Equal(t, method, httpMethodLabel(method))
	}

	for _, method := range []string{"get", "PROPFIND", "X-ANYTHING", ""} {
		require.Equal(t, httpMethodOther, httpMethodLabel(method))
	}
}

// TestSessionsTotal verifies that sessionsTotal increments exactly once for each
// successful ExecuteWorkflow stream opened by newStreamManager.
func TestSessionsTotal(t *testing.T) {
	server := setupTestServer(t)

	before := counterValue(t, sessionsTotal)

	r := httptest.NewRequest(http.MethodGet, "/", nil)
	sm, err := newStreamManager(newSession(r), testDuoWorkflowConfig(server))
	require.NoError(t, err)
	defer sm.Close() //nolint:errcheck

	require.InDelta(t, before+1, counterValue(t, sessionsTotal), 0,
		"sessionsTotal should increment by 1 when ExecuteWorkflow succeeds")
}

// TestSessionErrorsTotal verifies that sessionErrorsTotal is labeled with the
// correct gRPC code for each kind of receive error, and is not incremented for
// the expected io.EOF.
func TestSessionErrorsTotal(t *testing.T) {
	tests := []struct {
		name         string
		recvError    error
		wantCode     string
		wantIncrease bool
	}{
		{
			name:         "Internal gRPC error",
			recvError:    status.Error(codes.Internal, "internal server error"),
			wantCode:     codes.Internal.String(),
			wantIncrease: true,
		},
		{
			name:         "Unavailable gRPC error",
			recvError:    status.Error(codes.Unavailable, "service unavailable"),
			wantCode:     codes.Unavailable.String(),
			wantIncrease: true,
		},
		{
			name:         "ResourceExhausted quota exceeded",
			recvError:    status.Error(codes.ResourceExhausted, "USAGE_QUOTA_EXCEEDED"),
			wantCode:     codes.ResourceExhausted.String(),
			wantIncrease: true,
		},
		{
			name:         "DeadlineExceeded gRPC error",
			recvError:    status.Error(codes.DeadlineExceeded, "deadline exceeded"),
			wantCode:     codes.DeadlineExceeded.String(),
			wantIncrease: true,
		},
		{
			name:         "plain Go error maps to Unknown",
			recvError:    io.ErrUnexpectedEOF,
			wantCode:     codes.Unknown.String(),
			wantIncrease: true,
		},
		{
			name:         "EOF does not increment",
			recvError:    io.EOF,
			wantIncrease: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.wantIncrease {
				// No runner wired the stream manager up, so nothing recorded a
				// cause and the teardown reports as unsolicited.
				wantReason := teardownUnsolicited.String()
				beforeCode := counterVecValue(t, sessionErrorsTotal, tt.wantCode, wantReason)

				sm := newTestStreamManager(t, &mockWorkflowStream{recvError: tt.recvError})
				_, _ = sm.Recv()

				require.InDelta(t, beforeCode+1,
					counterVecValue(t, sessionErrorsTotal, tt.wantCode, wantReason), 0,
					"sessionErrorsTotal{grpc_code=%q} should increment by 1", tt.wantCode)
			} else {
				// io.EOF is a normal workflow termination — the total number of
				// reported time series must not grow. We use CollectAndCount to
				// avoid calling WithLabelValues, which would itself create a new
				// series as a side-effect.
				seriesBefore := testutil.CollectAndCount(sessionErrorsTotal)

				sm := newTestStreamManager(t, &mockWorkflowStream{recvError: tt.recvError})
				_, _ = sm.Recv()

				require.Equal(t, seriesBefore, testutil.CollectAndCount(sessionErrorsTotal),
					"sessionErrorsTotal must not create new series for EOF")
			}
		})
	}
}

// TestSessionErrorsTotal_teardownReason verifies that the teardown_reason label
// carries the cause workhorse recorded for the session.
func TestSessionErrorsTotal_teardownReason(t *testing.T) {
	for _, reason := range []teardownReason{
		teardownUnsolicited,
		teardownClientNormalClose,
		teardownClientPongTimeout,
		teardownClientKeepaliveFailed,
		teardownClientReadFailed,
		teardownWorkhorseShutdown,
		teardownRunLimit,
	} {
		t.Run(reason.String(), func(t *testing.T) {
			code := codes.Unavailable.String()

			sm := newTestStreamManager(t, &mockWorkflowStream{
				recvError: status.Error(codes.Unavailable, "service unavailable"),
			})
			sm.teardownReason = func() teardownReason { return reason }

			before := counterVecValue(t, sessionErrorsTotal, code, reason.String())
			_, _ = sm.Recv()

			require.InDelta(t, before+1,
				counterVecValue(t, sessionErrorsTotal, code, reason.String()), 0,
				"sessionErrorsTotal{grpc_code=%q, teardown_reason=%q} should increment by 1",
				code, reason.String())
		})
	}
}

// TestClientDisconnectReason pins the mapping from the StopWorkflowRequest
// reasons wsManager.ReadError actually produces onto teardown categories, so
// the two cannot drift apart.
func TestClientDisconnectReason(t *testing.T) {
	tests := []struct {
		name       string
		readErr    error
		wantOK     bool
		wantReason teardownReason
	}{
		{
			name:       "normal closure",
			readErr:    &websocket.CloseError{Code: websocket.CloseNormalClosure},
			wantOK:     true,
			wantReason: teardownClientNormalClose,
		},
		{
			name:       "going away",
			readErr:    &websocket.CloseError{Code: websocket.CloseGoingAway},
			wantOK:     true,
			wantReason: teardownClientNormalClose,
		},
		{
			name:       "pong timeout",
			readErr:    &net.OpError{Err: &timeoutError{}},
			wantOK:     true,
			wantReason: teardownClientPongTimeout,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			w := &wsManager{}
			reason, ok := w.ReadError(tt.readErr)
			require.Equal(t, tt.wantOK, ok)
			require.Equal(t, tt.wantReason, clientDisconnectReason(reason))
		})
	}

	t.Run("abnormal closure is not an orderly disconnect", func(t *testing.T) {
		w := &wsManager{}
		reason, ok := w.ReadError(&websocket.CloseError{Code: websocket.CloseAbnormalClosure})
		require.False(t, ok, "an abnormal closure sends no stop request")
		require.Equal(t, teardownClientReadFailed, clientDisconnectReason(reason))
	})

	t.Run("detached run limit", func(t *testing.T) {
		reason, ok := newDetachedTransport(nil, time.Minute).ReadError(errRunLimitReached)
		require.True(t, ok)
		require.Equal(t, teardownRunLimit, clientDisconnectReason(reason))
	})
}

// sessionErrorsByReason sums sessionErrorsTotal across every grpc_code for one
// teardown_reason. The gRPC code a teardown ends up with is racy on the paths
// that send no stop request, so assertions key on the reason instead.
func sessionErrorsByReason(t *testing.T, reason string) float64 {
	t.Helper()

	families, err := prometheus.DefaultGatherer.Gather()
	require.NoError(t, err)

	var total float64
	for _, f := range families {
		if f.GetName() != "gitlab_workhorse_duo_workflow_session_errors_total" {
			continue
		}
		for _, m := range f.GetMetric() {
			for _, l := range m.GetLabel() {
				if l.GetName() == "teardown_reason" && l.GetValue() == reason {
					total += m.GetCounter().GetValue()
				}
			}
		}
	}

	return total
}

// TestSessionErrorsTotal_clientDisconnect drives the whole stack -- a real
// WebSocket into the real handler, runner and gRPC client, against a Duo
// Workflow Service stand-in -- and checks which teardown_reason each way of
// losing the client produces.
func TestSessionErrorsTotal_clientDisconnect(t *testing.T) {
	tests := []struct {
		name string
		// disconnect ends the client side of the connection.
		disconnect func(t *testing.T, conn *websocket.Conn)
		wantReason teardownReason
	}{
		{
			name: "browser tab closed sends a normal close frame",
			disconnect: func(t *testing.T, conn *websocket.Conn) {
				closeWebSocket(t, conn, websocket.CloseNormalClosure)
			},
			wantReason: teardownClientNormalClose,
		},
		{
			name: "client navigating away sends going away",
			disconnect: func(t *testing.T, conn *websocket.Conn) {
				closeWebSocket(t, conn, websocket.CloseGoingAway)
			},
			wantReason: teardownClientNormalClose,
		},
		{
			name: "connection dropped without a close frame",
			disconnect: func(t *testing.T, conn *websocket.Conn) {
				// Killing the TCP socket leaves no close frame, so the read
				// fails as an abnormal closure (1006) and no stop is sent.
				require.NoError(t, conn.UnderlyingConn().Close())
			},
			wantReason: teardownClientReadFailed,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testhelper.ConfigureSecret()

			// Stand in for DWS: hold the stream open, and acknowledge a stop the
			// way DWS does, by tearing the stream down with Unavailable.
			grpcServer := setupTestServer(t)
			grpcServer.execWorkflowHandler = func(stream pb.DuoWorkflow_ExecuteWorkflowServer) error {
				for {
					event, err := stream.Recv()
					if err != nil {
						return err
					}
					if event.GetStopWorkflow() != nil {
						return status.Error(codes.Unavailable, "workflow stopped")
					}
				}
			}

			conn := dialTestHandler(t, setupHandlerWithGRPC(t, grpcServer))

			// Start a flow, so the session is mid-stream when the client goes away.
			payload, err := marshaler.Marshal(&pb.ClientEvent{
				Response: &pb.ClientEvent_StartRequest{
					StartRequest: &pb.StartWorkflowRequest{
						WorkflowID: "1",
						Goal:       "test goal",
					},
				},
			})
			require.NoError(t, err)
			require.NoError(t, conn.WriteMessage(websocket.TextMessage, payload))

			before := sessionErrorsByReason(t, tt.wantReason.String())

			tt.disconnect(t, conn)

			require.Eventually(t, func() bool {
				return sessionErrorsByReason(t, tt.wantReason.String()) >= before+1
			}, 20*time.Second, 10*time.Millisecond,
				"sessionErrorsTotal{teardown_reason=%q} should increment once the client goes away",
				tt.wantReason.String())
		})
	}
}

// closeWebSocket sends a close frame with the given code and then closes the
// connection, the way a browser does when a tab or panel goes away.
func closeWebSocket(t *testing.T, conn *websocket.Conn, code int) {
	t.Helper()

	require.NoError(t, conn.WriteControl(
		websocket.CloseMessage,
		websocket.FormatCloseMessage(code, ""),
		time.Now().Add(5*time.Second),
	))
	require.NoError(t, conn.Close())
}

// histogramStats returns the observation count and the sum across every series
// of the histogram that carries the given labels.
func histogramStats(t *testing.T, name string, labels map[string]string) (count uint64, sum float64) {
	t.Helper()

	families, err := prometheus.DefaultGatherer.Gather()
	require.NoError(t, err)

	for _, f := range families {
		if f.GetName() != name {
			continue
		}
		for _, m := range f.GetMetric() {
			if matchesLabels(m.GetLabel(), labels) {
				count += m.GetHistogram().GetSampleCount()
				sum += m.GetHistogram().GetSampleSum()
			}
		}
	}

	return count, sum
}

// matchesLabels reports whether pairs carry every one of labels.
func matchesLabels[L interface {
	GetName() string
	GetValue() string
}](pairs []L, labels map[string]string) bool {
	matched := 0
	for _, l := range pairs {
		if v, ok := labels[l.GetName()]; ok && v == l.GetValue() {
			matched++
		}
	}

	return matched == len(labels)
}

// histogramBucketBounds returns the bucket upper bounds of the first series of
// the named histogram that carries labels.
func histogramBucketBounds(t *testing.T, name string, labels map[string]string) []float64 {
	t.Helper()

	families, err := prometheus.DefaultGatherer.Gather()
	require.NoError(t, err)

	for _, f := range families {
		if f.GetName() != name {
			continue
		}
		for _, m := range f.GetMetric() {
			if !matchesLabels(m.GetLabel(), labels) {
				continue
			}

			var bounds []float64
			for _, b := range m.GetHistogram().GetBucket() {
				bounds = append(bounds, b.GetUpperBound())
			}
			return bounds
		}
	}

	t.Fatalf("no series for %s %v", name, labels)
	return nil
}

// requireClientMessageSize checks that size was observed on the size histogram
// under the given transport and event type, relative to the before snapshot.
func requireClientMessageSize(t *testing.T, labels map[string]string, beforeCount uint64, beforeSum float64, wantMessages int, wantBytes int) {
	t.Helper()

	count, sum := histogramStats(t, "gitlab_workhorse_duo_workflow_client_message_size_bytes", labels)
	require.Equal(t, beforeCount+uint64(wantMessages), count, "messages observed for %v", labels)
	require.InDelta(t, beforeSum+float64(wantBytes), sum, 0.5, "bytes observed for %v", labels)
}

// peakSnapshot records the peak histograms of one transport, so a test can
// assert on what a single connection added.
type peakSnapshot struct {
	messagesCount map[string]uint64
	messagesSum   map[string]float64
	bytesCount    map[string]uint64
	bytesSum      map[string]float64
}

func snapshotPeaks(t *testing.T, transport string) peakSnapshot {
	t.Helper()

	s := peakSnapshot{
		messagesCount: map[string]uint64{},
		messagesSum:   map[string]float64{},
		bytesCount:    map[string]uint64{},
		bytesSum:      map[string]float64{},
	}

	for _, w := range trafficWindows {
		labels := map[string]string{"transport": transport, "window": w.label}
		s.messagesCount[w.label], s.messagesSum[w.label] = histogramStats(t, "gitlab_workhorse_duo_workflow_client_peak_messages", labels)
		s.bytesCount[w.label], s.bytesSum[w.label] = histogramStats(t, "gitlab_workhorse_duo_workflow_client_peak_bytes", labels)
	}

	return s
}

// requirePeaksObserved checks that every window got exactly one new observation
// since the before snapshot, holding the wanted peaks.
func requirePeaksObserved(t *testing.T, transport string, before peakSnapshot, wantMessages, wantBytes map[string]int) {
	t.Helper()

	after := snapshotPeaks(t, transport)

	for _, w := range trafficWindows {
		require.Equal(t, before.messagesCount[w.label]+1, after.messagesCount[w.label], "peak messages observed once for window %s", w.label)
		require.Equal(t, before.bytesCount[w.label]+1, after.bytesCount[w.label], "peak bytes observed once for window %s", w.label)
		require.InDelta(t, float64(wantMessages[w.label]), after.messagesSum[w.label]-before.messagesSum[w.label], 0.5, "peak messages for window %s", w.label)
		require.InDelta(t, float64(wantBytes[w.label]), after.bytesSum[w.label]-before.bytesSum[w.label], 0.5, "peak bytes for window %s", w.label)
	}
}

// requirePeaksUnchanged checks that no peak was observed since the snapshot.
func requirePeaksUnchanged(t *testing.T, transport string, before peakSnapshot) {
	t.Helper()

	after := snapshotPeaks(t, transport)
	require.Equal(t, before, after, "peaks are only observed when the connection closes")
}

func TestClientTraffic_peaks(t *testing.T) {
	now := time.Unix(1_000_000, 0)
	clock := func() time.Time { return now }

	traffic := newClientTrafficWithClock("test_peaks", clock)
	start := now

	// Offsets from the start of the connection, and raw sizes.
	script := []struct {
		at   time.Duration
		size int
	}{
		{0, 100},
		{500 * time.Millisecond, 200},
		{900 * time.Millisecond, 300},
		{1200 * time.Millisecond, 50},
		{9500 * time.Millisecond, 10},
		{10500 * time.Millisecond, 20},
		{10600 * time.Millisecond, 30},
		{59900 * time.Millisecond, 1},
		{60 * time.Second, 5},
	}

	before := snapshotPeaks(t, "test_peaks")

	for _, m := range script {
		now = start.Add(m.at)
		traffic.record(m.size, "heartbeat")
	}

	requirePeaksUnchanged(t, "test_peaks", before)

	traffic.finish()

	requirePeaksObserved(t, "test_peaks", before,
		// 1s: the first window holds three messages. 10s: the first holds
		// five. 60s: the first holds eight, the second only the last.
		map[string]int{"1s": 3, "10s": 5, "60s": 8},
		map[string]int{"1s": 600, "10s": 660, "60s": 711},
	)

	traffic.finish()

	requirePeaksObserved(t, "test_peaks", before,
		map[string]int{"1s": 3, "10s": 5, "60s": 8},
		map[string]int{"1s": 600, "10s": 660, "60s": 711},
	)
}

func TestClientTraffic_idleConnectionObservesZeroPeaks(t *testing.T) {
	traffic := newClientTrafficWithClock("test_idle", time.Now)
	before := snapshotPeaks(t, "test_idle")

	traffic.finish()

	requirePeaksObserved(t, "test_idle", before,
		map[string]int{"1s": 0, "10s": 0, "60s": 0},
		map[string]int{"1s": 0, "10s": 0, "60s": 0},
	)
}

func TestClientTraffic_recordsSizeByEventType(t *testing.T) {
	traffic := newClientTraffic("test_sizes")

	heartbeat := map[string]string{"transport": "test_sizes", "event_type": "heartbeat"}
	invalid := map[string]string{"transport": "test_sizes", "event_type": eventTypeInvalid}

	traffic.record(300, "heartbeat")
	traffic.record(1_000_000, eventTypeInvalid)
	traffic.record(20, "heartbeat")

	count, sum := histogramStats(t, "gitlab_workhorse_duo_workflow_client_message_size_bytes", heartbeat)
	require.Equal(t, uint64(2), count)
	require.InDelta(t, 320, sum, 0.5)

	count, sum = histogramStats(t, "gitlab_workhorse_duo_workflow_client_message_size_bytes", invalid)
	require.Equal(t, uint64(1), count)
	require.InDelta(t, 1_000_000, sum, 0.5)
}

func TestClientTrafficBuckets(t *testing.T) {
	traffic := newClientTraffic("test_buckets")
	traffic.record(1, "heartbeat")
	traffic.finish()

	require.Equal(t, prometheus.ExponentialBuckets(256, 4, 8),
		histogramBucketBounds(t, "gitlab_workhorse_duo_workflow_client_message_size_bytes", map[string]string{"transport": "test_buckets"}))
	require.Equal(t, []float64{1, 2, 5, 10, 20, 50, 100, 200, 500, 1000},
		histogramBucketBounds(t, "gitlab_workhorse_duo_workflow_client_peak_messages", map[string]string{"transport": "test_buckets", "window": "1s"}))
	require.Equal(t, prometheus.ExponentialBuckets(1024, 4, 10),
		histogramBucketBounds(t, "gitlab_workhorse_duo_workflow_client_peak_bytes", map[string]string{"transport": "test_buckets", "window": "1s"}))
}

// testTrafficTransport keeps the transport tests' observations apart from those
// of connections other tests leave closing in the background.
const testTrafficTransport = "test_transport"

func TestTransportsLabelTheirTraffic(t *testing.T) {
	require.Equal(t, transportWebSocket, newWsManager(&mockWebSocketConn{}).traffic.transport)
	require.Equal(t, transportHTTP, newNdjsonTransport(nil, httptest.NewRequest(http.MethodPost, "/", nil), nil).traffic.transport)
	require.Equal(t, transportDetached, newDetachedTransport(nil, time.Minute).traffic.transport)
}
