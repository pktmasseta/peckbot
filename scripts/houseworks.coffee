# Description:
#   Houseworks schedule
#
# Commands:
#   hubot houseworks
#   hubot houseworks get <description of time>
#   hubot houseworks ping
#
#
# Author:
#   Detry322


chrono = require('chrono-node')
moment = require('moment')

text_schedule = """
Date,Basement,Bike/Weight Room/Entrance,2nd Bath,3rd Bath,4th Bath,Chapter,Main Stair/4th Lounge,First Front,First Rear,Back Stair/Pantry,Kitchen
9/17/2016,JXM,SXS,DXZ,FAS,JAZ,DXD,BJO,AWW,JSS,SXM,AXS
9/24/2016,BTC,AXG,KSB,KXT,DTZ,CEC,YXZ,AYH,DPK,KMB,ASL
10/1/2016,BJO,DXD,DXZ,NFV,LWZ,AXS,JAZ,ACA,JAC,MJH,DXZ
10/8/2016,KXT,DPK,VXF,ASL,CEC,KSB,SXM,VXF,BTC,JXM,AYH
10/15/2016,LWZ,SXS,AXG,MJH,YXZ,KMB,KSP,JAZ,NFV,JSS,AWW
10/22/2016,AWW,ASL,ACA,AYH,BTC,JAC,DTZ,CEC,RKP,ASV,KSB
10/28/2016,YXZ,KXT,BJO,DPK,KMB,ASL,LWZ,KSP,AXG,EXA,FAS
11/5/2016,NFV,JSS,ASV,JAC,DXD,ACA,VXF,RKP,SXM,CEC,DTZ
11/12/2016,AXG,SXS,EXA,AXS,JXM,DTZ,BTC,KMB,YXZ,KXT,JAZ
11/19/2016,RKP,NFV,VXF,JSS,BJO,LWZ,DXD,DPK,MJH,FAS,ASV
11/26/2016,EXA,AYH,KSP,SXS,SXM,AWW,JAC,KSB,JXM,AXS,ACA
12/3/2016,FAS,LWZ,BJO,MJH,KSP,KXT,CEC,ASL,JAZ,BTC,RKP
12/10/2016,KMB,SXS,ASV,FAS,JSS,SXM,AXS,DXZ,AWW,KSP,EXA
"""

parseSchedule = () ->
  splitted = text_schedule.trim().split('\n')
  titles = splitted.shift().split(',')
  titles.shift()
  result = []
  for s in array
    stuff = s.split(',')
    text_date = stuff.shift()
    date = moment(text_date)
    other_result = {}
    other_result['date'] = text_date
    for _, i in stuff
      other_result[titles[i]] = stuff[i]
    result.push([date, other_result])
  return result

schedule = parseSchedule()

formatDict = (robot, dict, ping) ->
  result = "*Houseworks for #{dict['date']}*\n\n"
  for key, value of dict
    if key == 'date'
      continue
    result += "*#{key}*: "
    if not ping
      result += value
    else
      slack = robot.brain.userForInitials(value)['name']
      if slack
        result += "<@#{slack}>"
      else
        result += value
    result += '\n'
  return result.trim()

findWeek = (day) ->
  for elem of schedule
    time = elem[0]
    if (time - day) > -24*60*60*1000*2 and (time - day) <= -24*60*60*1000*5
      return elem[1]

module.exports = (robot) ->

  robot.respond /houseworks$/i, (res) ->
    day = new Date()
    res.send formatDict(robot, findWeek(day), false)

  robot.respond /houseworks ping$/i, (res) ->
    day = new Date()
    res.send formatDict(robot, findWeek(day), true)

  robot.respond /houseworks get (.+)$/i, (res) ->
    day = chrono.parseDate res.match[1]
    res.send formatDict(robot, findWeek(day), false)
