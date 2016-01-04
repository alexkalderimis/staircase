define (require) ->

  ng = require 'angular'
  require 'services'

  Controllers = ng.module 'steps.quick-search.controllers', ['steps.services']

  Controllers.controller 'QuickSearchController', class QuickSearchController

    @$inject = ['$log', '$scope', 'historyListener','Mines']

    constructor: (log, scope, {startHistory}, Mines) ->
      scope.startQuickSearchHistory = (term) ->
        Mines.all().then (mines) ->
          startHistory
            thing: "for #{ term }"
            verb:
              ed: "searched"
              ing: "searching"
            tool: "keyword-search"
            data:
              searchTerm: term
              mines : mines
