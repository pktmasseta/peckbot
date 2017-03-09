# Description:
#   Hubot houseworks reminder system
#
# Commands:
#   hubot housework(s) - gets your upcoming houseworks
#   hubot housework(s) XXX - gets XXX's upcoming houseworks
#   hubot housework(s) statistics - gets statistics on how long houseworks take.
#   hubot housework(s) upcoming - gets the upcoming houseworks
#   hubot quickwork(s) upcoming - gets the upcoming quickworks
#   hubot houseworks link - return master spreadsheet link
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

    isActive = (row, days) ->
      return row.completed.toLowerCase() == 'no' and row.brother != '' and (dueDate(row) - new Date()) < days*24*60*60*1000

    isHousework = (row) ->
      return row.type.toLowerCase() == 'housework'

    isQuickwork = (row) ->
      return row.type.toLowerCase() == 'quickwork'

    houseworkToString = (row) ->
      s = "*#{row.work}* (#{row.type}): Due _#{moment(dueDate(row)).calendar()}_"
      if (+row.ext) > 0
        s += " (date includes a #{row.ext}-day extension)"
      return s

    robot.respnd /houseworks?$/i, (res) ->
      res.send "https://docs.google.com/spreadsheets/d/#{config('spreadsheet')}/edit"

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
          if isActive(row, 8) and isHousework(row)
            result += row.brother + ' - ' + houseworkToString(row) + '\n'
        res.send result

    robot.respond /quickworks? upcoming$/i, (res) ->
      getSpreadsheetRows 'Houseworks', (err, rows) ->
        if err?
          return res.send err
        result = "*== Upcoming quickworks ==*\n\n"
        for row in rows
          if isActive(row, 5) and isQuickwork(row)
            result += row.brother + ' - ' + houseworkToString(row) + '\n'
        res.send result

    robot.respond /houseworks?($| [A-Z]{3}$)/i, (res) ->
      getSpreadsheetRows 'Houseworks', (err, rows) ->
        person = if res.match[1] == '' then res.message.user.initials else res.match[1].trim()
        if err?
          return res.send err
        result = "*== Houseworks for #{person} ==*\n\n"
        for row in rows
          if row.brother == person and new Date(+(new Date(row.date)) + 24*60*60*1000) > new Date()
            result += houseworkToString(row) + '\n'
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

    cron.schedule config('reminder.houseworks'), () ->
      getSpreadsheetRows 'Houseworks', (err, rows) ->
        if err?
          return
        for row in rows
          if isActive(row, 8) and isHousework(row)
            message = "Housework reminder: #{houseworkToString(row)}\n\nIf needed, ask the housework manager for an automatic 1-day extension, or about other questions."
            robot.messageRoom robot.brain.userForInitials(row.brother).name, 


    cron.schedule config('reminder.quickworks'), () ->
      getSpreadsheetRows 'Houseworks', (err, rows) ->
        if err?
          return
        for row in rows
          if isActive(row, 5) and isQuickwork(row)
            message = "Quickwork reminder: " + houseworkToString(row) + "\n\nYou cannot be given an extension for quickworks. If you are unable, find another brother to substitute."
            robot.messageRoom robot.brain.userForInitials(row.brother).name, message
