package b8gpipe

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"reflect"
	"testing"
)

func TestVerifyPolisHeaders_ValidIdentity(t *testing.T) {
	h := http.Header{}
	h.Set(HeaderPolisSubject, "saml:alice@acme.corp")
	h.Set(HeaderPolisTenant, "acme-enterprise")
	h.Set(HeaderPolisRoles, "maintainer, developer , security-auditor")
	h.Set(HeaderB8GLocality, LocalityLanPeer)

	id, err := VerifyPolisHeaders(h)
	if err != nil {
		t.Fatalf("VerifyPolisHeaders unexpected error: %v", err)
	}

	if id.Subject != "saml:alice@acme.corp" {
		t.Errorf("Subject = %q, want %q", id.Subject, "saml:alice@acme.corp")
	}
	if id.Tenant != "acme-enterprise" {
		t.Errorf("Tenant = %q, want %q", id.Tenant, "acme-enterprise")
	}
	wantRoles := []string{"maintainer", "developer", "security-auditor"}
	if !reflect.DeepEqual(id.Roles, wantRoles) {
		t.Errorf("Roles = %v, want %v", id.Roles, wantRoles)
	}
	if id.Locality != LocalityLanPeer {
		t.Errorf("Locality = %q, want %q", id.Locality, LocalityLanPeer)
	}
	if !id.PrivateData {
		t.Errorf("PrivateData = false, want true")
	}
	if id.Provider != OryPolisProvider || id.Version != OryPolisVersion {
		t.Errorf("Provider/Version = (%q, %q), want (%q, %q)", id.Provider, id.Version, OryPolisProvider, OryPolisVersion)
	}
}

func TestVerifyPolisHeaders_MissingHeadersRejected(t *testing.T) {
	if _, err := VerifyPolisHeaders(nil); !errors.Is(err, ErrMissingPolisHeader) {
		t.Fatalf("nil headers error = %v, want ErrMissingPolisHeader", err)
	}

	cases := []struct {
		name  string
		omit  string
		empty bool
	}{
		{name: "missing subject", omit: HeaderPolisSubject},
		{name: "missing tenant", omit: HeaderPolisTenant},
		{name: "missing roles", omit: HeaderPolisRoles},
		{name: "empty roles", omit: HeaderPolisRoles, empty: true},
		{name: "missing locality", omit: HeaderB8GLocality},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			h := http.Header{}
			h.Set(HeaderPolisSubject, "oidc:bob@acme.corp")
			h.Set(HeaderPolisTenant, "acme")
			h.Set(HeaderPolisRoles, "developer")
			h.Set(HeaderB8GLocality, LocalityHost)

			if tc.empty {
				h.Set(tc.omit, " ,  ")
			} else {
				h.Del(tc.omit)
			}

			if _, err := VerifyPolisHeaders(h); !errors.Is(err, ErrMissingPolisHeader) {
				t.Fatalf("VerifyPolisHeaders error = %v, want ErrMissingPolisHeader", err)
			}
		})
	}
}

func TestVerifyPolisHeaders_LocalityBoundaryEnforcement(t *testing.T) {
	allowedLocalities := []string{LocalityHost, LocalityLocal, LocalityLanPeer}
	for _, loc := range allowedLocalities {
		h := http.Header{}
		h.Set(HeaderPolisSubject, "scim:carol@acme.corp")
		h.Set(HeaderPolisTenant, "acme")
		h.Set(HeaderPolisRoles, "owner")
		h.Set(HeaderB8GLocality, loc)

		id, err := VerifyPolisHeaders(h)
		if err != nil {
			t.Errorf("locality %q should be allowed for private data, got error: %v", loc, err)
		} else if id.Locality != loc {
			t.Errorf("id.Locality = %q, want %q", id.Locality, loc)
		}
	}

	blockedLocalities := []string{LocalityRegional, LocalityPublicCloud, LocalityGlobal}
	for _, loc := range blockedLocalities {
		h := http.Header{}
		h.Set(HeaderPolisSubject, "scim:carol@acme.corp")
		h.Set(HeaderPolisTenant, "acme")
		h.Set(HeaderPolisRoles, "owner")
		h.Set(HeaderB8GLocality, loc)

		if _, err := VerifyPolisHeaders(h); !errors.Is(err, ErrLocalityBoundaryViolation) {
			t.Errorf("locality %q should fail with ErrLocalityBoundaryViolation, got %v", loc, err)
		}
	}

	// Unknown locality is rejected as invalid.
	hUnknown := http.Header{}
	hUnknown.Set(HeaderPolisSubject, "scim:carol@acme.corp")
	hUnknown.Set(HeaderPolisTenant, "acme")
	hUnknown.Set(HeaderPolisRoles, "owner")
	hUnknown.Set(HeaderB8GLocality, "interplanetary")
	if _, err := VerifyPolisHeaders(hUnknown); !errors.Is(err, ErrInvalidLocality) {
		t.Errorf("unknown locality error = %v, want ErrInvalidLocality", err)
	}
}

