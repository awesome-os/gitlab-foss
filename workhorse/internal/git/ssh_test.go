package git

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/sirupsen/logrus"
	logrustest "github.com/sirupsen/logrus/hooks/test"
	"github.com/stretchr/testify/require"
	"gitlab.com/gitlab-org/gitaly/v19/client"
	"gitlab.com/gitlab-org/gitaly/v19/proto/go/gitalypb"
	"google.golang.org/grpc"

	"gitlab.com/gitlab-org/gitlab/workhorse/internal/api"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/helper"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/testhelper"
)

const (
	sshUploadPackPath  = "/ssh-upload-pack"
	sshReceivePackPath = "/ssh-receive-pack"
)

func TestSSHUploadPack(t *testing.T) {
	addr := setupGitalyServer(t)
	a := &api.Response{GitalyServer: api.GitalyServer{Address: addr}}

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handleSSHUploadPack(w, r, a)
	}))
	defer ts.Close()

	buf := &bytes.Buffer{}
	res, err := http.Post(ts.URL+sshUploadPackPath, "", buf)
	require.NoError(t, err)

	err = res.Body.Close()
	require.NoError(t, err)

	require.Equal(t, http.StatusOK, res.StatusCode)
}

func TestSSHUploadPack_GitalyConnection(t *testing.T) {
	a := &api.Response{GitalyServer: api.GitalyServer{Address: "wrong"}}

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handleSSHUploadPack(w, r, a)
	}))
	defer ts.Close()

	buf := &bytes.Buffer{}
	res, err := http.Post(ts.URL+sshUploadPackPath, "", buf)
	require.NoError(t, err)

	err = res.Body.Close()
	require.NoError(t, err)

	require.Equal(t, http.StatusInternalServerError, res.StatusCode)
}

func TestReceivePack(t *testing.T) {
	addr := setupGitalyServer(t)
	a := &api.Response{GitalyServer: api.GitalyServer{Address: addr}}

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handleSSHReceivePack(w, r, a)
	}))
	defer ts.Close()

	buf := &bytes.Buffer{}
	res, err := http.Post(ts.URL+sshReceivePackPath, "", buf)
	require.NoError(t, err)

	err = res.Body.Close()
	require.NoError(t, err)

	require.Equal(t, http.StatusOK, res.StatusCode)
}

func TestReceivePack_GitalyConnection(t *testing.T) {
	a := &api.Response{GitalyServer: api.GitalyServer{Address: "wrong"}}

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handleSSHReceivePack(w, r, a)
	}))
	defer ts.Close()

	buf := &bytes.Buffer{}
	res, err := http.Post(ts.URL+sshReceivePackPath, "", buf)
	require.NoError(t, err)

	err = res.Body.Close()
	require.NoError(t, err)

	require.Equal(t, http.StatusInternalServerError, res.StatusCode)
}

func TestWithFullDuplex_Unsupported(t *testing.T) {
	next := http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Fatal("next handler must not run")
	})

	r := httptest.NewRequest(http.MethodPost, sshReceivePackPath, nil)
	w := httptest.NewRecorder()

	withFullDuplex(next).ServeHTTP(w, r)

	res := w.Result()

	err := res.Body.Close()
	require.NoError(t, err)

	require.Equal(t, http.StatusInternalServerError, res.StatusCode)
}

