// A bunch of Grafana defaults we like to see around the place
// Can be added to the referenced Grafonnet functions

local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';

{
  dashboardDefaults():: {
    graphTooltip: 1,  // enum for `shared_crosshair`
    templating: {
      list: [{
        current: {
          selected: false,
          text: 'prometheus',
          value: 'prometheus',
        },
        description: 'The datasource to use for this dashboard.',
        'error': null,
        hide: 0,
        includeAll: false,
        label: 'Data Source',
        multi: false,
        name: 'datasource',
        options: [],
        query: 'prometheus',
        refresh: 1,
        regex: '',
        skipUrlSync: false,
        type: 'datasource',
      }],
    },


  },

  graphPanelDefaults():: {
    datasource: '$datasource',
    fillGradient: 5,
  },
}
