define ['imjs'], ({Service}) -> Array '$scope', 'Mines', (scope, mines) ->

  scope.list = scope.data

  scope.activate = ->
    step =
      title: "Made list: " + scope.list.name
      tool: "show-list"
      data:
        service:
          root: scope.list.root
        listName: scope.list.name

    scope.appendStep data: step