func TestSSHPreAuthorizeRejection_OpenRequestBody(t *testing.T) {
	testhelper.ConfigureSecret()

	_, addr := startRecordingSSHServer(t)
	preauthResponse, err := json.Marshal(apiResponseFixture(addr))
	require.NoError(t, err)

	tests := []struct {
		name         string
		railsHandler http.HandlerFunc
		header       string
		wantStatus   int
	}{
		{
			name: "preauth rejection",
			railsHandler: func(w http.ResponseWriter, _ *http.Request) {
				w.WriteHeader(http.StatusNotFound)
				_, _ = io.WriteString(w, "not found")
			},
			wantStatus: http.StatusNotFound,
		},
		{
			name: "unsupported framing version",
			railsHandler: func(w http.ResponseWriter, _ *http.Request) {
				w.Header().Set("Content-Type", api.ResponseContentType)
				_, _ = w.Write(preauthResponse)
			},
			header:     "v2",
			wantStatus: http.StatusBadRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rails := httptest.NewServer(tt.railsHandler)
			defer rails.Close()
			a := api.NewAPI(helper.URLMustParse(rails.URL), "123", http.DefaultTransport)

			for _, route := range []struct {
				name    string
				handler http.Handler
				path    string
			}{
				{name: "upload pack", handler: SSHUploadPack(a), path: sshUploadPackPath},
				{name: "receive pack", handler: SSHReceivePack(a), path: sshReceivePackPath},
			} {
				t.Run(route.name, func(t *testing.T) {
					ts := httptest.NewServer(route.handler)
					defer ts.Close()

					// gitlab-shell streams the SSH client's stdin, which stays silent until
					// the client gets a response.
					body, bodyWriter := io.Pipe()
					defer bodyWriter.Close()

					req, err := http.NewRequest(http.MethodPost, ts.URL+route.path, body)
					require.NoError(t, err)
					req.Header.Set("Content-Type", "application/octet-stream")
					if tt.header != "" {
						req.Header.Set(sshBodyFramingHeader, tt.header)
					}

					type result struct {
						status int
						err    error
					}
					done := make(chan result, 1)
					go func() {
						res, err := ts.Client().Do(req)
						if err != nil {
							done <- result{err: err}
							return
						}
						done <- result{status: res.StatusCode, err: res.Body.Close()}
					}()

					select {
					case r := <-done:
						require.NoError(t, r.err)
						require.Equal(t, tt.wantStatus, r.status)
					case <-time.After(5 * time.Second):
						t.Fatal("rejection not sent while the request body was open")
					}
				})
			}
		})
	}
}

func TestSSHBodyFraming(t *testing.T) {
	testhelper.ConfigureSecret()

	for _, route := range []struct {
		name    string
		path    string
		handler func(*api.API) http.Handler
	}{
		{name: "upload pack", path: sshUploadPackPath, handler: SSHUploadPack},
		{name: "receive pack", path: sshReceivePackPath, handler: SSHReceivePack},
	} {
		t.Run(route.name, func(t *testing.T) {
			for _, tt := range []struct {
				name       string
				header     string
				body       []byte
				want       string
				wantStatus int
			}{
				{name: "no header leaves framing bytes intact", body: sshBodyFrame(sshBodyFrameData, "0000"), want: string(sshBodyFrame(sshBodyFrameData, "0000")), wantStatus: http.StatusOK},
				{
					name:   sshBodyFramingV1,
					header: sshBodyFramingV1,
					body: bytes.Join([][]byte{
						sshBodyFrame(sshBodyFrameKeepalive, ""),
						sshBodyFrame(sshBodyFrameData, "00"),
						sshBodyFrame(sshBodyFrameKeepalive, ""),
						sshBodyFrame(sshBodyFrameData, "00"),
						sshBodyFrame(sshBodyFrameKeepalive, ""),
					}, nil),
					want:       "0000",
					wantStatus: http.StatusOK,
				},
				{name: "unknown version", header: "v2", wantStatus: http.StatusBadRequest},
			} {
				t.Run(tt.name, func(t *testing.T) {
					srv, addr := startRecordingSSHServer(t)
					preauthResponse, err := json.Marshal(apiResponseFixture(addr))
					require.NoError(t, err)
					rails := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
						w.Header().Set("Content-Type", api.ResponseContentType)
						_, _ = w.Write(preauthResponse)
					}))
					defer rails.Close()

					a := api.NewAPI(helper.URLMustParse(rails.URL), "123", http.DefaultTransport)
					ts := httptest.NewServer(route.handler(a))
					defer ts.Close()

					req, err := http.NewRequest(http.MethodPost, ts.URL+route.path, bytes.NewReader(tt.body))
					require.NoError(t, err)
					if tt.header != "" {
						req.Header.Set(sshBodyFramingHeader, tt.header)
					}
					res, err := ts.Client().Do(req)
					require.NoError(t, err)
					defer res.Body.Close()
					body, err := io.ReadAll(res.Body)
					require.NoError(t, err)
					require.Equal(t, tt.wantStatus, res.StatusCode)
					if tt.wantStatus != http.StatusOK {
						require.Empty(t, srv.request)
						return
					}
					require.Equal(t, "result", string(body))
					require.Equal(t, tt.want, <-srv.request)
				})
			}
		})
	}
}

