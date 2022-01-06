# Description:
#   interface to unlock the front door
#
# Commands:
#   door unlock - unlocks the front door.
#   door register <person's name> - dry-run register the most recently tapped card in the last 5 minutes
#   door actually register <person's name> - *actually* register most recently tapped card in the last 5 minutes
#   door card list - list cards added by you
#   door card list all - list all cards globally
#   door card info <card id> - show verbose card information
#   door card activate <card id> - activate card
#   door card deactivate <card id> - deactivate card (ignores expiry date, disables card use)
#   door card adjust <card id> minutes|hours|days|weeks|months <value> - extend or shorten expiry date by a positive/negative integer <value>
#   door card last - show last failed card tap attempt
#
# Author:
#   craids

moment = require('moment')
QS = require('querystring') 
totp = require("totp-generator");
module.exports = (robot) ->

  config = require('hubot-conf')('unlock', robot)

  makeUnlockURL = () ->
    "#{config('url')}/door/unlock"

  makeLastURL = () ->
    "#{config('url')}/card/get/lastfail"

  makeTestRegisterURL = (sponsor, name) ->
    "#{config('url')}/card/test/register/#{name}/#{sponsor}"

  makeRegisterURL = (sponsor, name) ->
    "#{config('url')}/card/register/#{name}/#{sponsor}"

  makeMyCardsURL = (sponsor) ->
    "#{config('url')}/card/get/bysponsor/#{sponsor}"

  makeAllCardsURL = () ->
    "#{config('url')}/card/get/all"

  makeCardInfoURL = (card_id) ->
    "#{config('url')}/card/get/byid/#{card_id}"

  makeActivateURL = (card_id) ->
    "#{config('url')}/card/activate/#{card_id}"

  makeDeactivateURL = (card_id) ->
    "#{config('url')}/card/deactivate/#{card_id}"

  makeAdjustURL = (card_id, minutes, hours, days, weeks, months) ->
    "#{config('url')}/card/adjust/#{card_id}/#{minutes}/#{hours}/#{days}/#{weeks}/#{months}"

  makePingURL = () ->
    "#{config('url')}/door/info"

  pecklockRequest = (res, url) ->
    hdrs =
      'Pecklock-Token': config('key')
      'Pecklock-Performed-By': res.message.user.email_address

    return robot.http(url).headers(hdrs)

  unlock = (res) ->
    # pecklockRequest(res, makeUnlockURL()).get() (err, response, body) ->
    #   if err or response.statusCode isnt 200
    #     res.send "Something went wrong trying to unlock the door: #{body}"
    #     return 
    res.send "Door code is " + config('unlock'))#totp(config('unlockkey'),{'digits':6, 'period':300})

  register = (name, res) ->
    res.send "Enter the following key then scan #{name}'s card to register it: " + config('enroll'))#totp(config('enrollkey'),{'digits':6, 'period':300})
    # pecklockRequest(res, makeRegisterURL(res.message.user.email_address, name)).get() (err, response, body) ->
    #   if err or response.statusCode >= 400
    #     res.send "Error registering #{name}'s card: #{body}"
    #     return
    #   res.send body
