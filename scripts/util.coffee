# Description:
#   Utilities
#  Commands:
#   hubot duties - gets your upcoming duties
#   hubot duties XXX - gets XXX's upcoming duties
#   hubot duties upcoming - gets the upcoming houseworks
#   hubot duties link - return master spreadsheet link
# Author:
#   anishathalye

shallowClone = (obj) ->
  copy = {}
  for own key, value of obj
    copy[key] = value
  copy.__proto__ = obj.__proto__ # not standard in ECMAScript, but it works
  return copy

module.exports = (robot) ->

  robot.pingStringForUser = (user) -> "<@#{user['id']}>"

  config = require('hubot-conf')('util', robot)

  # a hacky way to override the shortcut prefix
  robot.hear /(.*)/, (res) ->
    prefix = config('shortcut.prefix')
    if prefix?
      text = res.match[1]
      matches = text.match(///^\s*#{prefix}([a-z]+)(\s+.*)?///)
      if matches?
        args = matches[2] ? ''
        msg = shallowClone(res.message)
        msg.text = "!#{matches[1]}#{args}"
        robot.receive msg

  robot.respond /clear$/, (res) ->
    res.send ("." for n in [1..60]).join "\n"

  if robot.adapterName == "slack"
    robot.logger.info "Adapter is slack: will terminate on client close"
    robot.adapter.client.on 'close', () ->
      process.exit(0)
  else
    robot.logger.info "Adapter is not slack, will not terminate on client close"
