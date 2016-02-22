# Description:
#   Hubot interface to unlock the front door
#
# Commands:
#   hubot unlock - unlocks the front door.
#
# Configuration:
#   HUBOT_UNLOCK_URL
#   HUBOT_UNLOCK_KEY
#   HUBOT_UNLOCK_ACTION
#
# Author:
#   Detry322

module.exports = (robot) ->

  config = require('hubot-conf')('unlock', robot)

  makeURL = (user) ->
    "#{config('url')}?key=#{config('key')}&action=#{config('action')}&username=#{user}"

  robot.respond /unlock/i, (res) ->
    user = res.message.user.name.toLowerCase()
    robot.http(makeURL(user)).get() (err, response, body) ->
      if err or response.statusCode isnt 200
        res.send "Something went wrong trying to unlock the door"
        return
      res.send "Door unlocked."

