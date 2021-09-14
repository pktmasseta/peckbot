// Description:
//   Hubot interface for the PKT Laundry Calendar

// Commands:
//   hubot laundry - gets next 10 laundry appointments
//   hubot laundry add <date> - makes you a laundry appointment for <date>
//   hubot laundry remove <id> - deletes the laundry appointment with id
//   hubot laundry addme <email> - adds your email to the laundry calendar so you get invited to events.
//   hubot laundry next - returns your next appointment.

// Author:
//   Detry322
var SCOPES, apiWrapper, authorize, chrono, createAppointment, credentials_json, deleteAppointment, fs, getAllAppointments, getAuthedClient, getClient, getEmail, getNextAppointment, google, googleAuth, moment, printAppointment, readline, setEmail, storeToken;

fs = require('fs');

readline = require('readline');

google = require('googleapis');

googleAuth = require('google-auth-library');

chrono = require('chrono-node');

moment = require('moment');

SCOPES = ['https://www.googleapis.com/auth/calendar'];

credentials_json = null;

authorize = function(robot, res, callback) {
  if (credentials_json != null) {
    callback(credentials_json);
    return;
  }
  credentials_json = JSON.parse(process.env['GOOGLE_CLIENT_SECRET']);
  return callback(credentials_json);
};

getClient = function(robot, res, callback) {
  return authorize(robot, res, function(credentials) {
    var auth, clientId, clientSecret, oauth2Client, redirectUrl;
    clientSecret = credentials.installed.client_secret;
    clientId = credentials.installed.client_id;
    redirectUrl = credentials.installed.redirect_uris[0];
    auth = new googleAuth();
    oauth2Client = new auth.OAuth2(clientId, clientSecret, redirectUrl);
    return callback(oauth2Client);
  });
};

getAuthedClient = function(robot, res, callback) {
  return getClient(robot, res, function(oauth2Client) {
    var authUrl, token;
    token = robot.brain.get('laundry-calendar-token');
    if (token != null) {
      oauth2Client.credentials = token;
      callback(oauth2Client);
      return;
    }
    authUrl = oauth2Client.generateAuthUrl({
      access_type: 'offline',
      scope: SCOPES
    });
    res.send("This app is not yet authorized, please visit this URL (when logged into the pktlaundry@gmail.com account):\n" + authUrl);
    return res.send("Enter that code by sending 'peckbot laundry storetoken <token>'");
  });
};

storeToken = function(robot, res, code, callback) {
  return getClient(robot, res, function(oauth2Client) {
    return oauth2Client.getToken(code, function(err, token) {
      if (err != null) {
        res.send("Error while trying to retrieve access token");
        return;
      }
      robot.brain.set('laundry-calendar-token', token);
      oauth2Client.credentials = token;
      return callback(oauth2Client);
    });
  });
};

apiWrapper = function(res, callback) {
  return function(err, response) {
    if (err != null) {
      res.send('The API returned an error: ' + err);
      return;
    }
    return callback(response);
  };
};

getAllAppointments = function(robot, res, num, callback) {
  return getAuthedClient(robot, res, function(oauth2Client) {
    return google.calendar('v3').events.list({
      auth: oauth2Client,
      calendarId: 'primary',
      timeMin: (new Date()).toISOString(),
      maxResults: num,
      singleEvents: true,
      orderBy: 'startTime'
    }, apiWrapper(res, function(response) {
      return callback(null, response.items);
    }));
  });
};

getNextAppointment = function(robot, res, user, callback) {
  return getAuthedClient(robot, res, function(oauth2Client) {
    return google.calendar('v3').events.list({
      auth: oauth2Client,
      calendarId: 'primary',
      timeMin: (new Date()).toISOString(),
      maxResults: 1,
      singleEvents: true,
      q: user,
      orderBy: 'startTime'
    }, apiWrapper(res, function(response) {
      if (response.items.length === 0) {
        callback(true);
        return;
      }
      return callback(null, response.items[0]);
    }));
  });
};

