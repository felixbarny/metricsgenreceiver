package metricsgenreceiver

import (
	"context"
	"fmt"
	"github.com/open-telemetry/opentelemetry-collector-contrib/receiver/metricsgenreceiver/internal/dp"
	"github.com/stretchr/testify/require"
	"go.opentelemetry.io/collector/consumer/consumertest"
	"go.opentelemetry.io/collector/pdata/pcommon"
	"go.opentelemetry.io/collector/pdata/pmetric"
	"go.opentelemetry.io/collector/receiver/receivertest"
	"testing"
	"time"
)

func TestReceiver(t *testing.T) {
	sink := new(consumertest.MetricsSink)

	factory := NewFactory()
	cfg := testdataConfigYamlAsMap()
	rcv, err := factory.CreateMetrics(context.Background(), receivertest.NewNopSettings(), cfg, sink)
	require.NoError(t, err)
	err = rcv.Start(context.Background(), nil)
	require.NoError(t, err)
	require.Eventually(t, func() bool {
		return sink.DataPointCount() == 3* // 3 metrics
			2* // 2 intervals
			cfg.Scenarios[0].Scale
	}, 2*time.Second, time.Millisecond)
	require.NoError(t, rcv.Shutdown(context.Background()))

	allMetrics := sink.AllMetrics()
	require.NotEmpty(t, allMetrics)

	require.Equal(t, 2*cfg.Scenarios[0].Scale, len(allMetrics))

	verifyMetrics(t, 0, cfg, allMetrics, cfg.StartTime)
	verifyMetrics(t, cfg.Scenarios[0].Scale, cfg, allMetrics, cfg.StartTime.Add(30*time.Second))
}

func TestReceiverConcurrency(t *testing.T) {
	sink := new(consumertest.MetricsSink)

	factory := NewFactory()
	cfg := testdataConfigYamlAsMap()
	cfg.Scenarios[0].ConcurrentInstances = true
	rcv, err := factory.CreateMetrics(context.Background(), receivertest.NewNopSettings(), cfg, sink)
	require.NoError(t, err)
	err = rcv.Start(context.Background(), nil)
	require.NoError(t, err)
	require.Eventually(t, func() bool {
		return sink.DataPointCount() == 3* // 3 metrics
			2* // 2 intervals
			cfg.Scenarios[0].Scale
	}, 2*time.Second, time.Millisecond)
	require.NoError(t, rcv.Shutdown(context.Background()))

	allMetrics := sink.AllMetrics()
	require.NotEmpty(t, allMetrics)

	require.Equal(t, 2*cfg.Scenarios[0].Scale, len(allMetrics))
}

func verifyMetrics(t *testing.T, offset int, cfg *Config, allMetrics []pmetric.Metrics, timestamp time.Time) {
	for i := offset; i < cfg.Scenarios[0].Scale+offset; i++ {
		dp.ForEachDataPoint(&allMetrics[i], func(r pcommon.Resource, s pcommon.InstrumentationScope, m pmetric.Metric, dp dp.DataPoint) {
			value, _ := r.Attributes().Get("host.name")
			require.Equal(t, fmt.Sprintf("host-%d", i-offset), value.Str())
			require.Equal(t, cfg.StartTime, dp.StartTimestamp().AsTime())
			require.WithinRange(t, dp.Timestamp().AsTime(), timestamp, timestamp.Add(20*time.Millisecond))
		})
	}
}
