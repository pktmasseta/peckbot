# Description:
#   Example scripts for you to examine and try out.
#
# Notes:
#   They are commented out by default, because most of them are pretty silly and
#   wouldn't be useful and amusing enough for day to day huboting.
#   Uncomment the ones you want to try and experiment with.
#
#   These are from the scripting documentation: https://github.com/github/hubot/blob/master/docs/scripting.md

ELO_SITE = 'https://peckelo.brendanashworth.workers.dev'

# Elo constants
K_FACTOR = 32
SCALE_FACTOR = 400
STARTING_ELO = 1500

module.exports = (robot) ->

  robot.hear /elo ([A-Z]{3}) beat ([A-Z]{3})/i, (res) ->
    # get ratings
    winner = res.match[1]
    loser = res.match[2]

    res.send "Updating leaderboard after #{winner} beat #{loser}..."

    winnerElo = STARTING_ELO
    loserElo = STARTING_ELO

    # don't let slack cache
    pf = "?id=#{Math.round(Math.random() * 1e6)}"

    # overwrite if either has played before
    robot.http("#{ELO_SITE}/get/#{winner}#{pf}").get() (err, response, body) ->
      if not err
        winnerElo = Number(body)
   
      robot.http("#{ELO_SITE}/get/#{loser}#{pf}").get() (err, response, body) ->
        if not err
          loserElo = Number(body)

        # do the calculations
        # https://mattmazzola.medium.com/implementing-the-elo-rating-system-a085f178e065
        Ea = 1/(1 + Math.pow 10, ((loserElo - winnerElo)/SCALE_FACTOR))

        # 1, 0 refer to loss
        newWinnerElo = Math.floor(winnerElo + K_FACTOR*(1 - Ea))
        newLoserElo = Math.floor(loserElo + K_FACTOR*(0 - Ea))

        robot.http("#{ELO_SITE}/put/#{winner}/#{newWinnerElo}#{pf}").get() (err, response, body) ->
          if err
            res.send "Could not connect to ELO site 😢"
        robot.http("#{ELO_SITE}/put/#{loser}/#{newLoserElo}#{pf}").get() (err, response, body) ->
          if err
            res.send "Could not connect to ELO site 😢"

        res.send "Updated ELOs to #{winner}: #{newWinnerElo} ↑, #{loser}: #{newLoserElo} ↓."

  robot.hear /elo$/i, (res) ->
    # don't let slack cache
    pf = "?id=#{Math.round(Math.random() * 1e6)}"

    # get ELO from site
    robot.http("#{ELO_SITE}/all#{pf}").get() (err, response, body) ->
      if err
        res.send "Could not connect to ELO site 😢"

        graduation = new Date('05/31/2022')
        days = ((new Date()) - graduation) / (1000 * 3600 * 24);
        if days > 0
          res.send "It has been #{Math.round(days)} days since BMA graduated... get someone else to fix it."

        return

      # get top 15
      elos = JSON.parse body
      eloPairs = Object.entries(elos).sort (a, b) => b[1] - a[1]
      eloPairs = eloPairs.slice 0, 15

      res.send "👑 POOL LEADERBOARD 👑 (TOP 15 IN PKT):"
      for pair in eloPairs
        res.send "#{pair[0]}:\t#{pair[1]}"
      res.send "~ give this two minutes to update ~"
