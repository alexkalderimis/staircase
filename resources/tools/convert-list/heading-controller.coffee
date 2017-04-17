# There are some MASSIVE problems with this tool - it assumes a huge amount
# of knowledge about the data model, it is fragile, it is bio-only. It will
# fail if identifiers have commas in them. We desperately need a better
# federation mechanism.
define ['imjs', 'lodash'], ({Service}, L) ->

  Array '$scope', '$q', 'notify', 'Mines', 'connectTo', 'makeList', (scope, Q, notify, mines, connectTo, makeList) ->

    scope.type = scope.data.type
    currentList = scope.data.name

    scope.services = []

    step = scope.previousStep
    # TODO: make this consistent.
    origin = (step.data.url or step.data.root or step.data.service.root)

    mines.all().then (services) ->
      scope.services = (Object.create(s) for s in services \
                                        when Service.connect(s).root isnt origin)

    getService = connectTo(origin).then (originatingService) -> scope.origin = originatingService

    getService.then (s) -> s.fetchModel()
              .then (model) -> scope.isGene = model.makePath(scope.type).isa 'Gene'

    getService.then (s) ->
      getOrgCount = s.count
        select: 'organism.shortName'
        from: 'Gene'
        where: [['Gene', 'IN', currentList]]
      Q.when(getOrgCount).then (c) -> scope.singleOrganism = c is 1

    scope.activate = (service) ->
      service.running = true
      targetSpecies = service.meta.covers
      targetService = Service.connect service

      contentQ =
        select: ['primaryIdentifier', 'organism.shortName']
        from: 'Gene'
        where: [[scope.data.type, 'IN', currentList]]

      # Ask the other service what they know about our genes.
      lookForHomologuesInRemote = -> scope.origin.rows(contentQ).then (details) ->
        [idents, [org]] = L.unzip details
        q =
          select: ['id']
          from: 'Gene'
          where: [
            ['organism.shortName', 'ONE OF', targetSpecies]
            ['homologues.homologue', 'LOOKUP', idents.join(',')]
            ['homologues.homologue.organism.shortName', '=', org]]
        targetService.values q

      lookForHomologuesInOrigin = ->
        q =
          select: ['primaryIdentifier']
          from: 'Gene'
          where: [
            ['organism.shortName', 'ONE OF', targetSpecies]
            ['homologues.homologue', 'IN', currentList]]
        scope.origin.values(q)

      makeIdListInOther = (ids) ->
        details = name: "Genes from #{ currentList } in #{ scope.origin.name } (#{ new Date() })"
        makeList.fromIds listDetails: details, objectIds: ids, type: 'Gene', service: targetService

      makeIdentifierListInOther = (idents) ->
        details = name: "Genes from #{ currentList } in #{ scope.origin.name } (#{ new Date() })"
        q =
          select: 'id'
          from: 'Gene'
          where: ['primaryIdentifier', 'ONE OF', idents]

        makeList.fromQuery q, targetService, details

      service.state = "Querying #{ service.name }"
      ret = lookForHomologuesInRemote().then (ids) ->
        if ids.length
          makeIdListInOther ids
        else
          service.state = "Querying #{ scope.origin.name }"
          lookForHomologuesInOrigin().then (identifiers) ->
            if identifiers.length
              makeIdentifierListInOther identifiers
            else
              throw new Error 'No matches found'

      done = (list) ->
        service.running = false
        scope.appendStep data:
          title: "Migrated: '#{ currentList }' to #{ service.name }"
          tool: 'show-list'
          data:
            listName: list.name
            service: {root: service.root}

      failed = (err) ->
        notify err.message
        service.running = false

      Q.when(ret).then done, failed
