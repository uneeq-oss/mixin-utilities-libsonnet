// A bunch of Grafana defaults we like to see around the place
// Can be added to the referenced Grafonnet functions

local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';

{
  dashboardDefaults():: {
    graphTooltip: 1,  // enum for `shared_crosshair`
    templates: [{
      name: 'datasource',
      label: 'Data Source',
      query: 'prometheus',
      current: true,
    }],
  },

  graphPanelDefaults():: {
    datasource: '$datasource',
    fillGradient: 5,
  },
}
