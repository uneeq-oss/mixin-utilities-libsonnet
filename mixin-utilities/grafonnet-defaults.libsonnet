local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet-7.0/grafana.libsonnet';

{
  local g = self,

  dashboard:: {
    new(
      title,
      description=null,
      timeFrom='now-1d',
      refreshIntervals=['10s', '30s', '1m', '5m', '15m'],
    )::
      grafana.dashboard.new(
        title=title,
        description=description,
        editable=true,
        refresh='10s',
        uid=std.strReplace(title, ' ', '_'),
        graphTooltip=1,  // Shared cross hair
      )
      .setTime(from=timeFrom)
      .setTimepicker(refreshIntervals=refreshIntervals)
      .addTemplate(
        grafana.template.datasource.new(
          name='datasource',
          label='Data Source',
          query='prometheus',
        )
        // Set to default Prometheus datasource, if it exists
        .setCurrent(
          text='default',
          value='default',
          selected=true
        )
      ) {
        // Add a list of panels, ensuring they cover the width of the dashboard.
        // Accepts a array of objects. Example object:
        // { title: '', description: '', expr: '', legendFormat: '', unit: '' }
        addSortedPanels(sp):: self.addPanels([
          g.panel.graph.new(title=p.title, description=p.description)
          .addTarget(
            g.target.prometheus.new(expr=p.expr, legendFormat=p.legendFormat)
          )
          .setDefaultLegend().setYaxes(p.unit) + {
            // Set grid position to 12 for every odd indexed obj. Will lay panels out at
            // half width, reading from left to right.
            gridPos+: { [if (std.find(p, sp)[0] % 2 == 1) then 'x']: 12 },
          }

          for p in sp
        ]),
      },
  },

  panel:: {
    graph:: {
      new(
        title,
        datasource='${datasource}',
        dashes=null,
        description=null,
        fill=null,
        fillGradient=5
      )::
        grafana.panel.graph.new(
          title=title,
          dashes=dashes,
          datasource=datasource,
          description=description,
          fill=fill,
          fillGradient=fillGradient,
        )
        .setGridPos() {
          maxDataPoints: 500,

          setDefaultLegend(alignAsTable=null):: self.setLegend(
            alignAsTable=alignAsTable, max=true
          ),

          setYaxes(format)::
            self { yaxes: [
              {
                show: true,
                min: 0,
                format: format,
              },
              {
                // Not sure why this second object is needed here, but panel
                // doesn't render without it. Suspect something related to the second
                // y axis, as switching the ordering removes the config set in the first
                // object.
              },
            ] },
        },
    },

    table:: {
      new(
        title,
        datasource='${datasource}',
        description=null,
      )::
        grafana.panel.table.new(
          title=title,
          description=description,
          datasource=datasource,
        )
        .setGridPos(),
    },
  },

  target:: { prometheus:: {
    new(expr, legendFormat, instant=null)::
      grafana.target.prometheus.new(
        datasource='${datasource}',
        expr=expr,
        instant=instant,
        legendFormat=legendFormat,
      ),
  } },
}
