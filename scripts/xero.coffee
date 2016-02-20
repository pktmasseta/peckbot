# Description:
#   Xero reimbursements
#
# Commands:
#   hubot xero budgets load - reloads all budgets from xero
#   hubot xero budgets - Lists all budgets
#   hubot xero add <slack name> [email, optional]- Allow a user to submit reimbursements
#   hubot xero delete <slack name> - Removes user access to submit reimbursements
#
# Config:
#   HUBOT_XERO_CONTACT_ID
#   HUBOT_XERO_ACCOUNT_ID
#   HUBOT_XERO_CONSUMER_KEY
#   HUBOT_XERO_CONSUMER_SECRET
#
# Author:
#   Detry322

fs = require 'fs'
request = require 'request'
Xero = require 'xero'

xero = try
  private_key = fs.readFileSync('xero/private_key.pem', 'ascii')
  new Xero(process.env.HUBOT_XERO_CONSUMER_KEY, process.env.HUBOT_ENV_CONSUMER_SECRET, private_key);
catch e
  null

submitReceipt = (robot, res, receipt_id) ->
  res.send "Step 3: Submitting receipt for reimbursement..."
  res.send "Success! You should receive a check for $#{res.reimbursement_amount} in a couple of days. You can track progress on https://xero.com"


uploadImage = (robot, res, receipt_id) ->
  res.send "Step 2: Uploading receipt to xero..."
  res.send 'P.S. The "public link" message you receive from slackbot is to download the image. Feel free to revoke the public link after this is complete.'
  public_link = res.message.rawMessage.file.permalink_public
  pub_secret = public_link.split("-").reverse()[0]
  private_link = res.message.rawMessage.file.url_private + "?pub_secret=" + pub_secret
  request.get public_link, (err, response, body) ->
    if err or response.statusCode != 200
      res.send "Error creating public link"
      return
    request.get private_link, (err, response, body) ->
      if err or response.statusCode != 200
        res.send "Error downloading file from slack"
        return
      image = new Buffer(body)
      submitReceipt(robot, res, receipt_id)

createReceipt = (robot, res, description, amount, budget) ->
  res.send "Step 1: Creating receipt in xero..."
  uploadImage(robot, res, "blah")

handleImageMessage = (robot, res) ->
  if not res.message.user['xero-identifier']?
    res.send "You haven't been added to xero just yet. Ask pkt-it"
    return
  comment_array = res.message?.rawMessage?.file?.initial_comment?.comment?.split('\n')
  if comment_array?.length != 3
    return badFormat(res)
  description = comment_array[0]
  amount = Number(comment_array[1].replace(/[^0-9\.]+/g,""))
  budget = comment_array[2]
  if isNaN(amount) or amount == 0
    return badFormat(res)
  res.reimbursement_amount = amount
  createReceipt(robot, res, description, amount, budget)

matchUser = (robot, res, user, email) ->
  xero.call 'GET', '/Users', null, (err, json) ->
    if err
      res.send "There was an error accessing the XERO API."
      return
    for xero_user in json.Response.Users.User
      if email == xero_user.EmailAddress.toLowerCase()
        user['xero-identifier'] = xero_user.UserID
        res.send "Successfully connected #{user['name']} to xero."
        return
    res.send "Unable to find a user with email #{email} in the xero database"

printBudgets = (robot, res) ->
  budgets = robot.brain.get('xero-budgets') or {}
  result = "We have the following budgets available. Please use the shorthand when referring to a budget.\n\n"
  for own shorthand, budget of budgets
    result += "*#{budget['shorthand']}*: #{budget['description']}\n"
  if Object.keys(budgets).length == 0
    result += "(No budgets)"
  res.send result

module.exports = (robot) ->

  badFormat = (res) ->
    res.send "If you are uploading a receipt, *please reupload* and comment on your image in the following format:\n\n<Short description (Costco)>\n<Dollar amount ($86.00)>\n<Budget shorthand (e.g. >"
    printBudgets(robot, res)

  if not xero?
    robot.logger.warning 'Could not load private key, not loading xero'
    return

  robot.respond /xero help$/i, (res) ->
    res.send "Please upload receipt images in a direct message to me."
    debugger;

  robot.respond /xero budgets load$/, (res) ->

  robot.respond /xero budgets$/, (res) ->
    printBudgets(robot, res)

  robot.respond /xero add ([a-z0-9_\-]+)($|.+$)/, (res) ->
    user = robot.brain.userForName(res.match[1])
    email = res.match[2].trim() or user['email_address']
    if not user?
      res.send "Couldn't find that user"
      return
    matchUser(robot, res, user, email)

  robot.respond /xero (delete|remove) ([a-z0-9_\-]+)$/, (res) ->
    user = robot.brain.userForName(res.match[1])
    if not user?
      res.send "Couldn't find that user"
      return
    delete user['xero-identifier']
    res.send "Deleted identifier"

  robot.respond /(.*)/, (res) ->
    if res.message?.rawMessage?.subtype != "file_share"
      return
    handleImageMessage robot, res

