# Description:
# Hubot interface for the PKT Parking Camera System
#
# Commands:
#   parking - gets most recent image of parking lot(always a minute old or less)
#   parking register <license plate> - adds license plate to parking database so it's not flagged for illegal parking
#   parking remove <license plate> - removes license plate from parking database
# Configuration:
#   HUBOT_PARKING_ALARM - boolean that when true allows logging of all unauthorized license plates

google = require('googleapis')
googlAuth = require('google-auth-library')
moment = require('moment')

module.exports = (robot) ->
