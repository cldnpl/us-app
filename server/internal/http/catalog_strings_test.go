package httpapi

import "testing"

func TestCatalogStringsHaveUniqueTranslationKeys(t *testing.T) {
	seen := map[string]struct{}{}
	for _, item := range CatalogStrings() {
		key := item.ContentType + "|" + item.ContentID + "|" + item.Field
		if _, exists := seen[key]; exists {
			t.Fatalf("duplicate catalog translation key %q", key)
		}
		seen[key] = struct{}{}
	}
	if len(seen) == 0 {
		t.Fatal("catalog string enumeration is empty")
	}
}
