local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local prom = grafana.prometheus.target;

{
  // latencyburnDashboard
  // Intented to be used with the latencyburn() function from slo-libsonnet,
  // param object is extended from this.
  // https://github.com/metalmatze/slo-libsonnet/blob/master/slo-libsonnet/latency-burn.libsonnet
  // Creates a dashboard and supporting recording rules for the provided SLO.
  latencyburnDashboard(param):: {
    local slo = {
      alertName: 'LatencyBudgetBurn',
      metric: error 'must set metric for latency burn',
      selectors: error 'must set selectors for latency burn',

      // Note, the latency target must be available as an exact histogram
      // bucket. As recording rules rely on it.
      latencyTarget: error 'must set latencyTarget latency burn',
      latencyBudget: error 'must set latencyBudget latency burn',
      alertLabels: {},
      alertAnnotations: {},
      codeSelector: 'code',
      notErrorSelector: '%s!~"5.."' % slo.codeSelector,

      dashboardName: error 'must set dashboardName for latency burn SLO',
      rates: ['5m', '30m', '1h', '2h', '6h', '1d', '3d'],
    } + param,

    recordingRuleGroup: {
      name: '%s rules' % slo.dashboardName,

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

      // Returns grafana dashboards as a map, can be added directly to grafanaDashboards
      // from kube-prometheus.
      grafanaDashboards: {
        ['%s.json' % shortDbName]:
          dashboardDefaults() +
          grafana.dashboard.new(
            title=slo.dashboardName,
            editable=true,
            refresh='10s',
            uid=shortDbName,
          )
          .addRow(
            grafana.row.new(title='SLO Details')
            .addPanel(grafana.text.new(
              title='', content=|||
                **Placeholder for description of SLO perhaps? Could fold into the alert as well.**

                **Latency Target:** %ss

                **Latency Budget:** %0.2f%%
              ||| % [slo.latencyTarget, slo.latencyBudget * 100]
            ))
            .addPanel(
              grafana.statPanel.new(
                title='Latency Budget used (30d)',
                description='The percent of the latency budget used in the last 30d.',
                datasource='$datasource',
                unit='percentunit',
              )
              .addTarget(prom(
                expr='latencytarget:%(metric)s:rate30d / latencybudget:%(metric)s' % { metric: slo.metric },
                instant=true,
              ))
              .addThresholds(thresholds)
            )
            .addPanel(
              grafana.statPanel.new(
                title='Burn Rates',
                description='Burn rate of the latency budget, for different sliding windows.',
                datasource='$datasource',
                unit='percentunit',
                reducerFunction='lastNotNull',
                min=0,
              )
              .addTargets([
                prom(expr='latencytarget:%s:rate%s' % [slo.metric, rate], legendFormat=rate)
                for rate in ['5m', '30m', '1h', '2h', '6h', '1d', '3d']
              ])
              .addThresholds(thresholds)
            )
          )
          .addRow(
            grafana.row.new(title='Charts')
            .addPanel(
              graphPanelDefaults +
              grafana.graphPanel.new(
                title='Burn Rate',
                description='Current Burn Rates',
                format='percentunit',
                span=12,
                min=0,
              )
              .addTargets([
                prom(expr='latencybudget:%s' % slo.metric, legendFormat='Budget'),
                prom(expr='latencytarget:%s:rate5m' % slo.metric, legendFormat='rate5m'),
                prom(expr='latencytarget:%s:rate1h' % slo.metric, legendFormat='rate1h'),
              ])
            )
          ),
      },
    },
  },
}
