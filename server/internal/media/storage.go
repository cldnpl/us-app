// Package media stores couple photos on the local filesystem and generates
// square thumbnails for the gallery grid.
package media

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/disintegration/imaging"
)

type Storage struct {
	baseDir string
}

func NewStorage(baseDir string) (*Storage, error) {
	if err := os.MkdirAll(baseDir, 0o755); err != nil {
		return nil, err
	}
	return &Storage{baseDir: baseDir}, nil
}

func (s *Storage) Abs(rel string) string { return filepath.Join(s.baseDir, rel) }

func (s *Storage) Remove(rels ...string) {
	for _, r := range rels {
		if r != "" {
			_ = os.Remove(filepath.Join(s.baseDir, r))
		}
	}
}

// SaveImage decodes an uploaded image, writes a normalized full-size JPEG plus a
// 400×400 thumbnail under {couple}/{yyyy}/{mm}/, and returns their relative paths.
func (s *Storage) SaveImage(coupleID, id string, r io.Reader) (fullRel, thumbRel string, size int64, err error) {
	img, err := imaging.Decode(r, imaging.AutoOrientation(true))
	if err != nil {
		return "", "", 0, fmt.Errorf("decode image: %w", err)
	}

	now := time.Now()
	dir := filepath.Join(coupleID, fmt.Sprintf("%04d", now.Year()), fmt.Sprintf("%02d", int(now.Month())))
	if err := os.MkdirAll(filepath.Join(s.baseDir, dir), 0o755); err != nil {
		return "", "", 0, err
	}
	fullRel = filepath.Join(dir, id+".jpg")
	thumbRel = filepath.Join(dir, id+"_thumb.jpg")

	full := img
	if w := img.Bounds().Dx(); w > 2048 {
		full = imaging.Resize(img, 2048, 0, imaging.Lanczos)
	}
	if err := imaging.Save(full, s.Abs(fullRel), imaging.JPEGQuality(88)); err != nil {
		return "", "", 0, err
	}
	thumb := imaging.Fill(img, 400, 400, imaging.Center, imaging.Lanczos)
	if err := imaging.Save(thumb, s.Abs(thumbRel), imaging.JPEGQuality(80)); err != nil {
		s.Remove(fullRel)
		return "", "", 0, err
	}

	if fi, e := os.Stat(s.Abs(fullRel)); e == nil {
		size = fi.Size()
	}
	return fullRel, thumbRel, size, nil
}
