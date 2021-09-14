// Description:
//   Hubot duties reminder system

// Commands:
//   hubot duties - gets your upcoming duties
//   hubot duties XXX - gets XXX's upcoming duties
//   hubot duties upcoming - gets the upcoming houseworks
//   hubot duties link - return master spreadsheet link

// Configuration:
//   HUBOT_HOUSEWORKS_SPREADSHEET - spreadsheet ID of master H-man
//   HUBOT_HOUSEWORKS_REMINDER - reminder schedule 

// Author:
//   Detry322

const moment = require('moment')
const { GoogleSpreadsheet } = require('google-spreadsheet')
const credentials = JSON.parse(process.env['GOOGLE_SERVICE_ACCOUNT'])

const cron = require('node-cron')

const DUTIES_SPREADSHEET_NAME = 'Duties'

const INSTRUCTIONS_SPREADSHEET_NAME = 'Instructions'

const TICKETS_SPREADSHEET_NAME = 'Tickets'

const DUTY_MESSAGES = {
  housework: 'If needed, ask the housework manager for an automatic 1-day extension, or about other questions.',
  quickwork: 'Extensions cannot be granted for quickworks. Find someone to switch with if you need extra time.',
  crew: 'Extensions cannot be granted for crews. D-crews must be finished by midnight the night of.',
  social: 'Social duties must be done the day they are assigned. If you are unable, find someone to switch with.'
}

// loadAuth = function(callback) {
//   var credentials_json
//   if (typeof credentials_json !== "undefined" && credentials_json !== null) {
//     return callback(null, credentials_json)
//   }
//   credentials_json = JSON.parse(process.env['GOOGLE_SERVICE_ACCOUNT'])
//   return callback(null, credentials_json)
// }

