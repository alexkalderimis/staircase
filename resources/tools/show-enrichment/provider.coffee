define [], ->

  handleRequest = Array '$q', (Q) -> (previousStep, data) ->
    Q.when
      title: "Enrichment: #{ data.request.enrichment }"
      tool: "show-enrichment"
      data: data

  return handleRequest
