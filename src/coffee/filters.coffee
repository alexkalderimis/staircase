define (require) ->

  ng = require 'angular'
  L = require 'lodash'
  require 'services'
  pluralize = require 'pluralize'

  Filters = ng.module('steps.filters', ['steps.services'])

  Filters.filter('interpolate', ['version', (v) -> (t) -> String(t).replace(/\%VERSION\%/mg, v)])

  Filters.filter 'count', -> (xs) -> xs?.length or null

  Filters.filter 'values', -> (obj) -> L.values obj

  Filters.filter 'uniq', -> (things) -> L.uniq things

  Filters.filter 'pluralize', -> (thing, n) -> pluralize thing, n

  Filters.filter 'pluralizeWithNum', -> (thing, n) -> pluralize thing, n, true

  Filters.filter 'mappingToArray', -> (obj) ->
    return obj unless obj instanceof Object
    (Object.defineProperty v, '$key', {__proto__: null, value: k} for k, v of obj)

  Filters.filter 'roughDate', Array '$filter', (filters) -> (str) ->
    date = new Date str
    now = new Date()
    rDate;

    minutesAgo = (now.getTime() - date.getTime()) / 60 / 1000
    hoursAgo = minutesAgo / 60
    daysAgo = hoursAgo / 24

    if hoursAgo < 48 && (now.getDate()-1 == date.getDate())
      rDate = "yesterday"

    if hoursAgo < now.getHours()
      if hoursAgo.toFixed() == "1"
        rDate = "today, one hour ago"
      else
        rDate = "today, #{ hoursAgo.toFixed() } hours ago"

    if minutesAgo < 60
      rDate =  "today, #{ minutesAgo.toFixed() } minutes ago"

    if minutesAgo < 2
      rDate = "one minute ago"

    if minutesAgo < 1
      rDate = "a moment ago"

    if rDate
      rDate = filters('date')(str) + " (" +rDate + ")"
    else
      rDate = filters('date')(str)

  return Filters
