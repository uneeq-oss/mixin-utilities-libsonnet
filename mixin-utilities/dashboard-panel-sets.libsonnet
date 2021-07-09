// Common sets of panels which can be reused on many dashboards.

local g = import './grafonnet-defaults.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet-7.0/grafana.libsonnet';
local p = g.target.prometheus.new;

{
  panelSets:: {

    // Returns an array of four panels for common resource usage stats for the provided container name.
    // Depends on kube-state-metrics.
    appResourceUsage(containerName, interval='1m'):: [
      g.panel.graph.new(
        title='CPU - ' + containerName,
        description='CPU usage by pod, and resource requests',
      )
      .setGridPos(w=6)
      .setLegend(avg=true, max=true)
      .setYaxes('percentunit')
      .addTarget(g.target.prometheus.new(
        'avg by (pod) (rate(container_cpu_usage_seconds_total{container="%s"}[$__rate_interval]))'
        % containerName,
        '{{pod}}',
      ))
      .addTarget(g.target.prometheus.new(
        'avg(kube_pod_container_resource_requests_cpu_cores{container="%s"})' % containerName,
        'Request',
      ))
      .addSeriesOverride(alias='Request', dashes=true, fill=0, fillGradient=0, color='orange')
      .addTarget(g.target.prometheus.new(
        'avg(kube_pod_container_resource_limits_cpu_cores{container="%s"})' % containerName,
        'Limit',
      ))
      .addSeriesOverride(alias='Limit', dashes=true, fill=0, fillGradient=0, color='red')
      + { interval: '1m' },


      g.panel.graph.new(
        title='CPU Throttling - ' + containerName,
        description='Throttled CPU by pod.',
      )
      .setGridPos(x=6, w=6)
      .setLegend(avg=true, max=true)
      .setYaxes('percentunit')
      .addTarget(g.target.prometheus.new(
        |||
          rate(container_cpu_cfs_throttled_periods_total{container="%(containerName)s"}[$__rate_interval])
          /
          rate(container_cpu_cfs_periods_total{container="%(containerName)s"}[$__rate_interval])
        ||| % { containerName: containerName },
        '{{pod}}',
      ))
      + { interval: '1m' },

      g.panel.graph.new(
        title='Memory - ' + containerName,
        description='Memory usage by pod, and resource requests',
      )
      .setGridPos(x=12, w=6)
      .setLegend(avg=true, max=true)
      .setYaxes('decbytes')
      .addTarget(g.target.prometheus.new(
        'avg by (pod) (max_over_time(container_memory_working_set_bytes{container="%s"}[$__interval]))'
        % containerName,
        '{{pod}}',
      ))
      .addTarget(g.target.prometheus.new(
        'avg(kube_pod_container_resource_requests_memory_bytes{container="%s"})' % containerName,
        'Request',
      ))
      .addSeriesOverride(alias='Request', dashes=true, fill=0, fillGradient=0, color='orange')
      .addTarget(g.target.prometheus.new(
        'avg(kube_pod_container_resource_limits_memory_bytes{container="%s"})' % containerName,
        'Limit',
      ))
      .addSeriesOverride(alias='Limit', dashes=true, fill=0, fillGradient=0, color='red')
      + { interval: '1m' },

      g.panel.graph.new(title='Network - ' + containerName,)
      .setGridPos(x=18, w=6)
      .setLegend(avg=true, max=true)
      .setYaxes('Bps')
      .addTarget(g.target.prometheus.new(
        |||
          avg(sum without (interface) (
              rate(container_network_receive_bytes_total{pod=~"%s.*"}[$__rate_interval])
          ))
        ||| % containerName,
        'receive',
      ))
      .addTarget(g.target.prometheus.new(
        |||
          avg(sum without (interface) (
              rate(container_network_transmit_bytes_total{pod=~"%s.*"}[$__rate_interval])
          ))
        ||| % containerName,
        'transmit',
      ))
      + { interval: '1m' },
    ],

    // Reutrns an object, with a key set to slo.sloName. This is an array of panels for this SLO.
    // These could be reused in a couple of dashboards, hence the object to make easier to share
    // around. Intended to accept a similar object as slo-libsonnet, with some additions. Required
    // fields: sloName, latencytarget, latencyBudget, metric.
    sloLatencyBurn(param):: {
      local slo = {
        sloName: error 'Must set `sloName` for sloLatencyBurn',
        latencytarget: error 'Must set `latencytarget` for sloLatencyBurn',
        latencyBudget: error 'Must set `latencyBudget` for sloLatencyBurn',
        latencyObjective: 1 - self.latencyBudget,
        metric: error 'Must set `metric` for sloLatencyBurn',
        unit: 's',
      } + param,
      [param.sloName]: [
        grafana.panel.row.new(collapsed=false, title=param.sloName),
        // "Have we hit our SLO" panel
        g.panel.stat.new(
          title='Spent Budget [30d]',
          description='Ratio of the error budget has been used over the last 30d. Less than 1 means the SLO was achieved.'
        )
        .addTarget(p('latencytarget:%(m)s:rate30d / latencybudget:%(m)s' % { m: slo.metric }, ''))
        .addThresholdStep(value=0, color='green')
        .addThresholdStep(value=0.9, color='yellow')
        .addThresholdStep(value=1, color='red')
        .setFieldConfig(unit='X')
        .setGridPos(w=4, h=4),

        g.panel.stat.new(title='SLI [30d]')
        .addTarget(p('1 - latencytarget:%s:rate30d' % slo.metric, ''))
        .addThresholdStep(value=0, color='red')
        .addThresholdStep(value=slo.latencyObjective, color='yellow')
        .addThresholdStep(value=slo.latencyObjective + slo.latencyBudget * 0.1, color='green')
        .setFieldConfig(unit='percentunit', max=1.1)
        .setGridPos(w=4, h=4),

        // Info panel
        grafana.panel.text.new(
          content=|||
            - Target: `%s%s`
            - Budget: `%s%%`
            - Objective: `%s%%`
          ||| % [
            slo.latencyTarget,
            slo.unit,
            slo.latencyBudget * 100,
            slo.latencyObjective * 100,
          ]
        )
        .setGridPos(w=4, h=3),

        // Alert threshold graphs
        // Critical
        g.panel.graph.new(
          title='Alert thresholds: critical fast burn',
          description='Alert thresholds to trigger a critical fast burn SLO alert'
        )
        .addTargets([
          p('latencytarget:%s:rate1h' % slo.metric, 'rate1h'),
          p('latencytarget:%s:rate5m' % slo.metric, 'rate5m'),
          p('latencybudget:%(metric)s * 14.4' % { metric: slo.metric }, 'threshold'),
        ])
        .addSeriesOverride(alias='threshold', dashes=true, fill=0, fillGradient=0, color='red')
        .setYaxes('percentunit')
        .setGridPos(w=5, h=11, x=4),

        g.panel.graph.new(
          title='Alert thresholds: critical slow burn',
          description='Alert thresholds to trigger a critical slow burn SLO alert'
        )
        .addTargets([
          p('latencytarget:%s:rate6h' % slo.metric, 'rate6h'),
          p('latencytarget:%s:rate30m' % slo.metric, 'rate30m'),
          p('latencybudget:%(metric)s * 6' % { metric: slo.metric }, 'threshold'),
        ])
        .addSeriesOverride(alias='threshold', dashes=true, fill=0, fillGradient=0, color='red')
        .setYaxes('percentunit')
        .setGridPos(w=5, h=11, x=9),

        // Warning
        g.panel.graph.new(
          title='Alert thresholds: warning fast burn',
          description='Alert thresholds to trigger a warning fast burn SLO alert'
        )
        .addTargets([
          p('latencytarget:%s:rate1d' % slo.metric, 'rate1d'),
          p('latencytarget:%s:rate2h' % slo.metric, 'rate2h'),
          p('latencybudget:%(metric)s * 3' % { metric: slo.metric }, 'threshold'),
        ])
        .addSeriesOverride(alias='threshold', dashes=true, fill=0, fillGradient=0, color='#FA6400')
        .setYaxes('percentunit')
        .setGridPos(w=5, h=11, x=14),

        g.panel.graph.new(
          title='Alert thresholds: warning slow burn',
          description='Alert thresholds to trigger a warning slow burn SLO alert'
        )
        .addTargets([
          p('latencytarget:%s:rate3d' % slo.metric, 'rate3d'),
          p('latencytarget:%s:rate6h' % slo.metric, 'rate6h'),
          p('latencybudget:%(metric)s' % { metric: slo.metric }, 'threshold'),
        ])
        .addSeriesOverride(alias='threshold', dashes=true, fill=0, fillGradient=0, color='#FA6400')
        .setYaxes('percentunit')
        .setGridPos(w=5, h=11, x=19),
      ],
    },

    // Returns an object with a key set to slo.sloName. This is an array of panels for this SLO.
    // These could be reused in a couple of dashboards, hence the object to make easier to share
    // around. This is intended to accept a similar object as errorburn in slo-libsonnet, but
    // modified somewhat for applications that may have different success and failure metrics.
    // Only required fields are specified.
    sloErrorBurn(param):: {
      local slo = {
        sloName: error 'Must set `sloName` for sloErrorBurn',
        errorBudget: error 'Must set `errorBudget` for sloErrorBurn',
        errorObjective: 1 - self.errorBudget,
        successMetric: error 'Must set successMetric for sloErrorBurn',
        recordingrule: '%s:burnrate%%s' % self.successMetric,
      } + param,

      [param.sloName]: [
        grafana.panel.row.new(collapsed=false, title=param.sloName),
        // Error budget spent
        g.panel.stat.new(
          title='Spent Budget [30d]',
          description='Ratio of the error budget has been used over the last 30d. Less than 1 means the SLO was achieved.'
        )
        .addTarget(p('%(m)s:burnrate30d / %(m)s:errorbudget' % { m: slo.successMetric }, ''))
        .addThresholdStep(value=0, color='green')
        .addThresholdStep(value=0.9, color='yellow')
        .addThresholdStep(value=1, color='red')
        .setFieldConfig(unit='X')
        .setGridPos(w=4, h=4),

        g.panel.stat.new(title='SLI [30d]')
        .addTarget(p('1 - %s:burnrate30d' % slo.successMetric, ''))
        .addThresholdStep(value=0, color='red')
        .addThresholdStep(value=slo.errorObjective, color='yellow')
        .addThresholdStep(value=slo.errorObjective + slo.errorBudget * 0.1, color='green')
        .setFieldConfig(unit='percentunit', max=1.1)
        .setGridPos(w=4, h=4),

        // Info panel
        grafana.panel.text.new(
          content=|||
            - Budget: `%g%%`
            - Objective: `%g%%`
          ||| % [slo.errorBudget * 100, slo.errorObjective * 100]
        )
        .setGridPos(w=4, h=2),
      ] + [
        g.panel.graph.new(
          title='Alert thresholds: %(sev)s rate%(burns)s for %(for)s' % {
            sev: w.severity,
            burns: '%s/%s' % [w.long, w.short],
            'for': w['for'],
          },
          description=|||
            Alert thresholds to trigger a %(sev)s alert for %(name)s.

            Both `rate%(long)s` and `rate%(short)s` must be above the threshold
            of `%(thresh)g%%` for `%(for)s` to fire the alert.
          ||| % {
            sev: w.severity,
            name: slo.sloName,
            long: w.long,
            short: w.short,
            thresh: slo.errorBudget * w.factor * 100,
            'for': w['for'],
          },
        )
        .addTargets([
          p('%s:burnrate%s' % [slo.successMetric, w.long], 'rate%s' % w.long),
          p('%s:burnrate%s' % [slo.successMetric, w.short], 'rate%s' % w.short),
          p('%s:errorbudget * %s' % [slo.successMetric, w.factor], 'threshold'),
        ],)
        .addSeriesOverride(alias='threshold', dashes=true, fill=0, fillGradient=0, color='#FA6400')
        .setYaxes('percentunit')
        .setGridPos(
          w=5,
          h=10,
          // Offset horizontally by index of w in arr windows
          x=std.find(w, slo.windows)[0] * 5 + 4
        )
        for w in slo.windows
      ],
    },
  },
}
