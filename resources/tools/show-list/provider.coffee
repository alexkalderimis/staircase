define [], ->

  injectables = ['$q', '$log', 'makeList', 'identifyItem']

  factory = (Q, console, makeList, identifyItem) -> (previousStep, data) ->
    if data.objectIds?
      category = previousStep.data.request?.extra
      makeList.fromIds(data, category).then (list) ->
        title: "New list: #{ list.name }"
        tool: 'show-list'
        data:
          listName: list.name
          service: data.service
    else if data.item?
      # data :: {service, item}
      identifyItem(data.service, data.item).then (fields) ->
        title: "Viewed item",
        tool: 'show-list'
        data:
          item:
            type: data.item.type
            fields: fields
          service: data.service
    else if query = (data.request?.query ? data.query)
      makeList.fromQuery(query, data.service).then (list) ->
        title: "New list: #{ list.name }"
        tool: 'show-list'
        data:
          listName: list.name
          service: data.service
    else
      console.error "Don't know how to make a list from", data
      Q.reject 'Unable to handle request'

  return [injectables..., factory]
