define ['angularMocks', 'filters'], (mocks) ->

describe 'Filters', ->
  'use strict'

  test = {}

  beforeEach ->
    module 'steps.filters'
    inject (_$filter_) ->
      test.$filter = _$filter_

  describe 'roughDate', ->
    beforeEach ->
      test.historyTime = new Date()

    it 'should not append a rough date to the day before yesterday', ->
      twoDaysAgo = test.historyTime.setDate(test.historyTime.getDate()-2);
      formattedDate = test.$filter('imDate')(twoDaysAgo)
      result = test.$filter('roughDate')(twoDaysAgo)
      # Assert.
      expect(result).toEqual formattedDate

    it 'should append "a moment ago" to dates less than 1 minute ago.', ->
      thirtySecsAgo = test.historyTime.setSeconds(test.historyTime.getSeconds()-30)
      formattedDate = test.$filter('imDate')(thirtySecsAgo)
      result = test.$filter('roughDate')(thirtySecsAgo)

      expect(result).toEqual formattedDate + ' (a moment ago)'

    it 'should append "one minute ago" to anything less than two minutes ago.', ->
      lessThanTwoMinsAgo = test.historyTime.setSeconds(test.historyTime.getSeconds()-110)
      formattedDate = test.$filter('imDate')(lessThanTwoMinsAgo)
      result = test.$filter('roughDate')(lessThanTwoMinsAgo)

      expect(result).toEqual formattedDate + ' (one minute ago)'

    it 'should append "x minutes ago" to anything less than an hour and more than two minutes ago.', ->
      someTimeAgo = test.historyTime.setMinutes(test.historyTime.getMinutes()-33)
      formattedDate = test.$filter('imDate')(someTimeAgo)
      result = test.$filter('roughDate')(someTimeAgo)

      expect(result).toEqual formattedDate + ' (33 minutes ago)'

    it 'should append "x hours ago" to anything after midnight last night and more than an hour ago.', ->
      someTimeAgo = test.historyTime.setHours(test.historyTime.getHours()-2)
      formattedDate = test.$filter('imDate')(someTimeAgo)
      result = test.$filter('roughDate')(someTimeAgo)

      expect(result).toEqual formattedDate + ' (2 hours ago)'

    #We test the first second of yesterday. Otherwise this test could fail depending on the time of day it's run.
    #Hopefully we'll never encounter the possible scenario of running this test at midnight and it failing? There's only a single second window where this could happen.
    it 'should append "yesterday" to anything that does not meet the categories above and is before midnight yesterday', ->
      test.historyTime.setDate(test.historyTime.getDate()-1)
      test.historyTime.setHours(0)
      someTimeAgo = test.historyTime.setMinutes(0)
      someTimeAgo = test.historyTime.setMinutes(1)
      formattedDate = test.$filter('imDate')(someTimeAgo)
      result = test.$filter('roughDate')(someTimeAgo)

      expect(result).toEqual formattedDate + ' (yesterday)'

  describe 'imDate', ->
    it 'should return dates in the format 2014-01-08 13:14', ->
      reg = /\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}/
      result = test.$filter('imDate')(new Date())
      expect(reg.test(result)).toEqual true
