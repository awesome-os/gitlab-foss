package git

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"strings"
	"testing"
	"testing/iotest"

	"github.com/stretchr/testify/require"
)

func TestSSHBodyFrameReader(t *testing.T) {
	for _, tt := range []struct {
		name string
		body []byte
		want string
	}{
		{name: "empty body"},
		{name: "data", body: sshBodyFrame(sshBodyFrameData, "0000"), want: "0000"},
		{name: "keepalive only", body: sshBodyFrame(sshBodyFrameKeepalive, "")},
		{
			name: "interleaved keepalives",
			body: bytes.Join([][]byte{
				sshBodyFrame(sshBodyFrameKeepalive, ""),
				sshBodyFrame(sshBodyFrameData, "0014command=ls-refs\n"),
				sshBodyFrame(sshBodyFrameKeepalive, ""),
				sshBodyFrame(sshBodyFrameKeepalive, ""),
				sshBodyFrame(sshBodyFrameData, "00010000"),
				sshBodyFrame(sshBodyFrameKeepalive, ""),
			}, nil),
			want: "0014command=ls-refs\n00010000",
		},
		{name: "maximum data length", body: sshBodyFrame(sshBodyFrameData, strings.Repeat("x", maxSSHBodyFrameDataLength)), want: strings.Repeat("x", maxSSHBodyFrameDataLength)},
	} {
		t.Run(tt.name, func(t *testing.T) {
			reader := &sshBodyFrameReader{body: bytes.NewReader(tt.body)}
			require.NoError(t, reader.Err())
			got, err := io.ReadAll(reader)
			require.NoError(t, err)
			require.Equal(t, tt.want, string(got))
			require.NoError(t, reader.Err())
		})
	}
}

func TestSSHBodyFrameReader_SplitReads(t *testing.T) {
	body := bytes.Join([][]byte{
		sshBodyFrame(sshBodyFrameData, "hello"),
		sshBodyFrame(sshBodyFrameKeepalive, ""),
		sshBodyFrame(sshBodyFrameData, "world"),
	}, nil)

	for offset := 0; offset <= len(body); offset++ {
		t.Run(fmt.Sprintf("split at %d", offset), func(t *testing.T) {
			input := io.MultiReader(bytes.NewReader(body[:offset]), bytes.NewReader(body[offset:]))
			got, err := io.ReadAll(&sshBodyFrameReader{body: input})
			require.NoError(t, err)
			require.Equal(t, "helloworld", string(got))
		})
	}

	t.Run("one byte at a time", func(t *testing.T) {
		got, err := io.ReadAll(&sshBodyFrameReader{body: iotest.OneByteReader(bytes.NewReader(body))})
		require.NoError(t, err)
		require.Equal(t, "helloworld", string(got))
	})
}

func TestSSHBodyFrameReader_InvalidFrame(t *testing.T) {
	for _, tt := range []struct {
		name string
		body []byte
		want string
	}{
		{name: "unknown type", body: sshBodyFrameHeader(0x03, 0), want: "unknown frame type: 0x03"},
		{name: "keepalive with payload", body: sshBodyFrameHeader(sshBodyFrameKeepalive, 1), want: "keepalive frame length must be 0: 1"},
		{name: "empty data", body: sshBodyFrameHeader(sshBodyFrameData, 0), want: "data frame length must be between 1 and 65536: 0"},
		{name: "oversized data", body: sshBodyFrameHeader(sshBodyFrameData, 65537), want: "data frame length must be between 1 and 65536: 65537"},
		{name: "maximum uint32 length", body: sshBodyFrameHeader(sshBodyFrameData, 0xffffffff), want: "data frame length must be between 1 and 65536: 4294967295"},
	} {
		t.Run(tt.name, func(t *testing.T) {
			reader := &sshBodyFrameReader{body: bytes.NewReader(append(tt.body, sshBodyFrame(sshBodyFrameData, "valid")...))}
			_, err := io.ReadAll(reader)
			require.ErrorContains(t, err, tt.want)
			require.ErrorIs(t, reader.Err(), err)
		})
	}
}

func TestSSHBodyFrameReader_TruncatedFrame(t *testing.T) {
	body := sshBodyFrame(sshBodyFrameData, "hello")
	for length := 1; length < len(body); length++ {
		t.Run(fmt.Sprintf("truncated at %d", length), func(t *testing.T) {
			reader := &sshBodyFrameReader{body: bytes.NewReader(body[:length])}
			got, err := io.ReadAll(reader)
			require.ErrorIs(t, err, io.ErrUnexpectedEOF)
			require.EqualError(t, err, "SSH body framing: truncated frame: unexpected EOF")
			require.Equal(t, "hello"[:max(0, length-sshBodyFrameHeaderLen)], string(got))
			require.ErrorIs(t, reader.Err(), err)
		})
	}
}

func TestSSHBodyFrameReader_DataAndEOF(t *testing.T) {
	for _, tt := range []struct {
		name   string
		length uint32
		want   error
	}{
		{name: "complete payload", length: 1},
		{name: "truncated payload", length: 2, want: errSSHBodyFrameTruncated},
	} {
		t.Run(tt.name, func(t *testing.T) {
			input := io.MultiReader(bytes.NewReader(sshBodyFrameHeader(sshBodyFrameData, tt.length)), iotest.DataErrReader(strings.NewReader("x")))
			reader := &sshBodyFrameReader{body: input}
			buf := make([]byte, 10)

			n, err := reader.Read(buf)
			require.ErrorIs(t, err, tt.want)
			require.Equal(t, "x", string(buf[:n]))
		})
	}
}

func TestSSHBodyFrameReader_EmptyRead(t *testing.T) {
	body := bytes.NewReader(sshBodyFrame(sshBodyFrameData, "x"))
	reader := &sshBodyFrameReader{body: body}

	n, err := reader.Read(nil)
	require.NoError(t, err)
	require.Zero(t, n)
	require.Equal(t, 6, body.Len())
}

func TestSSHBodyFrameReader_BodyError(t *testing.T) {
	bodyErr := fmt.Errorf("body read failed")
	for _, tt := range []struct {
		name    string
		prefix  []byte
		readErr error
		want    error
	}{
		{name: "header", readErr: bodyErr, want: bodyErr},
		{name: "payload", prefix: sshBodyFrameHeader(sshBodyFrameData, 1), readErr: bodyErr, want: bodyErr},
		{name: "truncated payload", prefix: sshBodyFrameHeader(sshBodyFrameData, 1), readErr: io.ErrUnexpectedEOF, want: errSSHBodyFrameTruncated},
	} {
		t.Run(tt.name, func(t *testing.T) {
			input := io.MultiReader(bytes.NewReader(tt.prefix), iotest.ErrReader(tt.readErr))
			_, err := io.ReadAll(&sshBodyFrameReader{body: input})
			require.ErrorIs(t, err, tt.want)
		})
	}
}

func sshBodyFrame(frameType byte, payload string) []byte {
	return append(sshBodyFrameHeader(frameType, uint32(len(payload))), payload...)
}

func sshBodyFrameHeader(frameType byte, length uint32) []byte {
	header := make([]byte, sshBodyFrameHeaderLen)
	header[0] = frameType
	binary.BigEndian.PutUint32(header[1:], length)
	return header
}
