define [], -> Array '$scope', (scope) ->

  scope.$watch 'data', (data) ->
    scope.type = type = data.type

    if data.id?
      scope.n = data.id.length
      scope.query =
        select: ['*']
        from: type
        where: [{path: type, op: 'IN', ids: scope.data.id}]
    else if data.query
      scope.type = 'result'
      scope.query = data.query

  scope.activate = ->
    scope.previousStep.$promise.then ->

      step =
        title: "Export results"
        tool: scope.tool.ident
        data:
          query: scope.query
          service:
            root: scope.previousStep.data.service.root

      scope.appendStep data: step
