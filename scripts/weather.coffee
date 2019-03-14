# Description:
#   Find weather in Boston
#
# Commands:
#   hubot weather
#
# Author:
#   nsykes

module.exports = (robot) ->

  robot.respond /weather/i, (msg) ->
    location = "02116" || process.env.HUBOT_DARK_SKY_DEFAULT_LOCATION
    return if not location

    googleurl = "http://maps.googleapis.com/maps/api/geocode/json"
    q = sensor: false, address: location
    msg.http(googleurl)
      .query(q)
      .get() (err, res, body) ->
        result = JSON.parse(body)

        if result.results.length > 0
          lat = result.results[0].geometry.location.lat
          lng = result.results[0].geometry.location.lng
          darkSkyMe msg, lat,lng , (darkSkyText) ->
            response = "Weather for #{result.results[0].formatted_address}. #{darkSkyText}"
            msg.send response
        else
          msg.send "Couldn't find #{location}"

darkSkyMe = (msg, lat, lng, cb) ->
  url = "https://api.forecast.io/forecast/#{process.env.HUBOT_DARK_SKY_API_KEY}/#{lat},#{lng}/"
  if process.env.HUBOT_DARK_SKY_UNITS
    url += "?units=#{process.env.HUBOT_DARK_SKY_UNITS}"
  msg.http(url)
    .get() (err, res, body) ->
      result = JSON.parse(body)

      if result.error
        cb "#{result.error}"
        return

      isFahrenheit = process.env.HUBOT_DARK_SKY_UNITS == "us"
      if isFahrenheit
        fahrenheit = result.currently.temperature
        celsius = (fahrenheit - 32) * (5 / 9)
      else
        celsius = result.currently.temperature
        fahrenheit = celsius * (9 / 5) + 32
      response = "Currently: #{result.currently.summary} (#{fahrenheit}°F/"
      response += "#{celsius}°C). "
      response += "Today: #{result.hourly.summary} "
      response += "Coming week: #{result.daily.summary}"
      cb response