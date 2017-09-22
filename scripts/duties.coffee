# Description:
#   Hubot duties reminder system
#
# Commands:
#   hubot duties - gets your upcoming duties
#   hubot duties XXX - gets XXX's upcoming duties
#   hubot duties upcoming - gets the upcoming houseworks
#   hubot duties link - return master spreadsheet link
#
# Configuration:
#   HUBOT_HOUSEWORKS_SPREADSHEET - spreadsheet ID of master H-man
#   HUBOT_HOUSEWORKS_REMINDER - reminder schedule 
#
# Author:
#   Detry322

fs = require('fs')
moment = require('moment')
GoogleSpreadsheet = require 'google-spreadsheet';
cron = require 'node-cron';

DUTIES_SPREADSHEET_NAME = 'Duties'
INSTRUCTIONS_SPREADSHEET_NAME = 'Instructions'
TICKETS_SPREADSHEET_NAME = 'Tickets'

DUTY_MESSAGES = {
  housework: "If needed, ask the housework manager for an automatic 1-day extension, or about other questions."
  quickwork: "Extensions cannot be granted for quickworks. Find someone to switch with if you need extra time."
  crews: "Extensions cannot be granted for crews. D-crews must be finished by midnight the night of."
}

loadAuth = (callback) ->
  if credentials_json?
    return callback(null, credentials_json)
  fs.readFile 'service_account.json', (err, content) ->
    if err?
      return callback("could not load service_account.json")
    credentials_json = JSON.parse(content)
    callback(null, credentials_json)

module.exports = (robot) ->
  config = require('hubot-conf')('duties', robot)

  spreadsheet_object = null
  spreadsheet_key = null

  getDoc = (callback) ->
    sp_key = config('spreadsheet')
    if not sp_key?
      return callback("No spreadsheet is currently set")
    if spreadsheet_key == sp_key
      return callback(null, spreadsheet_object)
    spreadsheet_object = new GoogleSpreadsheet(sp_key)
    loadAuth (err, credentials) ->
      if err?
        return callback(err)
      spreadsheet_object.useServiceAccountAuth credentials, (err) ->
        if err?
          return callback(err)
        spreadsheet_key = sp_key
        callback(null, spreadsheet_object)

  getSpreadsheet = (name, callback) ->
    getDoc (err, doc) ->
      if err?
        return callback(err)
      doc.getInfo (err, info) ->
        if err?
          return callback(err)
        for sheet in info.worksheets
          if sheet.title.toLowerCase() == name.toLowerCase()
            return callback(null, sheet)
        callback("Could not find sheet with title #{name}")

  getSpreadsheetRows = (name, callback) ->
    getSpreadsheet name, (err, sheet) ->
      if err?
        return callback(err)
      sheet.getRows (err, rows) ->
        if err?
          return callback(err)
        return callback(null, rows)

  dueDate = (row) ->
    return new Date(+(new Date(row.date)) + 24*60*60*1000*(+(row.ext) + 1) - 1)

  isActive = (row, days) ->
    days = if days? then days else 10000
    return row.completed.toLowerCase() == 'no' and row.brother != '' and (dueDate(row) - new Date()) < days*24*60*60*1000

  dutyToString = (row) ->
    s = "*#{row.duty}* (#{row.category}): Due _#{moment(dueDate(row)).calendar()}_"
    if (+row.ext) > 0
      s += " (date includes a #{row.ext}-day extension)"
    return s

  instructionToString = (row) ->
    if not row?
      return "Couldn't find instructions"
    return "-- Instructions for the *#{row.duty} #{row.category}* duty.\n#{row.instructions}"

  instructionForDuty = (duty, instruction_rows) ->
    for row in instruction_rows
      if duty.category == row.category and duty.duty == row.duty
        return row
    return null

  delayLoop = (elements, delay, fn, finish) ->
    setTimeout(() ->
      if elements.length is 0 and finish
        return finish()
      fn(elements[0])
      return delayLoop(elements[1..], delay, fn, finish)
    , delay)

  remindPeople = (days_in_advance) ->
    getSpreadsheetRows INSTRUCTIONS_SPREADSHEET_NAME, (ierr, instruction_rows) ->
      if ierr?
        robot.messageRoom "#botspam", "Error sending duties pings: #{err}"
        return
      getSpreadsheetRows DUTIES_SPREADSHEET_NAME, (err, duty_rows) ->
        if err?
          robot.messageRoom "#botspam", "Error sending duties pings: #{err}"
          return
        delayLoop duty_rows, 500, (row) ->
          if isActive(row, days_in_advance)
            instructions = instructionForDuty(row, instruction_rows)
            message = "*#{row.category}* reminder: #{dutyToString(row)}\n\n#{DUTY_MESSAGES[row.category]}\n\nInstruction: #{instructionToString(instructions)}"
            robot.messageRoom robot.brain.userForInitials(row.brother).name, message

  robot.respond /houseworks?(.+)$/i, (res) ->
    res.send "Please use `peckbot duties <whatever>` instead."

  robot.respond /duties link$/i, (res) ->
    res.send "https://docs.google.com/spreadsheets/d/#{config('spreadsheet')}/edit"

  robot.respond /duties upcoming$/i, (res) ->
    getSpreadsheetRows DUTIES_SPREADSHEET_NAME, (err, rows) ->
      if err?
        return res.send err
      result = "*== Upcoming duties ==*\n\n"
      for row in rows
        if isActive(row, 5)
          result += row.brother + ' - ' + dutyToString(row) + '\n'
      res.send result

  robot.respond /duties instructions all$/i, (res) ->
    getSpreadsheetRows INSTRUCTIONS_SPREADSHEET_NAME, (err, rows) ->
      if err
        return res.send err
      result = ""
      for row in rows
        result += "#{instructionToString(row)}\n\n"
      res.send result

  robot.respond /duties instructions$/i, (res) ->
    person = res.message.user.initials
    getSpreadsheetRows DUTIES_SPREADSHEET_NAME, (err, duties) ->
      if err?
        return res.send err
      duty = null
      for row in duties
        if row.brother == person and isActive(row)
          duty = row
          break
      if not duty?
        return res.send "You don't have any upcoming duties!"
      getSpreadsheetRows INSTRUCTIONS_SPREADSHEET_NAME, (err, instruction_list) ->
        if err?
          return res.send err
        res.send instructionToString(instructionForDuty(duty, instruction_list))

  robot.respond /duties?($| [A-Z]{3}$)/i, (res) ->
    getSpreadsheetRows DUTIES_SPREADSHEET_NAME, (err, rows) ->
      person = if res.match[1] == '' then res.message.user.initials else res.match[1].trim().toUpperCase()
      if err?
        return res.send err
      result = "*== Duties for #{person} ==*\n\n"
      for row in rows
        if row.brother == person and isActive(row)
          result += dutyToString(row) + '\n'
      res.send result

  robot.respond /ticket (.+)$/i, (res) ->
    getSpreadsheet TICKETS_SPREADSHEET_NAME, (err, sheet) ->
      if err
        return res.send err
      newRow = {
        timestamp: moment().format('M/D/YYYY H:mm:ss'),
        priority: "Unassigned",
        broken: res.match[1],
        initials: res.message.user.initials
      }
      sheet.addRow newRow, (err) ->
        if err
          return res.send err
        res.send "I've marked down that: *#{res.match[1]}*"

  robot.respond /duties remind($| [0-9]+$)/i, (res) ->
    res.send "Sending reminders..."
    remindPeople(+res.match[1] || 8)

  cron.schedule config('reminder'), () ->
    remindPeople(8) # 8 days in advance
