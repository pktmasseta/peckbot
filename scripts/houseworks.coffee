# Description:
#   Hubot houseworks reminder system
#
# Commands:
#   hubot housework(s) statistics - gets statistics on how long houseworks take.
#   hubot housework(s) upcoming - gets the upcoming houseworks
#   hubot houseworks 
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

loadAuth = (callback) ->
  if credentials_json?
    return callback(null, credentials_json)
  fs.readFile 'service_account.json', (err, content) ->
    if err?
      return callback("could not load service_account.json")
    credentials_json = JSON.parse(content)
    callback(null, credentials_json)

module.exports = (robot) ->
    config = require('hubot-conf')('houseworks', robot)

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

    isActive = (row) ->
      return row.completed == 'no' and row.brother != '' and (dueDate(row) - new Date()) < 8*24*60*60*1000

    houseworkToString = (row) ->
      s = "*#{row.work}*: Due _#{moment(dueDate(row)).calendar()}_"
      if (+row.ext) > 0
        s += " (date includes a #{row.ext}-day extension)"
      return s

    robot.respond /houseworks? statistics$/i, (res) ->
      getSpreadsheetRows 'Statistics', (err, rows) ->
        if err?
          return res.send err
        result = "*==Housework Statistics==*\n\n"
        for row in rows
          result += "*#{row.housework}*: #{row.averagetime} minutes avg.\n"
        res.send result

    robot.respond /houseworks? upcoming$/i, (res) ->
      getSpreadsheetRows 'Houseworks', (err, rows) ->
        if err?
          return res.send err
        result = "*== Upcoming houseworks ==*\n\n"
        for row in rows
          if isActive(row)
            result += row.brother + ' - ' + houseworkToString(row) + '\n'
        res.send result

    robot.respond /ticket (.+)$/i, (res) ->
      getSpreadsheet 'Tickets', (err, sheet) ->
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

    cron.schedule config('reminder'), () ->
      getSpreadsheetRows 'Houseworks', (err, rows) ->
        if err?
          return
        for row in rows
          if isActive(row)
            message = "Housework reminder: " + houseworkToString(row)
            robot.messageRoom robot.brain.userForInitials(row.brother).name, message
