var StackedAreaChart = function(name) {
  var chart;

  var colors = d3.scale.category20();
  var keyColor = function(d, i) {return colors(d.key)};

  var createChart = function() {
    chart = nv.models.stackedAreaChart()
              .useInteractiveGuideline(true)
              .x(function(d) { return d[0] })
              .y(function(d) { return d[1] })
              .color(keyColor)
              .transitionDuration(300);

    chart.xAxis
      .tickFormat(function(d) { return d3.time.format('%X')(new Date(d)) });

    chart.yAxis
      .tickFormat(d3.format(',.d'));

    nv.utils.windowResize(chart.update);

    return chart;
  }

  var update = function() {
    $.ajax({
      url: '/api/stats/' + name,
      type: 'GET',
      dataType: 'json',
      success: function(data) {
        d3.select('#chart-' + name)
          .datum(data)
          .transition().duration(300)
          .call(chart);

        chart.update;
      },
      complete: setTimeout(function() { update(name, chart); }, 1000),
    });
  };

  var initialize = function() {
    console.info("creating graph '" + name + "'");
    nv.addGraph(createChart);
    update();
  }

  initialize();

  return {
    update: update
  }
}
