define (require) ->

  ng = require 'angular'
  L = require 'lodash'
  ga = require 'analytics'
  require 'services'
  ChooseDialogueCtrl = require './choose-dialogue'

  # Run-time requirements
  injectables = L.pairs
    scope: '$scope'
    route: '$route'
    http: '$http'
    location: '$location',
    params: '$routeParams'
    to: '$timeout'
    console: '$log'
    Q: '$q'
    $modal: '$modal'
    connectTo: 'connectTo'
    meetRequest: 'meetRequest'
    Histories: 'Histories'
    Mines: 'Mines'
    silentLocation: '$ngSilentLocation'
    serviceStamp: 'serviceStamp'
    notify: 'notify'

  # Test to see if two strings overlap.
  overlaps = (x, y) -> x && y && (x.indexOf(y) >= 0 || y.indexOf(x) >= 0)

  # Get the configured service at the given URL.
  atURL = (url) -> (mines) -> L.find mines, (m) -> overlaps m.root, url

  # Turn a configuration object into a tool.
  # Currently just adds a handles() method.
  toTool = (conf) ->
    handles = conf.handles
    providers = conf.provides

    if Array.isArray handles
      conf.handles = (cat) -> handles.indexOf(cat) >= 0
    else
      conf.handles = (cat) -> handles is cat

    if Array.isArray providers
      conf.provides = (x) -> x in providers
    else
      conf.provides = (x) -> x is providers

    conf

  # Decorator to create injecting constructor.
  inject = (fn) -> (injected...) ->
    for [name, _], idx in injectables
      @[name] = injected[idx]
    fn.call @

  Controllers = ng.module 'steps.history.controllers', ['steps.services']

  Controllers.controller 'HistoryCtrl', class HistoryController

    currentCardinal: 0

    @$inject: (snd for [fst, snd] in injectables)

    constructor: inject ->
      @init()
      @startWatching()
      @

    elide: true

    startWatching: ->
      scope = @scope

      scope.$watch 'messages', (msgs) -> null # TODO

      scope.$watchCollection 'idlists', (idlists) =>
        if !scope.datainfo? and idlists.length > 0 then scope.makeactive idlists[0]

      scope.$watchCollection 'items', (items) -> null # TODO

      scope.$watch 'queries', (items) -> null # TODO

      scope.$watch 'lastemitted', (val) =>

        if val?

          if val.what == "list"

            # TODO Straighten out the API for lists.
            if val.root? then root = val.root
            if val.service?.root? then root = val.service.root

            connect = @connectTo root
            connect.then (s) ->
              s.fetchList(val.name).then (res) =>
                scope.datainfo = "#{res.size} #{val.type}s"

          if val.what == "ids"
            scope.datainfo = "#{val.ids.length} #{val.type}s"

          if val.what == "query"
            @unquery val

          listHandlers = []
          for tool in scope.nextTools when tool.handles val.what
            for category in scope.categories
              if tool.ident in category.tools
                listHandlers.push {tool, category: category, data: val}
          scope.nextSteps = listHandlers

    unquery: (qu) ->

      @scope.idlists = []

      {Q} = @

      connection = @connectTo qu.service.root
      connection.then (service) =>

        # For our query into an intermine query
        query = service.query(qu.query).then (imquery) =>

          classes = []

          # Get each class of the query
          for node in imquery.getQueryNodes()
            if node.isClass()
              if node.allDescriptors().length == 1
                idpath = node.allDescriptors().pop().name + ".id"
              else
                idpath = (L.map node.allDescriptors(), (part) -> part.name).join(".") + ".id"

            classes.push idpath

          getCount = (idpath) ->

            deferred = Q.defer()

            service.query(qu.query).then (newquery) ->
              newquery.select(idpath)
              newquery.values().then (values) ->
                filteredIds = L.uniq L.without values, null
                type = newquery.makePath(idpath).getParent().getType()
                parts = newquery.makePath(idpath).allDescriptors()
                parts = parts.slice 0, parts.length - 1
                strings = L.map parts, (part) -> part.name
                label = strings.join " > "
                has =
                  label: label
                  ids: filteredIds
                  type: type.name
                  what: "ids"
                  service: newquery.service
                deferred.resolve has

            deferred.promise

          Q.all( (getCount imclass for imclass in classes) ).then (results) =>
            @scope.idlists.push result for result in results

    init: ->
      {Histories, Mines, params, http, connectTo} = @

      # See below for data fetching to fill these.
      @scope.nextTools ?= []
      @scope.providers ?= []
      @scope.messages ?= {}
      @scope.nextSteps ?= []
      @scope.items ?= {}
      @scope.queries ?= []
      @scope.categories ?= []
      @scope.opennextsteps = false
      @scope.idlists ?= []

      @scope.collapsed = true # Hide details in reduced real-estate view.
      @scope.state = {expanded: false, nextStepsCollapsed: true}
      @currentCardinal = parseInt params.idx, 10
      @scope.history = Histories.get id: params.id
      @scope.steps = Histories.getSteps id: params.id
      @scope.step = Histories.getStep id: params.id, idx: @currentCardinal - 1
      @mines = Mines.all()
      @connectTo = connectTo

      @scope.showtools = (val) => @scope.ccat = val

      @scope.clearcc = => @scope.ccat = null

      @scope.showmenu = => @scope.showsubmenu = true

      @scope.hidemenu = => @scope.showsubmenu = false

      @scope.expandhistory = => @scope.openhistory = true

      @scope.shrinkhistory = => @scope.openhistory = false

      @scope.expandnextsteps = => @scope.opennextsteps = true

      @scope.shrinknextsteps = => @scope.opennextsteps = false

      @scope.showdata = => @scope.ccat = null

      @scope.makeactive = (val) =>

        tmpstep =
          title: "Selected #{val.ids.length} #{val.type}s"
          description: val.label
          data:
            ids: val.ids
            service: val.service
          tool: "show-list"
        # @storeHistory tmpstep
        @scope.lastemitted = val


      toolNotFound = (e) => @to => @scope.error = e

      unless @scope.tool? # tool never changes! to do so breaks the history API.
        @scope.step.$promise.then ({tool}) =>
          http.get('/tools/' + tool)
                .then (({data}) => @scope.tool = data), toolNotFound
          http.get('/tools', params: {capabilities: 'next'})
              .then ({data}) => @scope.nextTools = data.map toTool
      http.get('/tools', params: {capabilities: 'provider'})
          .then ({data}) -> data.map toTool
          .then (providers) => @scope.providers = providers
      http.get('/tool-categories')
          .then ({data}) => @scope.categories = data;

      @scope.step.$promise.then (res) =>
        if res.data.query? then res.data.what = "query"
        @scope.lastemitted = res.data


    saveHistory: ->
      @scope.editing = false
      @scope.history.$save()

    updateHistory: ->
      {Histories, params} = @
      @scope.editing = false
      @scope.history = Histories.get id: params.id

    setItems: -> (key, type, ids) => @set ['items', key], {type, ids}


    # Set scope values using an array of keys.
    # eg: this.set ['foo', 'bar'], 2 == this.scope.foo.bar = 2
    #       (but in a timeout)
    set: ([prekeys..., key], value) -> @to =>
      o = @scope
      for k, i in prekeys
        o = o[k]
      o[key] = value

    hasSomething: (what, data, key) ->
      if data? then data.what = what

      {scope, console, to, Q, mines, connectTo} = @

      return to -> scope.lastemitted = data

      triggerUpdate = -> to -> debugger; scope.messages = L.assign {}, scope.messages

      handlers = (tool for tool in scope.nextTools when tool.handles(what))

      for tool in handlers then do (tool) =>
        idx = tool.ident + what + key
        if data # set or update
          if scope.messages[idx]?
            @set ['messages', idx, 'data'], data
          else
            @connectTo(data['service:base'] ? data.service.root).then (service) =>
              @set ['messages', idx], {tool, data, service, kind: 'msg'}
              triggerUpdate()
        else # delete
          delete scope.messages[idx]

      # trigger the update.
      triggerUpdate() if handlers.length

    letUserChoose: (tools) ->
      dialogue = @$modal.open
        templateUrl: '/partials/choose-tool-dialogue.html'
        controller: ChooseDialogueCtrl
        resolve: {items: tools}

      return dialogue.result

    meetingRequest: (next, data) ->
      if next.length is 1
        @meetRequest(next[0], @scope.step, data)
      else
        @letUserChoose(next).then (provider) => @meetRequest provider, @scope.step, data

    wantsSomething: (what, data) ->
      {notify, console, meetRequest} = @
      console.log "Something is wanted", what, data
      next = @scope.providers.filter (t) -> t.provides what
      console.log "Suitable providers found", next, @scope.providers

      return unless next.length

      @meetingRequest(next, data).then @nextStep, (err) ->
        console.error err
        notify err.message

    storeHistory: (step) -> @nextStep step, true

    stampStep: (step) ->
      {Q, serviceStamp} = @
      if not step.data.service? # Nothing to stamp.
        Q.when step
      else
        serviceStamp(step.data.service).then (stamp) -> L.assign {stamp}, step

    nextStep: (step, silently = false) =>
      {Histories, scope, currentCardinal, console, location, silentLocation} = @
      console.debug "Next step:", step
      console.log "storing - silently? #{ silently }"
      nextCardinal = currentCardinal + 1
      appended = null

      goTo = if silently
        (url) =>
          @params.idx = nextCardinal
          silentLocation.silent url
          @currentCardinal = nextCardinal
          @init()
      else
        (url) -> location.url url

      history = scope.history

      @stampStep(step).then (stamped) ->
        console.log 'STAMPED', stamped
        if history.steps.length isnt currentCardinal
          title = "Fork of #{ history.title }"
          console.debug "Forking at #{ currentCardinal } as #{ title }"
          fork = Histories.fork {id: history.id, at: currentCardinal, title}, ->
            console.debug "Forked history"
            appended = Histories.append {id: fork.id}, stamped, ->
              console.debug "Created step #{ appended.id }"
              goTo "/history/#{ fork.id }/#{ nextCardinal }"
        else
          appended = Histories.append {id: history.id}, stamped, ->
            console.debug "Created step #{ appended.id }"
            goTo "/history/#{ history.id }/#{ nextCardinal }"
            ga 'send', 'event', 'history', 'append', step.tool

  Controllers.controller 'HistoryStepCtrl', Array '$scope', '$log', '$modal', 'Mines', (scope, log, modalFactory, Mines) ->


    scope.$watch 'appView.elide', ->
      scope.elide = scope.appView.elide && scope.$middle && (scope.steps.length - scope.$index) > 3

    InputEditCtrl = Array '$scope', '$modalInstance', 'history', 'step', (scope, modal, history, step, index) ->

      scope.data = L.clone step.data, true
      delete scope.data.service # Not editable

      scope.ok = ->
        modal.close history.id, index, scope.data

      scope.cancel = ->
        modal.dismiss 'cancel'
        scope.data = L.clone step.data, true


    scope.openEditDialogue = ->
      dialogue = modalFactory.open
        templateUrl: '/partials/edit-step-data.html'
        controller: InputEditCtrl
        size: 'lg'
        resolve:
          index: -> scope.$index
          history: -> scope.history
          step: -> scope.s
