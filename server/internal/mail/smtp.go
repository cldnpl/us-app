package mail

import (
	"context"
	"crypto/tls"
	"fmt"
	"net"
	"net/smtp"
	"strings"
	"time"
)

type smtpSender struct {
	addr string // host:port
	host string
	auth smtp.Auth
	from string
}

// NewSMTPSender returns a Sender that delivers over SMTP with STARTTLS. Works
// with any provider that speaks plain SMTP submission — Gmail app passwords,
// Resend, Postmark, Mailgun, Fastmail — so switching provider is a config
// change, not a code change.
//
// user/pass may be empty for a relay that does not authenticate.
func NewSMTPSender(host, port, user, pass, from string) Sender {
	var auth smtp.Auth
	if user != "" {
		auth = smtp.PlainAuth("", user, pass, host)
	}
	return &smtpSender{
		addr: net.JoinHostPort(host, port),
		host: host,
		auth: auth,
		from: from,
	}
}

func (s *smtpSender) Deliverable() bool { return true }

func (s *smtpSender) Send(ctx context.Context, m Message) error {
	// smtp.SendMail has no context support, so bound the whole exchange with a
	// dial deadline and run it on a goroutine we can abandon if ctx dies.
	done := make(chan error, 1)
	go func() { done <- s.send(m) }()
	select {
	case err := <-done:
		return err
	case <-ctx.Done():
		return ctx.Err()
	}
}

func (s *smtpSender) send(m Message) error {
	conn, err := net.DialTimeout("tcp", s.addr, 10*time.Second)
	if err != nil {
		return fmt.Errorf("smtp dial: %w", err)
	}
	_ = conn.SetDeadline(time.Now().Add(30 * time.Second))

	c, err := smtp.NewClient(conn, s.host)
	if err != nil {
		conn.Close()
		return fmt.Errorf("smtp client: %w", err)
	}
	defer c.Close()

	if ok, _ := c.Extension("STARTTLS"); ok {
		if err := c.StartTLS(&tls.Config{ServerName: s.host, MinVersion: tls.VersionTLS12}); err != nil {
			return fmt.Errorf("smtp starttls: %w", err)
		}
	}
	if s.auth != nil {
		if err := c.Auth(s.auth); err != nil {
			return fmt.Errorf("smtp auth: %w", err)
		}
	}
	if err := c.Mail(s.from); err != nil {
		return fmt.Errorf("smtp from: %w", err)
	}
	if err := c.Rcpt(m.To); err != nil {
		return fmt.Errorf("smtp rcpt: %w", err)
	}
	w, err := c.Data()
	if err != nil {
		return fmt.Errorf("smtp data: %w", err)
	}
	if _, err := w.Write([]byte(s.compose(m))); err != nil {
		return fmt.Errorf("smtp write: %w", err)
	}
	if err := w.Close(); err != nil {
		return fmt.Errorf("smtp close: %w", err)
	}
	return c.Quit()
}

// compose builds a minimal RFC 5322 message. Header values are stripped of CR
// and LF so a hostile address cannot inject extra headers.
func (s *smtpSender) compose(m Message) string {
	var b strings.Builder
	b.WriteString("From: " + header(s.from) + "\r\n")
	b.WriteString("To: " + header(m.To) + "\r\n")
	b.WriteString("Subject: " + header(m.Subject) + "\r\n")
	b.WriteString("MIME-Version: 1.0\r\n")
	b.WriteString("Content-Type: text/plain; charset=UTF-8\r\n")
	b.WriteString("\r\n")
	b.WriteString(strings.ReplaceAll(m.Body, "\n", "\r\n"))
	return b.String()
}

func header(v string) string {
	return strings.NewReplacer("\r", "", "\n", "").Replace(v)
}
