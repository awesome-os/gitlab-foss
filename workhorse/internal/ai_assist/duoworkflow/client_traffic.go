package duoworkflow

import (
	"sync"
	"time"
)

// eventTypeInvalid is the event_type of a client message that could not be decoded.
const eventTypeInvalid = "invalid"

// trafficWindows are the lengths of the tumbling windows clientTraffic keeps a
// peak for, with the value of the window label.
var trafficWindows = []struct {
	label  string
	length time.Duration
}{
	{"1s", time.Second},
	{"10s", 10 * time.Second},
	{"60s", time.Minute},
}

// trafficWindow counts the messages and bytes of the window the connection is
// in, and the highest counts any window of this length has reached.
type trafficWindow struct {
	index        int64
	messages     int
	bytes        int
	peakMessages int
	peakBytes    int
}

// clientTraffic tracks what one connection reads from its client. Every
// transport owns one and reports each client message to record from
// ReadClientEvent, before it decodes it.
//
// The windows are fixed (tumbling), counted from the start of the connection,
// not sliding. A burst that straddles a window boundary is split across two
// windows, so a peak can read up to 2x lower than a sliding window would show.
type clientTraffic struct {
	transport string
	now       func() time.Time
	start     time.Time

	mu       sync.Mutex
	windows  []trafficWindow
	finished bool
}

func newClientTraffic(transport string) *clientTraffic {
	return newClientTrafficWithClock(transport, time.Now)
}

func newClientTrafficWithClock(transport string, now func() time.Time) *clientTraffic {
	return &clientTraffic{
		transport: transport,
		now:       now,
		start:     now(),
		windows:   make([]trafficWindow, len(trafficWindows)),
	}
}

// record accounts for one message read from the client: size is its raw length,
// before decoding, and eventType the oneof field it decoded to, or
// eventTypeInvalid.
func (c *clientTraffic) record(size int, eventType string) {
	clientMessageSizeBytes.WithLabelValues(c.transport, eventType).Observe(float64(size))

	elapsed := c.now().Sub(c.start)

	c.mu.Lock()
	defer c.mu.Unlock()

	for i, w := range trafficWindows {
		win := &c.windows[i]

		if index := int64(elapsed / w.length); index != win.index {
			win.index = index
			win.messages = 0
			win.bytes = 0
		}

		win.messages++
		win.bytes += size
		win.peakMessages = max(win.peakMessages, win.messages)
		win.peakBytes = max(win.peakBytes, win.bytes)
	}
}

// finish observes the peak of each window. It does so once, however often it
// is called, when the connection closes.
func (c *clientTraffic) finish() {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.finished {
		return
	}
	c.finished = true

	for i, w := range trafficWindows {
		clientPeakMessages.WithLabelValues(c.transport, w.label).Observe(float64(c.windows[i].peakMessages))
		clientPeakBytes.WithLabelValues(c.transport, w.label).Observe(float64(c.windows[i].peakBytes))
	}
}
