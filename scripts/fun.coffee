# Description:
#   Fun responses
#
# Commands:
#   hubot rolldie
#   hubot park
#   hubot order66 <something>
#
# Author:
#   Detry322

waitingForIota = false

url = require("url")

randomInt = (low, high) ->
  Math.floor(Math.random() * (high - low) + low);

module.exports = (robot) ->


  chantParts = [
    "PHI",
    "IOTA",
    "KAPPA",
    "ALPHA",
    "PI",
    "PI",
    "ALPHA",
    "THETA",
    "ETA",
    "TAU",
    "ALPHA",
    "GOD AND COLLEGE",
    "GOD AND COLLEGE",
    "PHI",
    "KAPPA",
    "THETA",
    "HO!!!"
  ]

  lennySnakeParts = [
    "╚═( ͡° ͜ʖ ͡°)═╝",
    "╚═(███)═╝",
    "╚═(███)═╝",
    ".╚═(███)═╝",
    "..╚═(███)═╝",
    "…╚═(███)═╝",
    "…╚═(███)═╝",
    "..╚═(███)═╝",
    ".╚═(███)═╝",
    "╚═(███)═╝",
    ".╚═(███)═╝",
    "..╚═(███)═╝",
    "…╚═(███)═╝",
    "…╚═(███)═╝",
    "…..╚(███)╝",
    "……╚(██)╝",
    "………(█)",
    "……….*"
  ]

  lennySnakeTick = 300 # milliseconds
  chantTick = 300

  robot.hear /\bPHI\b/, (res) ->
    res.send "PHI"
    waitingForIota = true
    setTimeout(() ->
      waitingForIota = false
    , 4000)

  robot.hear /\bIOTA\b/, (res) ->
    if waitingForIota
      res.send "IOTA"
      sendFrom = (i) ->
        if i < chantParts.length
          res.send chantParts[i]
          setTimeout sendFrom, lennySnakeTick, i + 1
      setTimeout sendFrom, 1200, 2

  robot.respond /order66/i, (res) ->
    res.send("Yes, my lord.")

  robot.respond /yea aight/i, (res) ->
    res.send("Blueface babyyy")

  robot.hear /lennysnake/i, (res) ->
    sendFrom = (i) ->
      if i < lennySnakeParts.length
        res.send lennySnakeParts[i]
        setTimeout sendFrom, lennySnakeTick, i + 1
    sendFrom 0

  dootDoot = """```
thank mr skeltal

░░░░░░░░░░░▐▄▐
░░░░░░▄▄▄░░▄██▄
░░░░░▐▀█▀▌░░░░▀█▄
░░░░░▐█▄█▌░░░░░░▀█▄
░░░░░░▀▄▀░░░▄▄▄▄▄▀▀
░░░░▄▄▄██▀▀▀▀
░░░█▀▄▄▄█░▀▀
░░░▌░▄▄▄▐▌▀▀▀
▄░▐░░░▄▄░█░▀▀
▀█▌░░░▄░▀█▀░▀
░░░░░░░▄▄▐▌▄▄
░░░░░░░▀███▀█░▄
░░░░░░▐▌▀▄▀▄▀▐▄
░░░░░░▐▀░░░░░░▐▌
░░░░░░█░░░░░░░░█
░░░░░▐▌░░░░░░░░░█
░░░░░█░░░░░░░░░░▐▌
```"""

  robot.hear /(doot|[0-9]spooky)/i, (res) ->
    res.send dootDoot
  robot.hear /print/i, (res) ->
    res.send "Go to Ballroom. Connect to Ballroom WiFi. Password is 'helloworld' without quotes. Scan for printers (should be Brother smth smth). If you don't see it, turn the printer off and on again."
  robot.respond /rolldie/i, (res) ->
    rolls = (randomInt(1, 7) for i in [1..5])
    result = Math.pow(Math.min(rolls[0], rolls[1]), Math.min(rolls[2], rolls[3], rolls[4]))
    res.send ":game_die: You rolled " + result + ". Rolls: "+ rolls.join(", ") + " :game_die:"
