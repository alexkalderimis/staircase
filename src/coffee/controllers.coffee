define (require) ->

  ng = require 'angular'
  L = require 'lodash'
  imjs = require 'imjs'
  require 'angular-cookies'
  require 'services'
  require 'projects'
  require 'starting-point'
  require 'facets/controller'
  require 'auth/controller'
  require 'quick-search/controller'
  require 'history/controllers'

  Controllers = ng.module('steps.controllers', [
    'ngCookies', 'steps.services', 'ngAnimate'
    'steps.projects',
    'steps.starting-point',
    'steps.auth.controllers',
    'steps.quick-search.controllers',
    'steps.history.controllers'
  ])

  requiredController = (ident) -> Array '$scope', '$injector', ($scope, injector) ->
    require ['controllers/' + ident], (ctrl) ->
      instance = injector.instantiate(ctrl, {$scope})
      $scope.controller = instance # Working around breakage of controllerAs
      $scope.$apply()

  mountController = (name, ident) -> Controllers.controller name, requiredController ident

  Controllers.controller 'FooterCtrl', Array '$scope', '$cookies', (scope, cookies) ->
    scope.showCookieMessage = cookies.ShowCookieWarning isnt "false"

    scope.$watch "showCookieMessage", -> cookies.ShowCookieWarning = String scope.showCookieMessage

  Controllers.controller 'WelcomeCtrl', Array '$scope', (scope) -> scope.showWelcome = true

  # Index does very little just now - but we still need a controller.
  Controllers.controller 'IndexCtrl', ->

  Controllers.controller 'AboutCtrl', Array '$http', '$scope', 'historyListener', (http, scope, historyListener) ->
    http.get('/tools', {params: {capabilities: 'initial'}})
        .then ({data}) ->
          scope.tool = L.chain(data).where(width: 1).find('description').value()
          scope.tool.expandable = false

    historyListener.watch scope

  mountController 'StartingPointsController', 'starting-points'

  mountController 'BrandCtrl', 'brand'

  mountController 'NavCtrl', 'brand'
