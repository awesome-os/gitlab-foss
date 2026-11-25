package b8gpipe

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"net/http"
	"strings"
)

const (
	// OryPolisProvider identifies the Awesome-OS Ory Polis enterprise SSO delegate.
	OryPolisProvider = "awesome-os/ory-polis"

	// OryPolisVersion is the pinned Awesome-OS Ory Polis release tag.
	OryPolisVersion = "v26.2.0-awesome-os.1"

	// Signed/verified Ory Polis SAML/OIDC/SCIM delegation headers.
	HeaderPolisSubject   = "X-Ory-Polis-Subject"
	HeaderPolisTenant    = "X-Ory-Polis-Tenant"
	HeaderPolisRoles     = "X-Ory-Polis-Roles"
	HeaderPolisSignature = "X-Ory-Polis-Signature"

	// Awesome-OS 7-Tuple locality and private-data boundary headers.
	HeaderB8GLocality    = "X-B8G-Locality"
	HeaderB8GPrivateData = "X-B8G-Private-Data"

	// 7-Tuple locality levels ordered from most local to most public.
	LocalityHost        = "host"
	LocalityLocal       = "local"
	LocalityLanPeer     = "lan-peer"
	LocalityRegional    = "regional"
	LocalityPublicCloud = "public-cloud"
	LocalityGlobal      = "global"
)

var (
	// ErrMissingPolisHeader is returned when a required Ory Polis or locality header is absent or empty.
	ErrMissingPolisHeader = errors.New("b8gpipe: missing required Ory Polis header")

	// ErrInvalidLocality is returned when X-B8G-Locality is not a recognized 7-Tuple locality tier.
	ErrInvalidLocality = errors.New("b8gpipe: invalid X-B8G-Locality value")

	// ErrLocalityBoundaryViolation enforces the 7-Tuple invariant: privateData => locality <= lan-peer.
	ErrLocalityBoundaryViolation = errors.New("b8gpipe: 7-Tuple locality boundary violation (privateData requires locality <= lan-peer)")

	// ErrInvalidPolisSignature is returned when HMAC-SHA256 verification of X-Ory-Polis-Signature fails.
	ErrInvalidPolisSignature = errors.New("b8gpipe: invalid X-Ory-Polis-Signature")
)

var localityRank = map[string]int{
	LocalityHost:        0,
	LocalityLocal:       0,
	LocalityLanPeer:     1,
	LocalityRegional:    2,
	LocalityPublicCloud: 3,
	LocalityGlobal:      4,
}

// OryPolisIdentity represents a verified enterprise SAML/OIDC/SCIM identity
// delegated from awesome-os/ory-polis (v26.2.0-awesome-os.1) to GitLab Workhorse.
type OryPolisIdentity struct {
	Subject     string
	Tenant      string
	Roles       []string
	Locality    string
	PrivateData bool
	Provider    string
	Version     string
}

type polisContextKey struct{}

// LocalityRank returns the numeric rank of a 7-Tuple locality tier and whether it is valid.
func LocalityRank(locality string) (int, bool) {
	rank, ok := localityRank[strings.ToLower(strings.TrimSpace(locality))]
	return rank, ok
}

// IsPrivateDataAllowed reports whether the given locality satisfies locality <= lan-peer.
func IsPrivateDataAllowed(locality string) bool {
	rank, ok := LocalityRank(locality)
	if !ok {
		return false
	}
	return rank <= localityRank[LocalityLanPeer]
}

