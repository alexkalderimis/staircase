define (require, module, exports) ->
  L = require 'lodash'
  {Service} = require 'imjs',
  DialogueCtrl = require './dialogue'
  DialogueTempl = require 'text!./dialogue.html'

  Array '$scope', '$modal', '$q', 'connectTo', (scope, Modals, Q, connectTo) ->

    scope.type = scope.data.type
    scope.listName = scope.data.name
    scope.services = []

    step = scope.previousStep
    # TODO: make this consistent.
    origin = (step.data.url or step.data.root or step.data.service.root)
    connect = connectTo(origin).then (s) -> scope.service = s

    scope.activate = ->
      injected =
        service: -> connect
        model: -> connect.then (s) -> s.fetchModel()
        lists: -> connect.then (s) -> s.fetchLists()
        list: -> connect.then (s) -> s.fetchList scope.listName

      modalInstance = Modals.open
        template: DialogueTempl
        controller: DialogueCtrl
        resolve: injected

      modalInstance.result.then (list) ->
        step =
          title: "Created: #{ list.name }"
          tool: 'show-list'
          data:
            service: L.pick(scope.service, 'root')
            listName: list.name

        scope.appendStep data: step
