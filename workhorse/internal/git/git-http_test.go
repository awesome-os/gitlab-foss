package git

import (
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/require"

	"gitlab.com/gitlab-org/gitlab/workhorse/internal/api"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/helper"
	"gitlab.com/gitlab-org/gitlab/workhorse/internal/testhelper"
)

func TestRepoPreAuthorizeHandler_RootNamespace(t *testing.T) {
	testhelper.ConfigureSecret()

	for _, namespace := range []string{"my-group", ""} {
		t.Run("namespace="+namespace, func(t *testing.T) {
			ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				if namespace != "" {
					w.Header().Set("X-Gitlab-Namespace", namespace)
				}
				w.Header().Set("Content-Type", api.ResponseContentType)
				io.WriteString(w, "{}")
			}))
			defer ts.Close()

			a := api.NewAPI(helper.URLMustParse(ts.URL), "123", http.DefaultTransport)
			handler := repoPreAuthorizeHandler(a, func(w http.ResponseWriter, _ *http.Request, _ *api.Response) {
				w.WriteHeader(http.StatusOK)
			})

			w := httptest.NewRecorder()
			r := httptest.NewRequest("GET", "/group/project.git/info/refs?service=git-upload-pack", nil)
			handler.ServeHTTP(w, r)

			require.Equal(t, http.StatusOK, w.Code)
			require.Equal(t, namespace, w.Header().Get("X-Gitlab-Namespace"))
		})
	}
}