module.exports = function (robot) {
  let spreadsheet_key
  const config = require('hubot-conf')('duties', robot)
  spreadsheet_key = null
  const getDoc = async function () {
    const sp_key = config('spreadsheet')
    if (sp_key == null) {
      return 'No spreadsheet is currently set'
    }
    // if (spreadsheet_key === sp_key) {
    //   return spreadsheet_object
    // }
    const spreadsheet_object = new GoogleSpreadsheet(sp_key)
    await spreadsheet_object.useServiceAccountAuth(credentials)
    await spreadsheet_object.loadInfo()
    spreadsheet_key = sp_key
    return spreadsheet_object
  }
  const getSpreadsheet = async function (name) {
    const doc = await getDoc()
    try {
      const sheet = doc.sheetsByTitle[name]
      return sheet
    } catch (err) {
      return `Could not find sheet with title ${name}`
    }
  }
  const getSpreadsheetRows = async function (name) {
    const sheet = await getSpreadsheet(name)
    const rows = await sheet.getRows()
    return rows
  }
  const dueDate = function (row) {
    return new Date(+(new Date(row.Date)) + 24 * 60 * 60 * 1000 * (+row.Ext + 1) - 1)
  }
  const isActive = function (row, days) {
    days = days != null ? days : 10000
    return String(row.Completed).toLowerCase() === 'no' && row.Brother !== '' && (dueDate(row) - new Date()) < days * 24 * 60 * 60 * 1000
  }
  const dutyToString = function (row) {
    var s
    s = `*${row.Duty}* (${row.Category}): Due _${moment(dueDate(row)).calendar()}_`
    if ((+row.Ext) > 0) {
      s += ` (date includes a ${row.Ext}-day extension)`
    }
    return s
  }
  const instructionToString = function (row) {
    if (row == null) {
      return "Couldn't find instructions"
    }
    return `-- Instructions for the *${row.Duty} ${row.Category}* duty.\n${row.Instructions}`
  }
  const instructionForDuty = function (duty, instruction_rows) {
    var i, len, row
    for (i = 0, len = instruction_rows.length; i < len; i++) {
      row = instruction_rows[i]
      if (duty.Category === row.Category && duty.Duty === row.Duty) {
        return row
      }
    }
    return null
  }
  const delayLoop = function (elements, delay, fn) {
    return elements.forEach(function (element, index) {
      return setTimeout(function () {
        return fn(element)
      }, delay * index)
    })
  }
  const remindPeople = async function (days_in_advance) {
    try {
      const instruction_rows = await getSpreadsheetRows(INSTRUCTIONS_SPREADSHEET_NAME)
      const duty_rows = await getSpreadsheetRows(DUTIES_SPREADSHEET_NAME)
      delayLoop(duty_rows, 600, function (row) {
        var instructions, message, user
        if (isActive(row, days_in_advance)) {
          instructions = instructionForDuty(row, instruction_rows)
          message = `*${row.Category}* reminder: ${dutyToString(row)}\n\n${DUTY_MESSAGES[row.Category]}\n\n${instructionToString(instructions)}`
          user = robot.brain.userForInitials(row.Brother)
          if (user == null) {
            robot.messageRoom('#botspam', "Someone has a housework I couldn't match:\n" + message)
          } else {
            robot.messageRoom(user.name, message)
          }
        }
      })
    } catch (err) {
      robot.messageRoom('#botspam', `Error sending duties pings: ${err}`)
    }
  }
  robot.respond(/houseworks?(.+)$/i, function (res) {
    return res.send('Please use `peckbot duties <whatever>` instead.')
  })
  robot.respond(/duties link$/i, function (res) {
    return res.send(`https://docs.google.com/spreadsheets/d/${config('spreadsheet')}/edit`)
  })
  robot.respond(/duties upcoming$/i, async function (res) {
    const rows = await getSpreadsheetRows(DUTIES_SPREADSHEET_NAME)
    let i, result, row
    result = '*== Upcoming duties ==*\n\n'
    for (i = 0; i < rows.length; i++) {
      row = rows[i]
      if (isActive(row, 5)) {
        result += row.Brother + ' - ' + dutyToString(row) + '\n'
      }
    }
    return res.send(result)
  })
  robot.respond(/duties instructions all$/i, async function (res) {
    const rows = await getSpreadsheetRows(INSTRUCTIONS_SPREADSHEET_NAME)
    let i, len, result, row
    result = ''
    for (i = 0, len = rows.length; i < len; i++) {
      row = rows[i]
      result += `${instructionToString(row)}\n\n`
    }
    res.send(result)
  })
  robot.respond(/duties instructions$/i, async function (res) {
    const person = res.message.user.initials
    const duties = await getSpreadsheetRows(DUTIES_SPREADSHEET_NAME)
    let duty, i, len, row
    duty = null
    for (i = 0, len = duties.length; i < len; i++) {
      row = duties[i]
      if (row.Brother === person && isActive(row)) {
        duty = row
        break
      }
    }
    if (duty == null) {
      return res.send("You don't have any upcoming duties!")
    }
    const instruction_list = await getSpreadsheetRows(INSTRUCTIONS_SPREADSHEET_NAME)
    return res.send(instructionToString(instructionForDuty(duty, instruction_list)))
  })
  robot.respond(/duties?($| [A-Z]{3}$)/i, async function (res) {
    const rows = await getSpreadsheetRows(DUTIES_SPREADSHEET_NAME)
    var i, len, person, result, row
    person = res.match[1] === '' ? res.message.user.initials : res.match[1].trim().toUpperCase()
    result = `*== Duties for ${person} ==*\n\n`
    for (i = 0, len = rows.length; i < len; i++) {
      row = rows[i]
      if (row.Brother === person && isActive(row)) {
        result += dutyToString(row) + '\n'
      }
    }
    return res.send(result)
  })
  robot.respond(/ticket (.+)$/i, async function (res) {
    const sheet = await getSpreadsheet(TICKETS_SPREADSHEET_NAME)
    const newRow = {
      timestamp: moment().format('M/D/YYYY H:mm:ss'),
      priority: "Unassigned",
      broken: res.match[1],
      initials: res.message.user.initials
    }
    sheet.addRow(newRow)
    res.send(`I've marked down that: *${res.match[1]}*`)
  })
  robot.respond(/duties remind($| [0-9]+$)/i, async function (res) {
    res.send("Sending reminders...")
    await remindPeople(+res.match[1] || 1)
  })
  return cron.schedule(config('reminder'), async function () {
    return remindPeople(8) // 8 days in advance
  })
}