// VerifyPolisHeaders extracts and validates Ory Polis identity headers and enforces
// the 7-Tuple invariant (privateData => locality <= lan-peer).
func VerifyPolisHeaders(h http.Header) (*OryPolisIdentity, error) {
	if h == nil {
		return nil, fmt.Errorf("%w: headers are nil", ErrMissingPolisHeader)
	}

	subject := strings.TrimSpace(h.Get(HeaderPolisSubject))
	if subject == "" {
		return nil, fmt.Errorf("%w: %s", ErrMissingPolisHeader, HeaderPolisSubject)
	}

	tenant := strings.TrimSpace(h.Get(HeaderPolisTenant))
	if tenant == "" {
		return nil, fmt.Errorf("%w: %s", ErrMissingPolisHeader, HeaderPolisTenant)
	}

	roles := parseRoles(h.Values(HeaderPolisRoles))
	if len(roles) == 0 {
		return nil, fmt.Errorf("%w: %s", ErrMissingPolisHeader, HeaderPolisRoles)
	}

	rawLocality := strings.ToLower(strings.TrimSpace(h.Get(HeaderB8GLocality)))
	if rawLocality == "" {
		return nil, fmt.Errorf("%w: %s", ErrMissingPolisHeader, HeaderB8GLocality)
	}

	rank, ok := LocalityRank(rawLocality)
	if !ok {
		return nil, fmt.Errorf("%w: %q", ErrInvalidLocality, rawLocality)
	}

	// Enterprise SAML/OIDC/SCIM identities carry private data by default unless
	// explicitly marked non-private via X-B8G-Private-Data: false|0.
	privateData := true
	if rawPrivate := strings.ToLower(strings.TrimSpace(h.Get(HeaderB8GPrivateData))); rawPrivate == "false" || rawPrivate == "0" {
		privateData = false
	}

	if privateData && rank > localityRank[LocalityLanPeer] {
		return nil, fmt.Errorf("%w: got %q", ErrLocalityBoundaryViolation, rawLocality)
	}

	return &OryPolisIdentity{
		Subject:     subject,
		Tenant:      tenant,
		Roles:       roles,
		Locality:    rawLocality,
		PrivateData: privateData,
		Provider:    OryPolisProvider,
		Version:     OryPolisVersion,
	}, nil
}

// SignPolisHeaders computes the canonical HMAC-SHA256 hex digest over the Ory Polis
// identity and locality headers for X-Ory-Polis-Signature.
func SignPolisHeaders(h http.Header, secret []byte) string {
	canonical := canonicalPolisPayload(
		strings.TrimSpace(h.Get(HeaderPolisSubject)),
		strings.TrimSpace(h.Get(HeaderPolisTenant)),
		parseRoles(h.Values(HeaderPolisRoles)),
		strings.ToLower(strings.TrimSpace(h.Get(HeaderB8GLocality))),
	)
	mac := hmac.New(sha256.New, secret)
	_, _ = mac.Write([]byte(canonical))
	return hex.EncodeToString(mac.Sum(nil))
}

// VerifyPolisHeadersWithSecret verifies headers via VerifyPolisHeaders and validates
// the HMAC-SHA256 X-Ory-Polis-Signature header using secret.
func VerifyPolisHeadersWithSecret(h http.Header, secret []byte) (*OryPolisIdentity, error) {
	id, err := VerifyPolisHeaders(h)
	if err != nil {
		return nil, err
	}
	sigHex := strings.TrimSpace(h.Get(HeaderPolisSignature))
	if sigHex == "" {
		return nil, fmt.Errorf("%w: %s", ErrMissingPolisHeader, HeaderPolisSignature)
	}
	provided, err := hex.DecodeString(sigHex)
	if err != nil {
		return nil, fmt.Errorf("%w: malformed hex", ErrInvalidPolisSignature)
	}
	expectedHex := SignPolisHeaders(h, secret)
	expected, _ := hex.DecodeString(expectedHex)
	if !hmac.Equal(provided, expected) {
		return nil, ErrInvalidPolisSignature
	}
	return id, nil
}

// IdentityFromContext retrieves the verified OryPolisIdentity stored by PolisAuthMiddleware.
func IdentityFromContext(ctx context.Context) (*OryPolisIdentity, bool) {
	if ctx == nil {
		return nil, false
	}
	id, ok := ctx.Value(polisContextKey{}).(*OryPolisIdentity)
	return id, ok && id != nil
}

// PolisAuthMiddleware validates incoming Ory Polis headers on each HTTP request
// and attaches the verified OryPolisIdentity to the request context.
func PolisAuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id, err := VerifyPolisHeaders(r.Header)
		if err != nil {
			status := http.StatusUnauthorized
			if errors.Is(err, ErrLocalityBoundaryViolation) {
				status = http.StatusForbidden
			}
			http.Error(w, err.Error(), status)
			return
		}
		ctx := context.WithValue(r.Context(), polisContextKey{}, id)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

func parseRoles(values []string) []string {
	var roles []string
	for _, v := range values {
		for _, part := range strings.Split(v, ",") {
			role := strings.TrimSpace(part)
			if role != "" {
				roles = append(roles, role)
			}
		}
	}
	return roles
}

func canonicalPolisPayload(subject, tenant string, roles []string, locality string) string {
	return subject + "\n" + tenant + "\n" + strings.Join(roles, ",") + "\n" + locality
}
