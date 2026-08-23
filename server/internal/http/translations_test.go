package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/sharepact/us/internal/config"
)

func TestGetTranslationsIsPublicAndReturnsEmbeddedStrings(t *testing.T) {
	router := NewRouter(Deps{Config: &config.Config{AllowedOrigins: []string{"*"}}})
	req := httptest.NewRequest(http.MethodGet, "/v1/translations/es", nil)
	res := httptest.NewRecorder()
	router.ServeHTTP(res, req)

	if res.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", res.Code, res.Body.String())
	}
	if got := res.Header().Get("Cache-Control"); got == "" {
		t.Fatal("missing Cache-Control header")
	}
	var body translationsResponse
	if err := json.Unmarshal(res.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if body.Lang != "es" || body.Strings["Cancel"] != "Cancelar" {
		t.Fatalf("unexpected translation response: %#v", body)
	}
}
