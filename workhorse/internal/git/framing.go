package git

import (
	"encoding/binary"
	"fmt"
	"io"
	"sync"
)

const (
	sshBodyFrameData          = 0x01
	sshBodyFrameKeepalive     = 0x02
	sshBodyFrameHeaderLen     = 5
	maxSSHBodyFrameDataLength = 65536
)

var errSSHBodyFrameTruncated = fmt.Errorf("SSH body framing: truncated frame: %w", io.ErrUnexpectedEOF)

// Gitaly's clients can drop the stdin copy error when the RPC fails, and can
// return while the copy goroutine is still reading. Save the error under a
// mutex so the handler can join it into the RPC error.
type sshBodyFrameReader struct {
	body      io.Reader
	remaining int

	errMu sync.Mutex
	err   error
}

func (r *sshBodyFrameReader) Read(p []byte) (int, error) {
	n, err := r.readFrame(p)
	if err != nil && err != io.EOF {
		r.errMu.Lock()
		r.err = err
		r.errMu.Unlock()
	}
	return n, err
}

func (r *sshBodyFrameReader) Err() error {
	r.errMu.Lock()
	defer r.errMu.Unlock()
	return r.err
}

func (r *sshBodyFrameReader) readFrame(p []byte) (int, error) {
	if len(p) == 0 {
		return 0, nil
	}

	for r.remaining == 0 {
		var header [sshBodyFrameHeaderLen]byte
		if _, err := io.ReadFull(r.body, header[:]); err != nil {
			if err == io.ErrUnexpectedEOF {
				err = errSSHBodyFrameTruncated
			}
			return 0, err
		}

		length := binary.BigEndian.Uint32(header[1:])
		switch header[0] {
		case sshBodyFrameData:
			if length == 0 || length > maxSSHBodyFrameDataLength {
				return 0, fmt.Errorf("SSH body framing: data frame length must be between 1 and %d: %d", maxSSHBodyFrameDataLength, length)
			}
			r.remaining = int(length)
		case sshBodyFrameKeepalive:
			if length != 0 {
				return 0, fmt.Errorf("SSH body framing: keepalive frame length must be 0: %d", length)
			}
		default:
			return 0, fmt.Errorf("SSH body framing: unknown frame type: 0x%02x", header[0])
		}
	}

	n, err := r.body.Read(p[:min(len(p), r.remaining)])
	r.remaining -= n
	switch {
	case r.remaining > 0 && (err == io.EOF || err == io.ErrUnexpectedEOF):
		err = errSSHBodyFrameTruncated
	case err == io.EOF:
		err = nil
	}
	return n, err
}
