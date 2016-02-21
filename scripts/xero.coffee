# Description:
#   Xero reimbursements
#
# Commands:
#   hubot xero help - Displays a short help message, can file reimbursements!
#
# Hidden:
#   hubot xero member add <slack name> [email, optional]- Allow a user to submit reimbursements
#   hubot xero member delete <slack name> - Removes user access to submit reimbursements
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

# submitReceipt = (robot, res, receipt_id) ->
#   res.send "Step 3: Submitting receipt for reimbursement..."
#   res.send "Success! You should receive a check for $#{res.reimbursement_amount} in a couple of days. You can track progress on https://xero.com"


# uploadImage = (robot, res, receipt_id) ->
#   res.send "Step 2: Uploading receipt to xero..."
#   res.send 'P.S. The "public link" message you receive from slackbot is to download the image. Feel free to revoke the public link after this is complete.'
#   public_link = res.message.rawMessage.file.permalink_public
#   pub_secret = public_link.split("-").reverse()[0]
#   private_link = res.message.rawMessage.file.url_private + "?pub_secret=" + pub_secret
#   request.get public_link, (err, response, body) ->
#     if err or response.statusCode != 200
#       res.send "Error creating public link"
#       return
#     request.get private_link, (err, response, body) ->
#       if err or response.statusCode != 200
#         res.send "Error downloading file from slack"
#         return
#       image = new Buffer(body)
#       submitReceipt(robot, res, receipt_id)

# createReceipt = (robot, res, description, amount, budget) ->
#   res.send "Step 1: Creating receipt in xero..."
#   uploadImage(robot, res, "blah")

# handleImageMessage = (robot, res) ->
#   if not res.message.user['xero-identifier']?
#     res.send "You haven't been added to xero just yet. Ask pkt-it"
#     return
#   comment_array = res.message?.rawMessage?.file?.initial_comment?.comment?.split('\n')
#   if comment_array?.length != 3
#     return badFormat(res)
#   description = comment_array[0]
#   amount = Number(comment_array[1].replace(/[^0-9\.]+/g,""))
#   budget = comment_array[2]
#   if isNaN(amount) or amount == 0
#     return badFormat(res)
#   res.reimbursement_amount = amount
#   createReceipt(robot, res, description, amount, budget)

# printBudgets = (robot, res) ->
#   budgets = robot.brain.get('xero-budgets') or {}
#   result = "We have the following budgets available. Please use the shorthand when referring to a budget.\n\n"
#   for own shorthand, budget of budgets
#     result += "*#{budget['shorthand']}*: #{budget['description']}\n"
#   if Object.keys(budgets).length == 0
#     result += "(No budgets)"
#   res.send result
#

  # robot.respond /xero help$/i, (res) ->
  #   res.send "Please upload receipt images in a direct message to me."
  #   debugger;

  # robot.respond /xero budgets load$/, (res) ->

  # robot.respond /xero budgets$/, (res) ->
  #   printBudgets(robot, res)


  # robot.respond /(.*)/, (res) ->
  #   if res.message?.rawMessage?.subtype != "file_share"
  #     return
  #   handleImageMessage robot, res

callXero = (endpoint, callback) ->
  xero.call 'GET', endpoint, null, (err, json) ->
    if err
      res.send "There was an error accessing the Xero API. Please try again."
      return
    callback(json.Response)

handleCancel = (robot, res, user) ->
  if user.xero_state != '0_not_started'
    clearTimeout(user.xero_timeout)
    user.xero_state = '0_not_started'

timeoutControl = (res, user) ->
  # This handles the 5 minute timeout for reimbursements. If a user stops responding, after 5 minutes their reimbursements stops.
  old_state = user.xero_state || '0_not_started'
  if old_state != '0_not_started'
    clearTimeout(user.xero_timeout)
  user.xero_timeout = setTimeout(() ->
    user.xero_state = '0_not_started'
    user.xero_timeout = null
  , 300000)

matchUser = (robot, res, user, email) ->
  callXero '/Users', (json) ->
    for xero_user in json.Users.User
      if email == xero_user.EmailAddress.toLowerCase()
        user.xero_userid = xero_user.UserID
        res.send "Successfully connected #{user['name']} to xero."
        return
    res.send "Unable to find a user with email #{email} in the xero database"

handleStartReimbursement = (robot, res, user, command, success) ->
  if command == 'start'
    res.send 'Ok! How much is this reimbursement for? Respond with something similar to `xero $12.34`.'
    success()

