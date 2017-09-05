# Description:
#   Ping groups
#
# Author:
#   Detry322

replaceInitials = (users, message) ->
  for own key, user of users
    if user['initials']
      message = message.replace(user['initials'], "<@#{user['name']}>")
  message

module.exports = (robot) ->

  robot.respond /ping ((.*\s*)+)/, (res) ->
    res.send(replaceInitials(robot.brain.data.users, res.match[1]))

