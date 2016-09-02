# Description:
#   Fun responses
#
# Commands:
#   hubot vans <url>
#
# Author:
#   Detry322

module.exports = (robot) ->
  robot.router.get '/vans', (req, res) ->
    url = robot.brain.get('vans-link-update') or 'http://pkt.mit.edu'
    res.redirect(url)
    
  robot.respond /vans (.+)/i, (res) ->
    robot.brain.set('vans-link-update', res.match[1])
    res.send "Set vans link to " + res.match[1]
