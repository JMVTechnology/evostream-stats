function TextStatsCtrl($scope, $http, $timeout) {
  $scope.stats = [];
  $scope.what = 'online';
  $scope.interval = 5000;
  var t;

  var poll = function() {
    function again() {
      $timeout.cancel(t);
      t = $timeout(function() {
            poll($scope.interval)
          }, $scope.interval);
    }

    $http.get('/api/online').
      success(function(data) {
        $scope.stats = data;
        again();
      }).
      error(again);
  }

  $scope.setWhat = function(what) {
    $scope.what = what;
  }

  $scope.setInterval = function(interval) {
    $scope.interval = interval;
  }

  $scope.getActiveClass = function(active) {
    if (active == true)
      return 'success';

    return 'danger';
  }
  poll();
}
