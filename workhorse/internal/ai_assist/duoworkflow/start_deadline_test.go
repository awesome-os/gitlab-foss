package duoworkflow

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"github.com/stretchr/testify/require"

	pb "gitlab.com/gitlab-org/modelops/applied-ml/code-suggestions/ai-assist/clients/gopb/contract"

	"gitlab.com/gitlab-org/gitlab/workhorse/internal/testhelper"
)

const startDeadlineCloseError = "websocket: close 1001 (going away): start deadline exceeded"

// dialWithStartDeadline connects a WebSocket client to a handler whose start
// deadline is shortened to deadline.
func dialWithStartDeadline(t *testing.T, grpcServer *testServer, deadline time.Duration) *websocket.Conn {
	t.Helper()

	testhelper.ConfigureSecret()

	apiServer, apiClient := setupAPIServer(t, `{
		"DuoWorkflow": {
			"Service": {
				"URI": "`+grpcServer.Addr+`",
				"Headers": {"Authorization": "Bearer test"},
				"Secure": false
			}
		}
	}`)
	t.Cleanup(apiServer.Close)

	handler := NewHandler(apiClient, initRdb(t), http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {}), "")
	handler.startDeadline = deadline

	httpServer := httptest.NewServer(handler.Build())
	t.Cleanup(httpServer.Close)

	wsConn, resp, err := websocket.DefaultDialer.Dial("ws"+strings.TrimPrefix(httpServer.URL, "http")+"/duo", nil)
	if resp != nil {
		_ = resp.Body.Close()
	}
	require.NoError(t, err)
	t.Cleanup(func() { _ = wsConn.Close() })

	return wsConn
}

// drainUntilClosed stands in for a Duo Workflow Service that never answers:
// it reads client events until workhorse ends the stream.
func drainUntilClosed(stream pb.DuoWorkflow_ExecuteWorkflowServer) error {
	for {
		if _, err := stream.Recv(); err != nil {
			return nil
		}
	}
}

func TestHandler_StartDeadline_ClosesConnectionWithoutStartRequest(t *testing.T) {
	grpcServer := setupTestServer(t)
	grpcServer.execWorkflowHandler = drainUntilClosed

	wsConn := dialWithStartDeadline(t, grpcServer, 50*time.Millisecond)

	_, _, err := wsConn.ReadMessage()
	require.EqualError(t, err, startDeadlineCloseError)
}

func TestHandler_StartDeadline_HeartbeatFirstIsRefused(t *testing.T) {
	grpcServer := setupTestServer(t)
	grpcServer.execWorkflowHandler = drainUntilClosed

	wsConn := dialWithStartDeadline(t, grpcServer, time.Hour)

	require.NoError(t, wsConn.WriteMessage(websocket.BinaryMessage, []byte(`{"heartbeat": {"timestamp": 1}}`)))

	_, _, err := wsConn.ReadMessage()
	require.EqualError(t, err, "websocket: close 4400: workflow not found")
}

func TestHandler_StartDeadline_StartRequestKeepsConnectionOpen(t *testing.T) {
	const deadline = 50 * time.Millisecond

	grpcServer := setupTestServer(t)
	grpcServer.execWorkflowHandler = func(stream pb.DuoWorkflow_ExecuteWorkflowServer) error {
		if _, err := stream.Recv(); err != nil {
			return err
		}

		// Answer only once the deadline is long past.
		time.Sleep(4 * deadline)

		return stream.Send(&pb.Action{
			Action: &pb.Action_RunCommand{RunCommand: &pb.RunCommandAction{Program: "ls"}},
		})
	}

	wsConn := dialWithStartDeadline(t, grpcServer, deadline)

	require.NoError(t, wsConn.WriteMessage(websocket.BinaryMessage, []byte(`{"startRequest": {"workflowID": "123", "goal": "create workflow"}}`)))

	_, response, err := wsConn.ReadMessage()
	require.NoError(t, err)
	require.Contains(t, string(response), `"runCommand"`)
}
