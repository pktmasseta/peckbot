# Description:
#   Returns a Hearthstone cards's stats
#
# Dependencies:
#   None
#
# Commands:
#   @<Hearthstone card> - Return <Hearthstone card>'s stats: name - mana - race - type - attack/hlth - descr
#   @more <Hearthstone card> - Return more of the <Hearthstone card>'s stats
#
# Author:
#   sylturner, edits by Detry322
#

getByName = (json, name) ->
  json.filter (card) ->
    card.name.toLowerCase() is name.toLowerCase()

fetchCard = (res, name, callback) ->
  res.http('http://hearthstonecards.herokuapp.com/hearthstone.json').get() (err, res, body) ->
    data = JSON.parse(body)
    card = getByName(data, name)
    callback(card)

sendCard = (res, card) ->
  if card.length > 0
    res.send "#{card[0].name} - Mana: #{card[0].mana} - Race: #{card[0].race} - Type: #{card[0].type} - Attack/Health: #{card[0].attack}/#{card[0].health} - Descr: #{card[0].descr}"
    res.send "Flavor: #{card[0].flavorText} Rarity: #{card[0].rarity}"
    res.send "http://hearthstonecards.herokuapp.com/cards/medium/#{card[0].image}.png"
  else
    res.send "I can't find that card"

module.exports = (robot) ->

  robot.hear /hearthstone (.+)$/, (res) ->
    name = res.match[1]
    fetchCard res, name, (card) ->
      sendCard(res, card)

