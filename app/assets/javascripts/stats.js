//= require jquery
//= require jquery.turbolinks
//= require highcharts
//= require highcharts-pattern-fill-v2
//= require turbolinks

var chartSeries = function() {
  var el = document.getElementById('chart');
  var seriesRaw = dataAttribute(el, 'data-series');
  var series = [];
  var seriesTitles = Object.keys(seriesRaw);

  $.each(seriesRaw, function(title, dataRaw) {
    var i = 0;
    var data = [];

    $.each(dataRaw, function(name, y) {
      data.push({
        name: name,
        color: 'url(#highcharts-default-pattern-' + i + ')',
        y: y
      });
      i++;
    });

    var size;
    var center;
    if(seriesTitles.length == 1) {
      size = '90%';
      center = ['50%', '50%'];
    } else {
      size = '70%';
      if(seriesTitles.indexOf(title) == 0) {
        center = ['25%', '50%'];
      } else {
        center = ['75%', '50%'];
      }
    }
    var showInLegend;
    if(seriesTitles.indexOf(title) == 0) {
      showInLegend = true;
    } else {
      showInLegend = false;
    }

    series.push({
      type: 'pie',
      size: size,
      center: center,
      showInLegend: showInLegend,
      data: data
    });
  });
  return series;
}
var dataAttribute = function(el, name) {
  return JSON.parse(el.getAttribute(name))
}

var chartTitle = function() {
  var el = document.getElementById('chart');
  var seriesRaw = dataAttribute(el, 'data-series');
  var titles = [];
  $.each(seriesRaw, function(title, _data) {
    titles.push(title);
  });
  return titles.join(' vs ');
}

$(document).on("turbolinks:load", function() {
  var series = chartSeries();

  Highcharts.setOptions({
    chart: {
      style: {
        fontFamily: '-apple-system, Helvetica, Roboto, Arial, sans-serif'
      }
    }
  });

  chart = new Highcharts.Chart({
    chart: {
      renderTo: 'chart',
      plotBackgroundColor: null,
      plotBorderWidth: null,
      plotShadow: false,
      animation: false,
    },
    title: {
      text: chartTitle(),
      style: {
        color: '#000000',
        fontSize: '36px',
        fontWeight: 'bold'
      }
    },
    tooltip: {
      formatter: function() {
        return '<b>'+ this.point.name +'</b>: '+ this.y +'/'+ this.total +' ('+ this.percentage.toFixed(2) +'%)';
      },
      style: {
        color: '#000000',
        fontSize: '28px'
      }
    },
    legend: {
      enabled: true,
      symbolHeight: 24,
      symbolWidth: 24,
      symbolRadius: 24,
      symbolPadding: 8,
      itemStyle: {
        color: '#000000',
        fontSize: '24px',
        fontWeight: 'normal'
      }
    },
    plotOptions: {
      pie: {
        allowPointSelect: true,
        cursor: 'pointer',
        animation: false,
        dataLabels: {
          enabled: true,
          connectorColor: '#000000',
          formatter: function() {
            return this.y +' ('+ this.percentage.toFixed(0) +'%)';
          },
          style: {
            color: '#000000',
            fontSize: '24px',
            fontWeight: 'normal'
          },
          distance: 30,
          verticalAlign: 'middle',
          crop: false
        }
      }
    },
    series: chartSeries(),
    credits: {
      enabled: false
    },
    exporting: {
      enabled: false
    }
  }, function(chart) {
    $(chart.series[0].data).each(function(i, e) {
      e.legendItem.on('click', function(event) {
        var legendItem=e.name;

        event.stopPropagation();
        $(chart.series).each(function(j,f){
          $(this.data).each(function(k,z){
            if(z.name==legendItem)
            {
              if(z.visible)
              {
                z.setVisible(false);
              }
              else
              {
                z.setVisible(true);
              }
            }
          });
        });
      });
    });
  });
});