func TestSSHBodyFraming_UnknownVersionBeforeGitalyConnection(t *testing.T) {
	for _, route := range []struct {
		name    string
		handler api.HandleFunc
	}{
		{name: "upload pack", handler: handleSSHUploadPack},
		{name: "receive pack", handler: handleSSHReceivePack},
	} {
		t.Run(route.name, func(t *testing.T) {
			r := httptest.NewRequest(http.MethodPost, "/", nil)
			r.Header.Set(sshBodyFramingHeader, "v2")
			w := httptest.NewRecorder()

			route.handler(w, r, &api.Response{GitalyServer: api.GitalyServer{Address: "wrong"}})

			require.Equal(t, http.StatusBadRequest, w.Code)
		})
	}
}

func TestSSHRequestBody_HeaderValidation(t *testing.T) {
	for _, tt := range []struct {
		versions []string
		wantErr  bool
	}{
		{nil, false},
		{[]string{sshBodyFramingV1}, false},
		{[]string{"v2"}, true},
		{[]string{""}, true},
		{[]string{"V1"}, true},
		{[]string{"v1, v2"}, true},
		{[]string{"v1", "v2"}, true},
		{[]string{"v1", "v1"}, true},
	} {
		t.Run(fmt.Sprintf("%q", tt.versions), func(t *testing.T) {
			input := sshBodyFrame(sshBodyFrameData, "0000")
			r := httptest.NewRequest(http.MethodPost, "/", bytes.NewReader(input))
			r.Header[sshBodyFramingHeader] = tt.versions

			body, wrapErr, err := sshRequestBody(r)
			if tt.wantErr {
				require.EqualError(t, err, "unsupported SSH body framing version")
				return
			}
			require.NoError(t, err)

			got, err := io.ReadAll(body)
			require.NoError(t, err)
			if len(tt.versions) == 0 {
				require.Equal(t, r.Body, body)
				require.Equal(t, input, got)
			} else {
				require.Equal(t, "0000", string(got))
			}
			clientErr := errors.New("gitaly failed")
			require.Same(t, clientErr, wrapErr(clientErr))
			require.NoError(t, wrapErr(nil))
		})
	}
}

func TestSSHRequestBody_FrameError(t *testing.T) {
	t.Run("no frame error", func(t *testing.T) {
		r := httptest.NewRequest(http.MethodPost, "/", bytes.NewReader(sshBodyFrame(sshBodyFrameData, "0000")))
		r.Header.Set(sshBodyFramingHeader, sshBodyFramingV1)
		body, wrapErr, err := sshRequestBody(r)
		require.NoError(t, err)
		_, err = io.Copy(io.Discard, body)
		require.NoError(t, err)
		clientErr := errors.New("gitaly failed")
		require.Same(t, clientErr, wrapErr(clientErr))
		require.NoError(t, wrapErr(nil))
	})

	const frameError = "SSH body framing: unknown frame type: 0x03"
	for _, tt := range []struct {
		name        string
		clientError func(error) error
		want        string
	}{
		{
			name:        "no client error",
			clientError: func(error) error { return nil },
		},
		{
			name:        "unrelated error",
			clientError: func(error) error { return errors.New("gitaly failed") },
			want:        "gitaly failed (" + frameError + ")",
		},
		{
			name:        "wrapped frame error",
			clientError: func(err error) error { return fmt.Errorf("copy request: %w", err) },
			want:        "copy request: " + frameError,
		},
	} {
		t.Run(tt.name, func(t *testing.T) {
			r := httptest.NewRequest(http.MethodPost, "/", bytes.NewReader(sshBodyFrameHeader(0x03, 0)))
			r.Header.Set(sshBodyFramingHeader, sshBodyFramingV1)
			body, wrapErr, err := sshRequestBody(r)
			require.NoError(t, err)
			_, frameErr := io.ReadAll(body)
			require.EqualError(t, frameErr, frameError)

			clientErr := tt.clientError(frameErr)
			got := wrapErr(clientErr)
			if tt.want == "" {
				require.NoError(t, got)
				return
			}
			require.EqualError(t, got, tt.want)
			if errors.Is(clientErr, frameErr) {
				require.Same(t, clientErr, got)
			}
		})
	}
}

