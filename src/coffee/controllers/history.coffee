define ['lodash'], (L) ->
  injectables = ['$scope', '$http', '$location', '$routeParams', '$timeout', 'makeList', 'Histories']

  Array injectables..., (scope, http, location, params, to, makeList, Histories) ->

    scope.nextTools = []
    scope.collapsed = true # Hide details in reduced real-estate view.
    scope.items = {}

    currentCardinal = parseInt params.idx, 10
    scope.history = Histories.get id: params.id
    scope.steps = Histories.getSteps id: params.id
    scope.step = Histories.getStep id: params.id, idx: currentCardinal - 1
    scope.step.$promise.then ({tool}) ->
      http.get('/tools/' + tool).then ({data}) -> scope.tool = data
      http.get('/tools', {params: {capabilities: 'next'}})
          .then ({data}) -> scope.nextTools = data.filter (nt) -> nt.ident isnt tool

    scope.nextSteps = []

    scope.$watchCollection 'items', ->
      console.log "Items changed"
      exporters = []
      for tool in scope.nextTools when tool.handles is 'items'
        for key, data of scope.items when data.ids.length
          exporters.push {key, data, tool}
      otherSteps = (s for s in scope.nextSteps when s.tool.handles isnt 'items')
      scope.nextSteps = otherSteps.concat(exporters)

    scope.$watch 'list', ->
      listHandlers = []
      for tool in scope.nextTools when tool.handles is 'list'
        listHandlers.push {tool, data: scope.list}
      otherSteps = (s for s in scope.nextSteps when s.tool.handles isnt 'list')
      scope.nextSteps = otherSteps.concat(listHandlers)
      console.log listHandlers

    scope.saveHistory = ->
      scope.editing = false
      scope.history.$save()

    scope.updateHistory  = ->
      scope.editing = false
      scope.history = Histories.get id: params.id

    scope.setItems = (key, type, ids) -> to -> scope.items[key] = {type, ids}

    scope.hasSomething = (what, data) ->
      if what is 'list'
        to -> scope.list = data
      else if what is 'ids'
        category = scope.step.data.request?.extra
        makeList.fromIds(data, category).then (list) ->
          scope.nextStep
            title: "Created list #{ list.name }"
            tool: 'show-list'
            data:
              listName: list.name
              service: data.service

    scope.nextStep = (step) ->
      step = Histories.append {id: scope.history.id}, step, ->
        console.log "Created step " + step.id
        location.url "/history/#{ scope.history.id }/#{ currentCardinal + 1 }"

