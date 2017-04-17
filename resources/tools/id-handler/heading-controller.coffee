define ['imjs'], ({Service}) -> Array '$scope', '$timeout', 'makeList', (scope, to, makeList) ->

  scope.mineName = ""
  scope.typeName = scope.data?.request?.type

  scope.$watch 'service', (service) ->
    return unless service?
    to -> scope.mineName = service.name
    service.fetchModel().then (model) ->
      p = model.makePath(scope.data.request.type).getDisplayName().then (name) -> to ->
        scope.typeName = name

      p.then null, console.error.bind(console, 'Err')

  scope.showTable = ->
    step =
      title: "Query: #{ scope.typeName }"
      tool: "show-table"
      data:
        service:
          root: scope.data.service.root
        query:
          from: scope.data.request.type
          select: ['*']
          constraints: [ {path: scope.data.request.type, op: 'IN', ids: scope.data.request.ids} ]

    scope.appendStep data: step

  scope.makeList = ->
    listReq =
      objectIds: scope.data.request.ids
      type: scope.data.request.type
      service: scope.data.service
    makeList.fromIds(listReq).then (list) ->
      step =
        title: "Created list #{ list.name }"
        tool: 'show-list'
        data:
          listName: list.name
          service: listReq.service

      scope.appendStep data: step