handleSelectBudget = (robot, res, user, command, success) ->
  amount = Number(command.replace(/[^0-9\.]+/g,""))
  if amount == 0 or isNaN(amount)
    res.send 'I couldn\'t recognize that dollar amount. Please retry with something similar to `xero $12.34`'
    return
  callXero '/TrackingCategories', (json) ->
    budget = null
    for category in json.TrackingCategories.TrackingCategory
      if category.Name.toLowerCase().match("budget")?
        budget = category
        break
    tracking = {
      id: budget.TrackingCategoryID
      budgets: {}
    }
    for option in budget.Options.Option
      shortname = option.Name.split(' ')[0].toLowerCase()
      tracking.budgets[shortname] = {
        name: option.Name
        id: option.TrackingOptionID
      }
    robot.brain.set('xero-budget-tracking', tracking)
    result = "Please select a budget for this receipt. Please respond with `xero <shortname>` where `<shortname>` is the bolded name for that budget.\n\n"
    for own shortname, budget of tracking.budgets
      result += "*#{shortname}*: #{budget.name}\n"
    res.send result
    success()


handleSelectType = (robot, res, user, command, success) ->
  tracking = robot.brain.get 'xero-budget-tracking'
  if not command of tracking.budgets
    res.send "I didn't recognize that budget. Please try again."
    return
  selected_budget = tracking.budgets[command]
  user.xero_tracking_category = tracking.id
  user.xero_budget = selected_budget.id
  callXero '/Accounts', (json) ->
    types = {}
    for type in json.Accounts.Account
      if type.ShowInExpenseClaims == false
        continue
      types[type.Code] = {
        name: type.Name,
        id: type.AccountID
      }
    robot.brain.set('xero-types', types)
    result = "Selected #{selected_budget.name}. Now, select the type of expense. Please respond with `xero <id>` where `<id>` is the bolded number for that type.\n\n"
    for own code, type of types
      result += "*#{code}*: #{type.name}\n"
    res.send result
    success()

handleInputDescription = (robot, res, user, command, success) ->
  types = robot.brain.get 'xero-types'
  if not command of types
    res.send "I didn't recognize that type. Please try again."
    return
  selected_type = types[command]
  user.xero_type = selected_type.id
  res.send "Selected #{selected_type.name}. Now, write a very brief description of the expense. Please respond with `xero <description>`."
  success()

submitReimbursement = (robot, res, user, success) ->
  success()

stateTransition = (robot, res, user, command) ->
  if user.xero_state == '0_not_started'
    res.send "You haven't started the reimbursement process. Please direct message me an image of your receipt."
    return

  else if user.xero_state == '1_image_received'
    handleStartReimbursement robot, res, user, command, () ->
      user.xero_state = '2_reimbursement_started'

  else if user.xero_state == '2_reimbursement_started'
    handleSelectBudget robot, res, user, command, () ->
      user.xero_state = '3_budget_selected'

  else if user.xero_state == '3_budget_selected'
    handleSelectType robot, res, user, command, () ->
      user.xero_state = '4_type_selected'

  else if user.xero_state == '4_type_selected'
    handleInputDescription robot, res, user, command, () ->
      submitReimbursement robot, res, user, () ->
        res.send "Thanks! Your reimbursement for $#{user.xero_amount} has been submitted. To modify or view progress, please visit https://xero.com."
        handleCancel(robot, res, user)

module.exports = (robot) ->

  # Available:
  # user.xero_userid
  # user.xero_state
  # user.xero_timeout
  # user.xero_receipt_link
  # user.xero_amount
  # user.xero_tracking_category
  # user.xero_budget
  # user.xero_type
  # user.xero_description

  if not xero?
    robot.logger.warning 'Could not load private key, not loading xero'
    return

  robot.respond /(.*)/, (res) ->
    if res.message?.rawMessage?.subtype != "file_share"
      return
    user = res.message.user
    if user.name != res.message.room
      return
    timeoutControl(res, user)
    res.message.user.xero_receipt_link = res.message.rawMessage.file.permalink_public
    res.message.user.xero_state = '1_image_received'
    res.send "Thanks for the image. If this is a receipt, please reply with `xero start`.  If at any point you wish to cancel your progress, send `xero cancel`."

  robot.respond /xero (.+)$/, (res) ->
    command = res.match[1]
    user = res.message.user
    user.xero_state = user.xero_state || '0_not_started'
    if command == 'help'
      res.send "I can file PKT reimbursements for you. To start the process, send an image to me in a direct message."
      return
    if command.split(' ')[0] == 'member'
      return
    if not user.xero_userid?
      res.send "You haven't been set up with xero yet. Try running `xero member add <your slack name>`. If that doesn't work, ask pkt-it"
      return
    if command == 'cancel'
      handleCancel(robot, res, user)
      res.send "Reimbursement cancelled."
      return
    if user.name != res.message.room
      return
    timeoutControl(res, user)
    stateTransition(robot, res, res.message.user, command)

  robot.respond /xero member add ([a-z0-9_\-]+)($|.+$)/, (res) ->
    user = robot.brain.userForName(res.match[1])
    email = res.match[2].trim() or user['email_address']
    if not user?
      res.send "Couldn't find that user"
      return
    matchUser(robot, res, user, email)

  robot.respond /xero (delete|remove) ([a-z0-9_\-]+)$/, (res) ->
    user = robot.brain.userForName(res.match[2])
    if not user?
      res.send "Couldn't find that user"
      return
    delete user.xero_userid
    res.send "Deleted identifier"
