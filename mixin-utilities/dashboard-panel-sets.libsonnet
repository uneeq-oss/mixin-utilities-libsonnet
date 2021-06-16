// Common sets of panels which can be reused on many dashboards.

local g = import './grafonnet-defaults.libsonnet';

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
        'avg by (pod) (max_over_time(container_memory_usage_bytes{container="%s"}[$__interval]))'
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
  },
}
