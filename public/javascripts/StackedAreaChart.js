var StackedAreaChart = function(name, interval) {
  var chart;
  var frozen = false;
  var timespan = 0;
  var currentDataLength = 0;

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
    if (frozen)
      return;

    $.ajax({
      url: '/api/stats/' + name + '?timespan=' + timespan,
      type: 'GET',
      dataType: 'json',
      success: function(data) {
        if (data.length > 0 && data[0].values.length == currentDataLength)
          transition = 300;
        else
          transition = 0;

        d3.select('#chart-' + name)
          .datum(data)
          .transition().duration(transition)
          .call(chart);

        chart.update;

        if (data.length > 0)
          currentDataLength = data[0].values.length;
        else
          currentDataLength = 0;
      },
      complete: setTimeout(function() { update(); }, interval),
    });
  };

  var toggleFreeze = function() {
    frozen = !frozen;

    if (!frozen)
      update();
  }

  var setTimespan = function(sec) {
    console.log('Setting timespan to: ' + sec)
    timespan = sec;
    update();
  }

  var initialize = function() {
    console.info("creating graph '" + name + "'");
    nv.addGraph(createChart);
    update();
  }

  initialize();

  return {
    update: update,
    toggleFreeze: toggleFreeze,
    setTimespan: setTimespan,
  }
}