func TestVerifyPolisHeadersWithSecret(t *testing.T) {
	secret := []byte("awesome-os-ory-polis-hmac-secret")
	h := http.Header{}
	h.Set(HeaderPolisSubject, "oidc:dana@acme.corp")
	h.Set(HeaderPolisTenant, "acme")
	h.Set(HeaderPolisRoles, "admin,maintainer")
	h.Set(HeaderB8GLocality, LocalityHost)
	h.Set(HeaderPolisSignature, SignPolisHeaders(h, secret))

	id, err := VerifyPolisHeadersWithSecret(h, secret)
	if err != nil {
		t.Fatalf("VerifyPolisHeadersWithSecret failed: %v", err)
	}
	if id.Subject != "oidc:dana@acme.corp" {
		t.Fatalf("unexpected subject %q", id.Subject)
	}

	// Tampering with roles invalidates the signature.
	h.Set(HeaderPolisRoles, "superadmin")
	if _, err := VerifyPolisHeadersWithSecret(h, secret); !errors.Is(err, ErrInvalidPolisSignature) {
		t.Fatalf("expected ErrInvalidPolisSignature after tampering, got %v", err)
	}
}

func TestPolisAuthMiddleware(t *testing.T) {
	var captured *OryPolisIdentity
	handler := PolisAuthMiddleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, ok := IdentityFromContext(r.Context())
		if !ok {
			t.Errorf("expected identity in request context")
		}
		captured = id
		w.WriteHeader(http.StatusOK)
	}))

	// Valid request -> 200 OK
	req := httptest.NewRequest(http.MethodGet, "/api/v4/projects", nil)
	req.Header.Set(HeaderPolisSubject, "saml:eve@acme.corp")
	req.Header.Set(HeaderPolisTenant, "acme")
	req.Header.Set(HeaderPolisRoles, "developer")
	req.Header.Set(HeaderB8GLocality, LocalityLanPeer)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("valid request status = %d, want 200", rec.Code)
	}
	if captured == nil || captured.Subject != "saml:eve@acme.corp" {
		t.Fatalf("unexpected captured identity: %+v", captured)
	}

	// Locality violation -> 403 Forbidden
	reqForbidden := httptest.NewRequest(http.MethodGet, "/api/v4/projects", nil)
	reqForbidden.Header.Set(HeaderPolisSubject, "saml:eve@acme.corp")
	reqForbidden.Header.Set(HeaderPolisTenant, "acme")
	reqForbidden.Header.Set(HeaderPolisRoles, "developer")
	reqForbidden.Header.Set(HeaderB8GLocality, LocalityPublicCloud)
	recForbidden := httptest.NewRecorder()
	handler.ServeHTTP(recForbidden, reqForbidden)
	if recForbidden.Code != http.StatusForbidden {
		t.Fatalf("locality violation status = %d, want 403", recForbidden.Code)
	}

	// Missing header -> 401 Unauthorized
	reqUnauth := httptest.NewRequest(http.MethodGet, "/api/v4/projects", nil)
	recUnauth := httptest.NewRecorder()
	handler.ServeHTTP(recUnauth, reqUnauth)
	if recUnauth.Code != http.StatusUnauthorized {
		t.Fatalf("missing header status = %d, want 401", recUnauth.Code)
	}
}
