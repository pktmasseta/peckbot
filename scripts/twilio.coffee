# Description:
#   Text reciever
#
# Configuration:
#   HUBOT_TWILIO_CHANNEL - channel to send messages in
#   HUBOT_TWILIO_ACCOUNT - Account SID for verification
#
# Author:
#   Detry322

module.exports = (robot) ->

  robot.router.post '/twilio/receive', (req, res) ->
    res.header('Content-Type','text/xml').send "<Response></Response>"
    if req.body.AccountSid == process.env.HUBOT_TWILIO_ACCOUNT
      number = req.body.From
      message = req.body.Body
      robot.messageRoom process.env.HUBOT_TWILIO_CHANNEL, "[Twilio] Text from #{number}: #{message}"
