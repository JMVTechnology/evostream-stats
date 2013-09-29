var TextStats = function(what, interval) {
  var timeout;

  var update = function() {
    $.ajax({
      url: '/api/online',
      type: 'GET',
      dataType: 'json',
      success: function(data) {

        $.each(data, function(title, section) {
          var list = ''

          $.each(section, function(name, stats) {
            if (stats['active'] == false)
              klass = 'danger';
            else
              klass = 'success';

            // templates are defined outside of class
            list += onlineStatsLiTemplate({key: name, value: stats[what], klass: klass});
          });

          var html = onlineStatsHeaderTemplate({title: title, list: list})
          $('#stats-' + title).html(html);
        });
      },
      complete: function() {
        clearTimeout(timeout);
        timeout = setTimeout(update, interval);
      },
    });
  }

  var setWhat = function(that) {
    what = that;
    update();
  }

  var initialize = function() {
    update();
  }

  initialize();

  return {
    update: update,
    setWhat: setWhat,
  }
}
