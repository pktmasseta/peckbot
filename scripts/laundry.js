// Description:
//   Hubot interface for the PKT Laundry Calendar
//
// Commands:
//   hubot laundry - gets next 10 laundry appointments
//   hubot laundry add <date> - makes you a laundry appointment for <date>
//   hubot laundry remove <id> - deletes the laundry appointment with id
//   hubot laundry addme <email> - adds your email to the laundry calendar so you get invited to events.
//   hubot laundry next - returns your next appointment.
//
// Author:
//   Detry322

const { google } = require('googleapis')
const gal = require('google-auth-library')
const chrono = require('chrono-node')
const moment = require('moment')

const SCOPES = ['https://www.googleapis.com/auth/calendar']

const credentials_json = JSON.parse(process.env['GOOGLE_CLIENT_SECRET'])

const getClient = async function (robot, res) {
    let clientSecret = credentials_json.installed.client_secret;
    let clientID = credentials_json.installed.client_id;
    let redirectURL = credentials_json.installed.redirect_uris[0];
    const oauth2Client = new gal.OAuth2Client(clientID, clientSecret, redirectURL);
    return oauth2Client;
}
// TODO: Instantiate local web server to accept oauth callback
const getAuthedClient = async function (robot, res) {
    const oauth2Client = await getClient(robot, res)
    let tokens = robot.brain.get('laundry-calendar-tokens')
    console.log(tokens)
    if (tokens != null) {
        oauth2Client.setCredentials(tokens)
        return oauth2Client
    }
    const authUrl = await oauth2Client.generateAuthUrl({
        access_type: 'offline',
        scope: SCOPES,
        // Refresh token only returned first time user consents to access
        prompt: 'consent'
    })
    res.send("This app is not yet authorized, please visit this URL (when logged into the pktlaundry@gmail.com account):\n" + authUrl)
    res.send("Enter that code by sending 'peckbot laundry storetoken <tokens>'")
}
storeTokens = async function (robot, res, code) {
    const oauth2Client = await getClient(robot, res)
    oauth2Client.getToken(code, function (err, token) {
        if (err) return console.error('Error retrieving access token', err);
        oauth2Client.setCredentials(token);
        robot.brain.set('laundry-calendar-tokens', oauth2Client.credentials);
    })
    res.send("Token has been succesfully stored!")
}

getTokensInfo = async function (robot, res) {
    const oauth2Client = await getAuthedClient(robot, res)
    const accessTokenInfo = await oauth2Client.getTokenInfo(oauth2Client.credentials.access_token)
    const refreshTokenInfo = await oauth2Client.getTokenInfo(oauth2Client.credentials.refresh_token)
    return (accessTokenInfo, refreshTokenInfo)
}
apiWrapper = async function (res, callback) {
    return async function (err, response) {
        if (err != null) {
            res.send('The API returned an error: ' + err);
            return;
        }
        return callback(response);
    };
};

getAllAppointments = async function (robot, res, num, callback) {
    let oauth2Client = await getAuthedClient(robot, res)
    const calendar = google.calendar({version: 'v3', oauth2Client});
    return calendar.events.list({
        auth: oauth2Client,
        calendarId: 'primary',
        timeMin: (new Date()).toISOString(),
        maxResults: num,
        singleEvents: true,
        orderBy: 'startTime'
    }, apiWrapper(res, async function (response) {
        return callback(null, response.items)
    }))

};

getNextAppointment = async function (robot, res, user, callback) {
    let oauth2Client = await getAuthedClient(robot, res)
    const calendar = google.calendar({version: 'v3', oauth2Client});
    return calendar.events.list({
        auth: oauth2Client,
        calendarId: 'primary',
        timeMin: (new Date()).toISOString(),
        maxResults: 1,
        singleEvents: true,
        q: user,
        orderBy: 'startTime'
    }, apiWrapper(res, async function (response) {
        if (response.items.length === 0) {
            callback(true);
            return;
        }
        return callback(null, response.items[0]);
    }));
};

createAppointment = async function (robot, res, user, date, callback) {
    let oauth2Client = getAuthedClient(robot, res)
    let attendees, email;
    email = getEmail(robot, user);
    attendees = [];
    if (email != null) {
        attendees.push({
            email: email
        });
    }
    const calendar = google.calendar({version: 'v3', oauth2Client});
    return calendar.events.insert({
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
    }, apiWrapper(res, async function (response) {
        return callback(null, response, email);
    }));
};

deleteAppointment = async function (robot, res, eid, callback) {
    let oauth2Client = await getAuthedClient(robot, res)
    const calendar = google.calendar({version: 'v3', oauth2Client});
    return calendar.events.delete({
        auth: oauth2Client,
        calendarId: 'primary',
        eventId: eid
    }, apiWrapper(res, async function (response) {
        return callback(null);
    }));
};

printAppointment = function (appointment, print_id) {
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

setEmail = function (robot, user, email) {
    var emails_table;
    emails_table = robot.brain.get('pkt-emails') || {};
    emails_table[user] = email;
    return robot.brain.set('pkt-emails', emails_table);
};

getEmail = function (robot, user) {
    return (robot.brain.get('pkt-emails') || {})[user];
};

module.exports = async function (robot) {
    robot.respond(/laundry (add|create) (.+)$/i, async function (res) {
        var date, user;
        user = res.message.user.name.toLowerCase();
        date = chrono.parseDate(res.match[2]);
        return createAppointment(robot, res, user, date, async function (err, appointment, invited_email) {
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
    robot.respond(/laundry (delete|remove) ([a-zA-Z0-9]+)$/i, async function (res) {
        return deleteAppointment(robot, res, res.match[2], async function (err) {
            if (err != null) {
                res.send("Couldn't delete event.");
                return;
            }
            return res.send("Successfully deleted event.");
        });
    });
    robot.respond(/laundry next\s*$/i, async function (res) {
        var user;
        user = res.message.user.name.toLowerCase();
        return getNextAppointment(robot, res, user, async function (err, appointment) {
            if (err != null) {
                res.send("You don't have a next appointment booked.");
                return;
            }
            return res.send(printAppointment(appointment, true));
        });
    });
    robot.respond(/laundry revoketokens\s*$/i, async function (res) {
        robot.brain.set('laundry-calendar-token', null);
        return res.send("Token revoked.");
    });
    robot.respond(/laundry storetokens (.+)$/i, async function (res) {
        return await storeTokens(robot, res, res.match[1])
    });
    robot.respond(/laundry displaytokens$/i, async function (res) {
        return res.send(getTokensInfo(robot, res, async function (err, accessTokenInfo, refreshTokenInfo) {
            if (err != null) {
                res.send("Failed to get token info.");
                return;
            }
            return res.send(accessTokenInfo + refreshTokenInfo)
        }))
    })
    robot.respond(/laundry addme (.+)$/i, async function (res) {
        var user;
        user = res.message.user.name.toLowerCase();
        setEmail(robot, user, res.match[1]);
        return res.send(`Thanks! I'll now invite ${res.match[1]} to all future events created by you.`);
    });
    robot.respond(/laundry removeme\s*$/i, async function (res) {
        var emails_table, user;
        user = res.message.user.name.toLowerCase();
        emails_table = robot.brain.get('pkt-emails') || {};
        delete emails_table[user];
        robot.brain.set('pkt-emails', emails_table);
        return res.send("OK! Removed your email from the list.");
    });
    return robot.respond(/laundry\s*$/i, async function (res) {
        return getAllAppointments(robot, res, 10, async function (err, appointments) {
            var appointment, i, len, response;
            if (err != null) {
                res.send("Couldn't fetch appointments.");
                return
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
