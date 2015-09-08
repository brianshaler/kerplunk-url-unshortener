_ = require 'lodash'
Promise = require 'when'
Promisify = require('when/node').lift
unshort = Promisify require 'unshort'

pattern = /\b(https?):\/\/([\-a-z0-9\.]+\.[\-a-z0-9]+)(\/[a-z0-9\-_?&@#\/%=~_()|!:,.;]*[\-a-z0-9+&@#\/%=~_|])?\b/gi

containsUrl = (str) ->
  pattern.test str

recursivelyUnshorten = (url, stack = 10) ->
  unshort url
  .then (newUrl) ->
    # console.log 'url', url, '->', newUrl
    if newUrl == url
      url
    else
      recursivelyUnshorten newUrl, stack - 1

unshortenUrlsInMessage = (message) ->
  urls = message.match pattern
  Promise.all _.map urls, (url) ->
    recursivelyUnshorten url
    .then (newUrl) ->
      message = message.replace url, newUrl
  .then ->
    message

module.exports = (System) ->
  ActivityItem = null

  preSave = (item) ->
    if item.attributes?.unshortened
      # console.log 'not re-shortening', item.message
      return item
    unless containsUrl item.message
      # console.log 'no urls', item.message
      return item
    unshortenUrlsInMessage item.message
    .then (message) ->
      if typeof message is 'string' and message.length > 0
        item.message = message
      item.attributes = {} unless item.attributes
      item.attributes.unshortened = true
      # console.log 'unshortened', message
      item

  # fn.precedence is a hack to declare an order of execution
  # -1 should let this run before neutral (0) filters run
  # neutral plugins will probably care more about unshortened url
  preSave.precedence = -1

  events:
    activityItem:
      save:
        pre: preSave