createAppointment = function(robot, res, user, date, callback) {
  return getAuthedClient(robot, res, function(oauth2Client) {
    var attendees, email;
    email = getEmail(robot, user);
    attendees = [];
    if (email != null) {
      attendees.push({
        email: email
      });
    }
    return google.calendar('v3').events.insert({
      auth: oauth2Client,
      calendarId: 'primary',
      resource: {
        start: {
          dateTime: date.toISOString()
        },
        end: {
          dateTime: (new Date(date.getTime() + 7200000)).toISOString()
        },
        attendees: attendees,
        sendNotifications: true,
        description: `Laundry use for ${user}`,
        summary: user
      }
    }, apiWrapper(res, function(response) {
      return callback(null, response, email);
    }));
  });
};

deleteAppointment = function(robot, res, eid, callback) {
  return getAuthedClient(robot, res, function(oauth2Client) {
    return google.calendar('v3').events.delete({
      auth: oauth2Client,
      calendarId: 'primary',
      eventId: eid
    }, apiWrapper(res, function(response) {
      return callback(null);
    }));
  });
};

printAppointment = function(appointment, print_id) {
  var end, id, result, start, summary;
  start = moment(new Date(appointment.start.date || appointment.start.dateTime)).calendar();
  end = moment(new Date(appointment.end.date || appointment.end.dateTime)).calendar();
  summary = appointment.summary;
  id = appointment.id;
  result = `*${summary}*: ${start} until ${end}`;
  if (print_id) {
    result += `, ID: ${id}`;
  }
  return result;
};

setEmail = function(robot, user, email) {
  var emails_table;
  emails_table = robot.brain.get('pkt-emails') || {};
  emails_table[user] = email;
  return robot.brain.set('pkt-emails', emails_table);
};

getEmail = function(robot, user) {
  return (robot.brain.get('pkt-emails') || {})[user];
};

module.exports = function(robot) {
  robot.respond(/laundry (add|create) (.+)$/i, function(res) {
    var date, user;
    user = res.message.user.name.toLowerCase();
    date = chrono.parseDate(res.match[2]);
    return createAppointment(robot, res, user, date, function(err, appointment, invited_email) {
      if (err != null) {
        res.send("Couldn't create event.");
        return;
      }
      res.send(`I created an appointment for you, ${user}:\n` + printAppointment(appointment, true));
      if (invited_email != null) {
        return res.send(`I also invited ${invited_email} as you requested.`);
      }
    });
  });
  robot.respond(/laundry (delete|remove) ([a-zA-Z0-9]+)$/i, function(res) {
    return deleteAppointment(robot, res, res.match[2], function(err) {
      if (err != null) {
        res.send("Couldn't delete event.");
        return;
      }
      return res.send("Successfully deleted event.");
    });
  });
  robot.respond(/laundry next\s*$/i, function(res) {
    var user;
    user = res.message.user.name.toLowerCase();
    return getNextAppointment(robot, res, user, function(err, appointment) {
      if (err != null) {
        res.send("You don't have a next appointment booked.");
        return;
      }
      return res.send(printAppointment(appointment, true));
    });
  });
  robot.respond(/laundry revoketoken\s*$/i, function(res) {
    robot.brain.set('laundry-calendar-token', null);
    return res.send("Token revoked.");
  });
  robot.respond(/laundry storetoken (.+)$/i, function(res) {
    return storeToken(robot, res, res.match[1], function() {
      return res.send("Token stored! Please try your command again.");
    });
  });
  robot.respond(/laundry addme (.+)$/i, function(res) {
    var user;
    user = res.message.user.name.toLowerCase();
    setEmail(robot, user, res.match[1]);
    return res.send(`Thanks! I'll now invite ${res.match[1]} to all future events created by you.`);
  });
  robot.respond(/laundry removeme\s*$/i, function(res) {
    var emails_table, user;
    user = res.message.user.name.toLowerCase();
    emails_table = robot.brain.get('pkt-emails') || {};
    delete emails_table[user];
    robot.brain.set('pkt-emails', emails_table);
    return res.send("OK! Removed your email from the list.");
  });
  return robot.respond(/laundry\s*$/i, function(res) {
    return getAllAppointments(robot, res, 10, function(err, appointments) {
      var appointment, i, len, response;
      if (err != null) {
        res.send("Couldn't fetch appointments.");
        return;
      }
      response = "";
      if (appointments.length > 0) {
        for (i = 0, len = appointments.length; i < len; i++) {
          appointment = appointments[i];
          response += (printAppointment(appointment, true)) + "\n";
        }
        return res.send(response);
      } else {
        return res.send("I can't see any appointments in the near future.");
      }
    });
  });
};
