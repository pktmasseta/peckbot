# Description:
#   Ankushify
#
# Commands:
#   hubot ankushify <blah>
#
# Author:
#   HEKY


ankushify = (sentence) ->
  words = sentence.split(' ')
  for i in [1...(words.length)] by 1
    if words[i-1].toLowerCase() == "i"
      return "I " + words[i] + "ed your mom"
  "Fuck you"
  

module.exports = (robot) ->
  robot.respond /ankushify (.+)/i, (res) ->
    sentence = res.match[1]
    res.send ankushify(sentence)