#        robot.messageRoom config('announce'), "#{robot.pingStringForUser(res.message.user)} added *#{name}*'s card to the door unlock system."

  robot.respond /(door )?unlock/i, (res) ->
    # res.send "Unlocking door..."
    unlock(res)

  robot.respond /door register (.+)$/i, (res) ->
    # name = res.match[1]
    # res.send "This is a card registration *dry run*, which uses the latest tapped _unregistered_ card in the *last 5 minutes*."
    # pecklockRequest(res, makeTestRegisterURL(res.message.user.email_address, name)).get() (err, response, body) ->
    #   if err or response.statusCode >= 400
    #     res.send "Dry run failed: #{body}"
    #     return
    #   res.send body
    #   res.send "If you are sure you want to register this card, run `peckbot door actually register <person's name>`"
    user = res.match[1]
    register(user, res)

  robot.respond /door actually register (.+)$/i, (res) ->
    user = res.match[1]
    register(user, res)
  
  robot.respond /door echo(.*)$/i, (res) ->
    res.send res.message.user.name + ': ' + res.message.user.email_address

  robot.respond /door card last(.*)$/i, (res) ->
    pecklockRequest(res, makeLastURL()).get() (err, response, body) ->
      if err or response.statusCode isnt 200
        res.send "Something went wrong trying to get the last failed card auth attempt: #{body}"
        return
      res.send body

  robot.respond /door card list$/i, (res) ->
    pecklockRequest(res, makeMyCardsURL(res.message.user.email_address)).get() (err, response, body) ->
      if err or response.statusCode isnt 200
        res.send "Something went wrong trying to fetch your cards: #{body}"
        return
      res.send body

  robot.respond /door card list all$/i, (res) ->
    pecklockRequest(res, makeAllCardsURL()).get() (err, response, body) ->
      if err or response.statusCode isnt 200
        res.send "Something went wrong trying to fetch all cards: #{body}"
        return
      res.send body

  robot.respond /door card activate (.+)$/i, (res) ->
    card_id = res.match[1]
    pecklockRequest(res, makeActivateURL(card_id)).get() (err, response, body) ->
      if err or response.statusCode isnt 200
        res.send "Something went wrong when trying to activate card: #{body}"
        return
      res.send body

  robot.respond /door card deactivate (.+)$/i, (res) ->
    card_id = res.match[1]
    pecklockRequest(res, makeDeactivateURL(card_id)).get() (err, response, body) ->
      if err or response.statusCode isnt 200
        res.send "Something went wrong when trying to deactivate card: #{body}"
        return
      res.send body

  robot.respond /door card adjust (.*) minutes (.*)$/i, (res) ->
    card_id = res.match[1]
    minutes = res.match[2]
    pecklockRequest(res, makeAdjustURL(card_id, minutes, 0, 0, 0, 0)).get() (err, response, body) ->
      if err or response.statusCode isnt 200
        res.send "Something went wrong when trying to adjust card validity: #{body}"
        return
      res.send body

  robot.respond /door card adjust (.*) hours (.*)$/i, (res) ->
    card_id = res.match[1]
    hours = res.match[2]
    pecklockRequest(res, makeAdjustURL(card_id, 0, hours, 0, 0, 0)).get() (err, response, body) ->
      if err or response.statusCode isnt 200
        res.send "Something went wrong when trying to adjust card validity: #{body}"
        return
      res.send body

  robot.respond /door card adjust (.*) days (.*)$/i, (res) ->
    card_id = res.match[1]
    days = res.match[2]
    pecklockRequest(res, makeAdjustURL(card_id, 0, 0, days, 0, 0)).get() (err, response, body) ->
      if err or response.statusCode isnt 200
        res.send "Something went wrong when trying to adjust card validity: #{body}"
        return
      res.send body

  robot.respond /door card adjust (.*) weeks (.*)$/i, (res) ->
    card_id = res.match[1]
    weeks = res.match[2]
    pecklockRequest(res, makeAdjustURL(card_id, 0, 0, 0, weeks, 0)).get() (err, response, body) ->
      if err or response.statusCode isnt 200
        res.send "Something went wrong when trying to adjust card validity: #{body}"
        return
      res.send body

  robot.respond /door card adjust (.*) months (.*)$/i, (res) ->
    card_id = res.match[1]
    months = res.match[2]
    pecklockRequest(res, makeAdjustURL(card_id, 0, 0, 0, 0, months)).get() (err, response, body) ->
      if err or response.statusCode isnt 200
        res.send "Something went wrong when trying to adjust card validity: #{body}"
        return
      res.send body

  robot.respond /door card info (.*)$/i, (res) ->
    card_id = res.match[1]
    pecklockRequest(res, makeCardInfoURL(card_id)).get() (err, response, body) ->
      if err or response.statusCode isnt 200
        res.send "Something went wrong when trying to fetch card info: #{body}"
        return
      res.send body

  robot.respond /door ping(.*)$/i, (res) ->
    pecklockRequest(res, makePingURL()).get() (err, response, body) ->
      if err or response.statusCode isnt 200
        res.send "Something went wrong when trying to ping door: #{body}"
        return
      res.send body

  robot.router.post '/unlock/:secret', (req, res) ->
    if req.params.secret == process.env.HUBOT_SCRIPTS_SECRET
      unlock(res)
    else
      res.send "That isn't the correct secret"

