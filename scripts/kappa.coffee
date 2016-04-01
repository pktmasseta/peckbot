# Description:
#   Language Aquisition bot
#
# Commands:
#   hubot speak
#
# Author:
#   Heky
starting_words = []
#dictionary of the form {I:{am:2),{will:1)}}
words = {}

isInArray = (value, array) ->
  return array.indexOf(value) > -1

add_to_experience = (sentence) ->
  new_words = sentence.split(" ")
  if new_words[-1][-1] == "."
    minus_period = new_words[-1].slice(".")
    new_words.pop()
    new_words.splice(-1, 0, minus_period)
  if new_words[-1][-1] == "?"
    minus_period = new_words[-1].slice("?")
    new_words.pop()
    new_words.splice(-1, 0, minus_period)
  new_words.splice(-1, 0, ".")
  new_words.forEach(toLowerCase())
  if isinArray(words[0], starting_words) == false
    starting_words.splice(-1, 0, new_words[0])
  for i in [0...new_words.length-1] by 1
    if new_words[i] == "."
      return
    if isinArray(new_words[i], words)
      if isinArray(new_words[i+1], words[new_words[i]])
        words[new_words[i]][new_words[i+1]] += 1
      else
        words[new_words[i]].splice(-1, 0, {new_words[i+1]:1})
    else 
      words[new_words[i]] == {new_words[i+1]:1}
  
  
next_word_selector = (word) ->
  if isinArray(word, words.keys()) == false
    return "."
  possible = words[word]
  best_choice = ""
  best_choice_value = 0
  for i in [0...(possible.keys().length)] by 1
    word = possible.keys()[i]
    if word > best_choice_value
      best_choice = word
      best_choice_value = possible[word]
  best_choice

module.exports = (robot) ->
  robot.hear /.+/, (res) ->
    add_to_experience(res.message.text)
   
   robot.respond /speak$/,i (res) ->
    speak = starting_words[randomInt(1, starting_words.length)]
    last_added = speak
    while lasted_added != "."
      if speak.length >= 60
        last_added = "."
        speak.splice(".")
      else
        speak += " "
        speak += next_word_selector(last_added)
    speak