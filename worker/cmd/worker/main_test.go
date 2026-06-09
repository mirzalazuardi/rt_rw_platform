package main

import (
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHealthEndpoint(t *testing.T) {
	req := httptest.NewRequest("GET", "/health", nil)
	w := httptest.NewRecorder()

	handler(w, req)

	resp := w.Result()
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}

	body, _ := io.ReadAll(resp.Body)
	if strings.TrimSpace(string(body)) != `{"status":"ok"}` {
		t.Errorf("expected {\"status\":\"ok\"}, got %s", body)
	}
}

func TestEnqueueEndpoint(t *testing.T) {
	payload := strings.NewReader(`{"job_type":"pdf","payload":{}}`)
	req := httptest.NewRequest("POST", "/enqueue", payload)
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	handler(w, req)

	resp := w.Result()
	if resp.StatusCode != http.StatusOK {
		t.Errorf("expected 200, got %d", resp.StatusCode)
	}

	body, _ := io.ReadAll(resp.Body)
	if !strings.Contains(string(body), "queued") {
		t.Errorf("expected body to contain 'queued', got %s", body)
	}
}
