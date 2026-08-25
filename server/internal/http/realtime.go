package httpapi

import (
	"context"
	"encoding/json"
	"net/http"
	"sync"
	"time"

	"nhooyr.io/websocket"
)

// ChangeEvent is deliberately small: the server tells a connected couple that
// something changed, while the app re-fetches its authoritative REST data.
// This avoids duplicating every model and conflict rule over a second protocol.
type ChangeEvent struct {
	Type     string `json:"type"`
	SenderID string `json:"senderId,omitempty"`
}

// ChangeHub fans couple-scoped change signals to live WebSocket connections.
// Railway runs one API process for this app; REST remains the source of truth
// if a reconnect ever misses an in-memory event.
type ChangeHub struct {
	mu          sync.RWMutex
	subscribers map[string]map[chan ChangeEvent]struct{}
}

func NewChangeHub() *ChangeHub {
	return &ChangeHub{subscribers: make(map[string]map[chan ChangeEvent]struct{})}
}

func (h *ChangeHub) Subscribe(coupleID string) (<-chan ChangeEvent, func()) {
	ch := make(chan ChangeEvent, 8)
	h.mu.Lock()
	if h.subscribers[coupleID] == nil {
		h.subscribers[coupleID] = make(map[chan ChangeEvent]struct{})
	}
	h.subscribers[coupleID][ch] = struct{}{}
	h.mu.Unlock()

	return ch, func() {
		h.mu.Lock()
		defer h.mu.Unlock()
		delete(h.subscribers[coupleID], ch)
		if len(h.subscribers[coupleID]) == 0 {
			delete(h.subscribers, coupleID)
		}
	}
}

func (h *ChangeHub) Publish(coupleID string, event ChangeEvent) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for ch := range h.subscribers[coupleID] {
		select {
		case ch <- event:
		default: // A slow client can re-fetch on its next event/reconnect.
		}
	}
}

// GET /v1/events — authenticated, couple-scoped WebSocket change stream.
func (d Deps) handleEvents(w http.ResponseWriter, r *http.Request) {
	couple, userID, ok := d.coupleForRequest(w, r)
	if !ok {
		return
	}
	conn, err := websocket.Accept(w, r, &websocket.AcceptOptions{CompressionMode: websocket.CompressionContextTakeover})
	if err != nil {
		return
	}
	defer conn.Close(websocket.StatusNormalClosure, "closing")

	events, unsubscribe := d.Changes.Subscribe(couple.ID)
	defer unsubscribe()

	// Keep control frames flowing while the app is idle.
	go func() { _ = conn.CloseRead(r.Context()) }()
	ticker := time.NewTicker(20 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case event := <-events:
			if event.SenderID == userID {
				continue
			}
			data, _ := json.Marshal(event)
			writeCtx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
			err := conn.Write(writeCtx, websocket.MessageText, data)
			cancel()
			if err != nil {
				return
			}
		case <-ticker.C:
			pingCtx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
			err := conn.Ping(pingCtx)
			cancel()
			if err != nil {
				return
			}
		case <-r.Context().Done():
			return
		}
	}
}
