# Metrics generation receiver

| Status        |                          |
| ------------- |--------------------------|
| Stability     | development: metrics     |

Generates metrics given an initial OTLP JSON file that was produced with the `fileexporter`.
This receiver is inspired by the metrics dataset generation tool that's part of https://github.com/timescale/tsbs.
The difference is that this makes it easier to use real-ish OTel metrics from a receiver such as the `hostmetricsreceiver`
and send it to different backends using the corresponding exporter.

Given an initial set of resource metrics, this receiver generates metrics with a configurable scale, start time, end time, and interval.
For example, given the output of a single report from the `hostmetricsreceiver`,
lets you generate a day's worth of data from multiple simulated hosts with a given interval.

The datapoints for the metrics are individually simulated, taking into account the temporality, monotonicity,
and capping double values whose initial value is between 0 and 1 to that range.

## Getting Started

Settings:
* `path`: the path of the file containing a single batch of resource metrics in JSON format, as produced by the `fileexporter`.
* `start_time`: the start time for the generated metrics timestamps.
* `end_time`: the time at which the metrics should end.
* `interval`: the interval at which the metrics are simulated.
  The minimum value is 1s.
* `real_time` (default `false`): by default, the receiver generates the metrics as fast as possible.
  When set to true, it will pause after each cycle according to the configured `interval`.
* `exit_after_end` (default `false`): when set to true, will terminate the collector.
* `seed` (default random): set to a specific value for deterministic data generation.
* `scale`: determines how many instances (like hosts) to simulate.
* `churn` (default 0): allows to simulate instances spinning down and other instances taking their place, which will create new time series.
* `resource_attributes`: a map with resource attribute keys and values that are rendered as a template.
  These resource attributes are injected into all resource metrics for each individually simulated instance, according to the `scale`.
  Supported placeholders:
  * `{{.ID}}` (an integer equal to the number of the simulated instance, starting with `0`)
  * `{{.RandomIP}}`
  * `{{.RandomMAC}}`
* `template_vars`: the file provided via the `path` option is rendered as a template.
  This option lets you specify variables that are available during template rendering.
  This allows, for example, to simulate a variable number of network devices by generating metric data points with different attributes.

All that is required to enable the No-op exporter is to include it in the
exporter definitions. It takes no configuration.

```yaml
receivers:
  metricsgen:
    start_time: "2024-12-17T00:00:00Z"
    end_time: "2024-12-18T00:00:00Z"
    interval: 10s
    path: metricsgenreceiver/testdata/metricstemplate.json
    seed: 123
    scale: 100
    resource_attributes:
      host.name: "host-{{.ID}}"
      host.ip: [ "{{.RandomIP}}", "{{.RandomIP}}" ]
      host.mac: [ "{{.RandomMAC}}", "{{.RandomMAC}}" ]
```
