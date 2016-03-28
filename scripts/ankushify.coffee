# Description:
#   Ankushify
#
# Commands:
#   hubot ankushify <blah>
#
# Author:
#   Heky

tensify = require('tensify')

ankushify = (sentence) ->
  words = sentence.split(' ')
  for i in [1...(words.length)] by 1
    last_3 = words[i].slice(-3)
    if words[i-1].toLowerCase() == "i"
      return "I " + tensify(words[i]).past + " your mom"
    if last_3 == "ing"
      new_string = ""
      for j in [0...(words[i].length-3)] by 1
        new_string += words[i][j]
      return "Get " + tensify(new_string).past
    if words[i-1].toLowerCase() == "a"
      return "I put a " + words[i] + " in my butt last night"
  "Fuck you"
  

module.exports = (robot) ->
  robot.respond /ankushify (.+)/i, (res) ->
    sentence = res.match[1]
    res.send ankushify(sentence)