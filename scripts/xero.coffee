# Description:
#   Xero reimbursements
#
# Commands:
#   hubot xero budget add <shorthand> <identifier> <budget description> - Add a budget to the list of options
#   hubot xero budget delete <shorthand> - Removes budget.
#   hubot xero budgets - Lists all budgets
#   hubot xero member add <identifier> <slack name> - Allow a user to submit reimbursements
#   hubot xero member delete <slack name> - Removes user access to submit reimbursements
#   hubot xero help - Displays a help message
#
# Config:
#   HUBOT_XERO_CONTACT_ID
#   HUBOT_XERO_ACCOUNT_ID
#
# Author:
#   Detry322

fs = require 'fs'
request = require 'request'
xero = require 'xero'

private_key = try
  fs.readFileSync('xero/private_key.pem', 'ascii')
catch e
  null

handleImageMessage = (robot, res) ->
  if res.message?.rawMessage?.subtype != "file_share"
    return
  if not res.user['xero-identifier']?
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
  debugger;

printBudgets = (robot, res) ->
  budgets = robot.brain.get('xero-budgets') or {}
  result = "We have the following budgets available. Please use the shorthand when referring to a budget.\n\n"
  for own shorthand, budget of budgets
    result += "*#{budget['shorthand']}*: #{budget['description']}\n"
  if Object.keys(budgets).length == 0
    result += "(No budgets)"
  res.send result

module.exports = (robot) ->

  config = require('hubot-conf')('xero', robot)

  badFormat = (res) ->
    res.send "If you are uploading a receipt, *please reupload* and comment on your image in the following format:\n\n<Short description (Costco)>\n<Dollar amount ($86.00)>\n<Budget shorthand (e.g. >"
    printBudgets(robot, res)

  if not private_key?
    robot.logger.warning 'Could not load private key, not loading xero'
    return

  robot.respond /xero help$/i, (res) ->
    res.send "Please upload receipt images in a direct message to me."
    debugger;

  robot.respond /xero budget add ([a-z]+) ([a-f0-9\-]+) (.+)$/, (res) ->
    budget = {
      shorthand: res.match[1],
      identifier: res.match[2],
      description: res.match[3]
    }
    budgets = robot.brain.get('xero-budgets') or {}
    budgets[budget['shorthand']] = budget
    robot.brain.set('xero-budgets', budgets)
    res.send "Added *#{budget['shorthand']}*: #{budget['description']}"

  robot.respond /xero budget (delete|remove) ([a-z]+)$/, (res) ->
    budgets = robot.brain.get('xero-budgets') or {}
    delete budgets[res.match[2]]
    robot.brain.set('xero-budgets', budgets)
    res.send "Deleted budget."

  robot.respond /xero budgets$/, (res) ->
    printBudgets(robot, res)

  robot.respond /xero member add ([a-z0-9_\-]+) ([a-f0-9\-]+)$/, (res) ->
    user = robot.brain.userForName(res.match[1])
    if not user?
      res.send "Couldn't find that user"
      return
    identifer = res.match[2]
    user['xero-identifier'] = identifer
    res.send "Added identifier to #{user['name']}."

  robot.respond /xero member (delete|remove) ([a-z0-9_\-]+)$/, (res) ->
    user = robot.brain.userForName(res.match[1])
    if not user?
      res.send "Couldn't find that user"
      return
    delete user['xero-identifier']
    res.send "Deleted identifier"


  robot.respond /(.*)/, (res) ->
    handleImageMessage robot, res







# getFileDownloadLink = (file) ->
#   pubsecret = file.permalink_public.split("-").reverse()[0]
#   file.url_private + "?pub_secret=" + pubsecret
