/*
In this file we handle the Git over SSH GitLab-Shell requests
*/

// Package git handles git operations
package git

import (
	"errors"
	"fmt"
	"io"
	"net/http"

	"gitlab.com/gitlab-org/gitaly/v19/proto/go/gitalypb"

	"gitlab.com/gitlab-org/gitaly/v19/client"

	"gitlab.com/gitlab-org/gitlab/workhorse/internal/api"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/gitaly"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/helper/fail"
)

const (
	sshBodyFramingHeader = "Gitlab-Shell-Body-Framing"
	sshBodyFramingV1     = "v1"
)

// SSHUploadPack handles git pull via SSH connection between GitLab-Shell and Gitaly through Workhorse
func SSHUploadPack(a *api.API) http.Handler {
	return withFullDuplex(repoPreAuthorizeHandler(a, handleSSHUploadPack))
}

// SSHReceivePack handles git push via SSH connection between GitLab-Shell and Gitaly through Workhorse
func SSHReceivePack(a *api.API) http.Handler {
	return withFullDuplex(repoPreAuthorizeHandler(a, handleSSHReceivePack))
}

func sshRequestBody(r *http.Request) (io.Reader, func(error) error, error) {
	versions := r.Header.Values(sshBodyFramingHeader)
	if len(versions) == 0 {
		return r.Body, func(err error) error { return err }, nil
	}
	if len(versions) != 1 || versions[0] != sshBodyFramingV1 {
		return nil, nil, errors.New("unsupported SSH body framing version")
	}

	fr := &sshBodyFrameReader{body: r.Body}
	return fr, func(err error) error {
		if err == nil {
			return nil
		}
		if ferr := fr.Err(); ferr != nil && !errors.Is(err, ferr) {
			return fmt.Errorf("%v (%v)", err, ferr)
		}
		return err
	}, nil
}

// withFullDuplex must run before preauth: otherwise net/http drains the request
// body before sending a rejection, and the SSH client's stdin stays silent until
// it gets a response, so the rejection never arrives.
func withFullDuplex(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := http.NewResponseController(w).EnableFullDuplex(); err != nil { //nolint:bodyclose // false-positive https://github.com/timakin/bodyclose/issues/52
			fail.Request(w, r, fmt.Errorf("enabling full duplex: %v", err))
			return
		}

		next.ServeHTTP(w, r)
	})
}

func handleSSHUploadPack(w http.ResponseWriter, r *http.Request, a *api.Response) {
	body, wrapErr, err := sshRequestBody(r)
	if err != nil {
		fail.Request(w, r, err, fail.WithStatus(http.StatusBadRequest))
		return
	}

	conn, err := gitaly.NewConnection(a.GitalyServer)
	if err != nil {
		fail.Request(w, r, fmt.Errorf("look up for gitaly connection: %v", err))
		return
	}

	registry, err := gitaly.Sidechannel()
	if err != nil {
		fail.Request(w, r, fmt.Errorf("sidechannel error: %v", err))
		return
	}

	w.WriteHeader(http.StatusOK)

	request := &gitalypb.SSHUploadPackWithSidechannelRequest{
		Repository:       &a.Repository,
		GitProtocol:      r.Header.Get("Git-Protocol"),
		GitConfigOptions: a.GitConfigOptions,
	}
	out := newFlushWriter(w)
	_, err = client.UploadPackWithSidechannelWithResult(r.Context(), conn, registry, body, out, out, request)
	if err != nil {
		fail.Request(w, r, fmt.Errorf("upload pack failed: %v", wrapErr(err)))
		return
	}
}

func handleSSHReceivePack(w http.ResponseWriter, r *http.Request, a *api.Response) {
	body, wrapErr, err := sshRequestBody(r)
	if err != nil {
		fail.Request(w, r, err, fail.WithStatus(http.StatusBadRequest))
		return
	}

	conn, err := gitaly.NewConnection(a.GitalyServer)
	if err != nil {
		fail.Request(w, r, fmt.Errorf("look up for gitaly connection: %v", err))
		return
	}

	w.WriteHeader(http.StatusOK)

	request := &gitalypb.SSHReceivePackRequest{
		Repository:       &a.Repository,
		GlId:             a.GL_ID,
		GlRepository:     a.GL_REPOSITORY,
		GlUsername:       a.GL_USERNAME,
		GitProtocol:      r.Header.Get("Git-Protocol"),
		GitConfigOptions: a.GitConfigOptions,
	}

	out := newFlushWriter(w)
	_, err = client.ReceivePack(r.Context(), conn, body, out, out, request)
	if err != nil {
		fail.Request(w, r, fmt.Errorf("receive pack failed: %v", wrapErr(err)))
		return
	}
}
