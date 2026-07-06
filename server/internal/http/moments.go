package httpapi

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"

	"github.com/sharepact/us/internal/domain"
	"github.com/sharepact/us/internal/store"
)

func toDomainMilestone(m store.Milestone) domain.Milestone {
	return domain.Milestone{ID: m.ID, Title: m.Title, Date: m.Date, Kind: m.Kind}
}

func toDomainReunion(r store.Reunion) domain.Reunion {
	return domain.Reunion{ID: r.ID, Title: r.Title, TargetDate: r.TargetDate}
}

// ---- milestones ----

func (d Deps) handleListMilestones(w http.ResponseWriter, r *http.Request) {
	c, _, ok := d.coupleForRequest(w, r)
	if !ok {
		return
	}
	items, err := d.Store.ListMilestones(r.Context(), c.ID)
	if err != nil {
		d.serverError(w, "milestones: list", err)
		return
	}
	out := make([]domain.Milestone, len(items))
	for i, m := range items {
		out[i] = toDomainMilestone(m)
	}
	writeJSON(w, http.StatusOK, map[string]any{"milestones": out})
}

type milestoneRequest struct {
	Title string `json:"title"`
	Date  string `json:"date"` // YYYY-MM-DD
	Kind  string `json:"kind"`
}

func (d Deps) handleCreateMilestone(w http.ResponseWriter, r *http.Request) {
	c, _, ok := d.coupleForRequest(w, r)
	if !ok {
		return
	}
	var req milestoneRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	title := strings.TrimSpace(req.Title)
	if title == "" {
		writeError(w, http.StatusBadRequest, "missing_title", "a title is required")
		return
	}
	date, err := time.Parse("2006-01-02", req.Date)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_date", "date must be YYYY-MM-DD")
		return
	}
	kind := req.Kind
	if kind == "" {
		kind = "milestone"
	}
	m, err := d.Store.CreateMilestone(r.Context(), c.ID, title, date, kind)
	if err != nil {
		d.serverError(w, "milestones: create", err)
		return
	}
	writeJSON(w, http.StatusCreated, toDomainMilestone(m))
}

func (d Deps) handleUpdateMilestone(w http.ResponseWriter, r *http.Request) {
	c, _, ok := d.coupleForRequest(w, r)
	if !ok {
		return
	}
	m, err := d.Store.GetMilestone(r.Context(), chi.URLParam(r, "id"))
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusNotFound, "not_found", "not found")
		return
	} else if err != nil {
		d.serverError(w, "milestones: get", err)
		return
	}
	if m.CoupleID != c.ID {
		writeError(w, http.StatusForbidden, "forbidden", "not allowed")
		return
	}
	var req milestoneRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	title := strings.TrimSpace(req.Title)
	if title == "" {
		writeError(w, http.StatusBadRequest, "missing_title", "a title is required")
		return
	}
	date, err := time.Parse("2006-01-02", req.Date)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_date", "date must be YYYY-MM-DD")
		return
	}
	updated, err := d.Store.UpdateMilestone(r.Context(), m.ID, title, date)
	if err != nil {
		d.serverError(w, "milestones: update", err)
		return
	}
	writeJSON(w, http.StatusOK, toDomainMilestone(updated))
}

func (d Deps) handleDeleteMilestone(w http.ResponseWriter, r *http.Request) {
	c, _, ok := d.coupleForRequest(w, r)
	if !ok {
		return
	}
	m, err := d.Store.GetMilestone(r.Context(), chi.URLParam(r, "id"))
	if errors.Is(err, store.ErrNotFound) {
		w.WriteHeader(http.StatusNoContent)
		return
	} else if err != nil {
		d.serverError(w, "milestones: get", err)
		return
	}
	if m.CoupleID != c.ID {
		writeError(w, http.StatusForbidden, "forbidden", "not allowed")
		return
	}
	if err := d.Store.DeleteMilestone(r.Context(), m.ID); err != nil {
		d.serverError(w, "milestones: delete", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ---- reunions ----

func (d Deps) handleListReunions(w http.ResponseWriter, r *http.Request) {
	c, _, ok := d.coupleForRequest(w, r)
	if !ok {
		return
	}
	items, err := d.Store.ListReunions(r.Context(), c.ID)
	if err != nil {
		d.serverError(w, "reunions: list", err)
		return
	}
	out := make([]domain.Reunion, len(items))
	for i, rn := range items {
		out[i] = toDomainReunion(rn)
	}
	writeJSON(w, http.StatusOK, map[string]any{"reunions": out})
}

type reunionRequest struct {
	Title      string `json:"title"`
	TargetDate string `json:"targetDate"` // YYYY-MM-DD
}

func (d Deps) handleCreateReunion(w http.ResponseWriter, r *http.Request) {
	c, _, ok := d.coupleForRequest(w, r)
	if !ok {
		return
	}
	var req reunionRequest
	if !decodeJSON(w, r, &req) {
		return
	}
	title := strings.TrimSpace(req.Title)
	if title == "" {
		writeError(w, http.StatusBadRequest, "missing_title", "a title is required")
		return
	}
	target, err := time.Parse("2006-01-02", req.TargetDate)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_date", "targetDate must be YYYY-MM-DD")
		return
	}
	rn, err := d.Store.CreateReunion(r.Context(), c.ID, title, target)
	if err != nil {
		d.serverError(w, "reunions: create", err)
		return
	}
	writeJSON(w, http.StatusCreated, toDomainReunion(rn))
}

func (d Deps) handleDeleteReunion(w http.ResponseWriter, r *http.Request) {
	c, _, ok := d.coupleForRequest(w, r)
	if !ok {
		return
	}
	rn, err := d.Store.GetReunion(r.Context(), chi.URLParam(r, "id"))
	if errors.Is(err, store.ErrNotFound) {
		w.WriteHeader(http.StatusNoContent)
		return
	} else if err != nil {
		d.serverError(w, "reunions: get", err)
		return
	}
	if rn.CoupleID != c.ID {
		writeError(w, http.StatusForbidden, "forbidden", "not allowed")
		return
	}
	if err := d.Store.DeleteReunion(r.Context(), rn.ID); err != nil {
		d.serverError(w, "reunions: delete", err)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
