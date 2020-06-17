# Description:
#   Ping groups
#
# Author:
#   Detry322

module.exports = (robot) ->

  replaceInitials = (users, message) ->
    for own key, user of users
      if user['initials']
        message = message.replace(user['initials'], robot.pingStringForUser(user))
    message

  robot.respond /ping ((.*\s*)+)/, (res) ->
    res.send(replaceInitials(robot.brain.data.users, res.match[1]))

