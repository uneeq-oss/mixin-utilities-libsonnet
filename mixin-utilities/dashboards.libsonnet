// A bunch of Grafana defaults we like to see around the place
// Can be added to the referenced Grafonnet functions

local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';

{
  dashboardDefaults():: {
    graphTooltip: 1,  // enum for `shared_crosshair`
    templating: {
      list: [{
        name: 'datasource',
        label: 'Data Source',
        query: 'prometheus',
        current: true,
        description: 'The data source to use for all panels of this dashboard.',
        refresh: 1,
        type: 'datasource',
      }],
    },


  },

  graphPanelDefaults():: {
    datasource: '$datasource',
    fillGradient: 5,
  },
}
