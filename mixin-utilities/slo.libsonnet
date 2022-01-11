local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local prom = grafana.prometheus.target;
local db = import 'dashboards.libsonnet';

{
  // latencyburnDashboardRules
  // Provides a recording rule group to be used with the `sloLatencyBurn` panel set.
  latencyburnDashboardRules(param):: {
    local slo = {
      sloName: error 'must set `sloName` for latency burn',
      metric: error 'must set metric for latency burn',
      latencyTarget: error 'must set latencyTarget latency burn',
      latencyBudget: error 'must set latencyBudget latency burn',

      selectors: error 'must set selectors for latency burn',
      notErrorSelector: '%s!~"5.."' % slo.codeSelector,
    } + param,

    name: '%s rules' % slo.sloName,

    // These can be relatively expensive rules, and they're not the type of metrics
    // that'll need viewed with a high resolution. Run at a less frequent interval
    // to be nice to Prometheus.
    interval: '90s',
    rules: [
      {
        // Record the SLO as a metric. Nicer to have on graphs. Round to 11 decimal
        // places, handles floating point math.
        record: 'latencybudget:%s' % slo.metric,
        expr: '%0.11f' % slo.latencyBudget,
      },
      {
        // a 30d caluclation of our latency burn.
        record: 'latencytarget:%s:rate30d' % slo.metric,
        expr: |||
          1 - (
            sum(rate(%(bucketMetric)s{%(selectors)s,le="%(latencyTarget)s",%(notErrorSelector)s}[30d]))
            /
            sum(rate(%(countMetric)s{%(selectors)s}[30d]))
          )
        ||| % {
          bucketMetric: slo.metric + '_bucket',
          selectors: std.join(',', slo.selectors),
          latencyTarget: slo.latencyTarget,
          notErrorSelector: slo.notErrorSelector,
          countMetric: slo.metric + '_count',
        },
      },
    ],
  },

  // errorburnDashboardRules
  // Provides a recording rule group to be used with the `sloErrorBurn` panel set.
  errorburnDashboardRules(param):: {
    local slo = {
      sloName: error 'must set `sloName` for error burn',
      metric: error 'must set metric for error burn',
      target: error 'must set target for error burn',

      selectors: error 'must set selectors for error burn',
      errorSelectors: error 'must set errorSelectors for error burn',
    } + param,

    name: '%s rules' % slo.sloName,

    // These can be relatively expensive rules, and they're not the type of metrics
    // that'll need viewed with a high resolution. Run at a less frequent interval
    // to be nice to Prometheus.
    interval: '90s',
    rules: [
      {
        // Record the SLO as a metric. Nicer to have on graphs. Round to 11 decimal
        // places, handles floating point math.
        record: '%s:errorbudget' % slo.metric,
        expr: '1 - %0.11f' % slo.target,
      },
      {
        // a 30d caluclation of our error burn.
        record: '%s:burnrate30d' % slo.metric,
        expr: |||
          sum(rate(%(metric)s{%(errorSelectors)s}[30d]))
          /
          sum(rate(%(metric)s{%(selectors)s}[30d]))
        ||| % {
          metric: slo.metric,
          selectors: std.join(',', slo.selectors),
          errorSelectors: std.join(',', slo.selectors + slo.errorSelectors),
        },
      },
    ],
  },
}
