# Description:
#   Gets the initials of brothers in PKT
#
# Commands:
#   hubot initials add <initials> <year> <name> - Adds person to initials database
#   hubot initials get <initials> - Returns the person with the given initials.
#
# Author:
#   Detry322

module.exports = (robot) ->

  robot.respond /initials add ([A-Z]{3}) ([0-9]{2}) (.+)$/, (res) ->
    initials = res.match[1].toUpperCase()
    year = parseInt(res.match[2])
    name = res.match[3]
    initials_table = robot.brain.get('pkt-initials') or {}
    initials_table[initials] = {
      initials: initials,
      year: year,
      name: name
    }
    robot.brain.set('pkt-initials', initials_table)
    res.send "Added *#{initials}*: #{name}, PKT '#{year}"

  robot.respond /initials get ([A-Z]{3})$/i, (res) ->
    initials = res.match[1].toUpperCase()
    initials_table = robot.brain.get('pkt-initials') or {}
    if initials_table[initials]?
      person = initials_table[initials]
      res.send "*#{person['initials']}*: #{person['name']}, PKT '#{person['year']}"
    else
      res.send "No one with initials #{initials} exists."