func TestSSHBodyFraming_InvalidFrame(t *testing.T) {
	hook := logrustest.NewLocal(logrus.StandardLogger())
	defer hook.Reset()

	for _, route := range []struct {
		name    string
		handler api.HandleFunc
	}{
		{name: "upload pack", handler: handleSSHUploadPack},
		{name: "receive pack", handler: handleSSHReceivePack},
	} {
		t.Run(route.name, func(t *testing.T) {
			for _, tt := range []struct {
				name string
				body []byte
				want string
			}{
				{name: "unknown type", body: sshBodyFrameHeader(0x03, 0), want: "SSH body framing: unknown frame type: 0x03"},
				{name: "truncated payload", body: sshBodyFrame(sshBodyFrameData, "hello")[:8], want: "SSH body framing: truncated frame: unexpected EOF"},
			} {
				t.Run(tt.name, func(t *testing.T) {
					hook.Reset()
					_, addr := startRecordingSSHServer(t)
					w := httptest.NewRecorder()
					r := httptest.NewRequest(http.MethodPost, "/", bytes.NewReader(tt.body))
					r.Header.Set(sshBodyFramingHeader, sshBodyFramingV1)

					route.handler(w, r, apiResponseFixture(addr))

					require.Contains(t, w.Body.String(), "Internal Server Error")
					entry := hook.LastEntry()
					require.NotNil(t, entry)
					require.Equal(t, logrus.ErrorLevel, entry.Level)
					loggedError := entry.Data[logrus.ErrorKey].(error).Error()
					require.Equal(t, 1, strings.Count(loggedError, tt.want), loggedError)
				})
			}
		})
	}
}

type recordingSSHServer struct {
	gitalypb.UnimplementedSSHServiceServer
	request chan string
}

func startRecordingSSHServer(t *testing.T) (*recordingSSHServer, string) {
	t.Helper()

	srv := &recordingSSHServer{request: make(chan string, 1)}
	return srv, startGRPCServer(t, func(server *grpc.Server) {
		gitalypb.RegisterSSHServiceServer(server, srv)
	})
}

func (srv *recordingSSHServer) SSHUploadPackWithSidechannel(ctx context.Context, _ *gitalypb.SSHUploadPackWithSidechannelRequest) (*gitalypb.SSHUploadPackWithSidechannelResponse, error) {
	conn, err := client.OpenServerSidechannel(ctx)
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	body, err := io.ReadAll(conn)
	if err != nil {
		return nil, err
	}
	srv.request <- string(body)
	if _, err := io.WriteString(conn, "000b\x01result"); err != nil {
		return nil, err
	}
	return &gitalypb.SSHUploadPackWithSidechannelResponse{}, nil
}

func (srv *recordingSSHServer) SSHReceivePack(stream gitalypb.SSHService_SSHReceivePackServer) error {
	var body bytes.Buffer
	for {
		req, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			return err
		}
		body.Write(req.Stdin)
	}
	srv.request <- body.String()
	return stream.Send(&gitalypb.SSHReceivePackResponse{Stdout: []byte("result")})
}

func setupGitalyServer(t *testing.T) string {
	t.Helper()

	return startSmartHTTPServer(t, &smartHTTPServiceServer{
		handler: func(ctx context.Context, _ *gitalypb.PostUploadPackWithSidechannelRequest) (*gitalypb.PostUploadPackWithSidechannelResponse, error) {
			conn, err := client.OpenServerSidechannel(ctx)
			require.NoError(t, err)

			defer conn.Close()

			_, err = io.Copy(io.Discard, conn)
			require.NoError(t, err)

			return &gitalypb.PostUploadPackWithSidechannelResponse{}, nil
		},
	})
}
