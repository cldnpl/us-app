package main

import (
	"encoding/json"
	"log"
	"os"

	httpapi "github.com/sharepact/us/internal/http"
)

func main() {
	if err := json.NewEncoder(os.Stdout).Encode(httpapi.CatalogStrings()); err != nil {
		log.Fatal(err)
	}
}
