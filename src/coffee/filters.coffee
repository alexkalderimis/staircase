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

    ###*
     * Adds rough temporal relativity to date, e.g. "3 hours ago". Doesn't add anything to dates older than yesterday.
     * @return {String}         imDate string, with temporal relative description if applicable
    ###
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
        rDate = "one hour ago"
      else
        rDate = "#{ hoursAgo.toFixed() } hours ago"

    if minutesAgo < 60
      rDate =  "#{ minutesAgo.toFixed() } minutes ago"

    if minutesAgo < 2
      rDate = "one minute ago"

    if minutesAgo < 1
      rDate = "a moment ago"

    if rDate
      rDate = filters('imDate')(str) + " (" +rDate + ")"
    else
      rDate = filters('imDate')(str)

  ###*
   * the imDate filter outputs dates in the format YYYY-MM-DD HH:mm.
   * This should be the default date standard used throughout Steps.
   * (Unfortunately there's no way in angular to set the default
   * format for the vanilla 'date' filter).
   * @param  {dateString} str the date to format, suitable for initialising via new Date()
   * @return {String}         returns date matching format YYYY-MM-DD HH:mm.
  ###

  Filters.filter 'imDate', Array '$filter', (filters) -> (str) ->
    imDateFilter = filters('date')
    theDate = new Date str
    imDateFilter theDate, 'yyyy-MM-dd HH:mm'

  return Filters
