/**
 * MMM-GoogleCalendar — node_helper.js
 * Obtém eventos do Google Calendar via OAuth 2.0.
 */
const NodeHelper = require("node_helper");
const https = require("https");
const querystring = require("querystring");

module.exports = NodeHelper.create({
    start: function () {
        console.log("MMM-GoogleCalendar: node_helper iniciado.");
        this.accessToken = null;
        this.tokenExpiry = 0;
    },

    socketNotificationReceived: function (notification, payload) {
        if (notification === "GCAL_FETCH") {
            this._getAccessToken(payload).then((token) => {
                if (token) this._fetchEvents(token, payload);
                else this.sendSocketNotification("GCAL_ERROR", { error: "Não foi possível obter o token de acesso." });
            });
        }
    },

    _getAccessToken: function (config) {
        return new Promise((resolve) => {
            if (this.accessToken && Date.now() < this.tokenExpiry) {
                return resolve(this.accessToken);
            }

            const body = querystring.stringify({
                client_id: config.clientId,
                client_secret: config.clientSecret,
                refresh_token: config.refreshToken,
                grant_type: "refresh_token",
            });

            const options = {
                hostname: "oauth2.googleapis.com",
                path: "/token",
                method: "POST",
                headers: {
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Content-Length": Buffer.byteLength(body),
                },
            };

            const req = https.request(options, (res) => {
                let data = "";
                res.on("data", (chunk) => (data += chunk));
                res.on("end", () => {
                    try {
                        const json = JSON.parse(data);
                        if (json.access_token) {
                            this.accessToken = json.access_token;
                            this.tokenExpiry = Date.now() + (json.expires_in - 60) * 1000;
                            resolve(json.access_token);
                        } else {
                            console.error("MMM-GoogleCalendar: Token error:", json);
                            resolve(null);
                        }
                    } catch (e) {
                        resolve(null);
                    }
                });
            });

            req.on("error", () => resolve(null));
            req.write(body);
            req.end();
        });
    },

    _fetchEvents: function (token, config) {
        const now = new Date().toISOString();
        const future = new Date(Date.now() + config.daysAhead * 24 * 60 * 60 * 1000).toISOString();
        const calId = encodeURIComponent(config.calendarId || "primary");

        const params = querystring.stringify({
            timeMin: now,
            timeMax: future,
            maxResults: config.maxEvents || 5,
            singleEvents: true,
            orderBy: "startTime",
        });

        const options = {
            hostname: "www.googleapis.com",
            path: `/calendar/v3/calendars/${calId}/events?${params}`,
            method: "GET",
            headers: { "Authorization": "Bearer " + token },
        };

        const req = https.request(options, (res) => {
            let data = "";
            res.on("data", (chunk) => (data += chunk));
            res.on("end", () => {
                try {
                    const json = JSON.parse(data);
                    if (!json.items) {
                        this.sendSocketNotification("GCAL_ERROR", {
                            error: json.error?.message || "Sem eventos na resposta.",
                        });
                        return;
                    }

                    const events = json.items.map((ev) => {
                        const startRaw = ev.start?.dateTime || ev.start?.date;
                        const endRaw = ev.end?.dateTime || ev.end?.date;
                        const isAllDay = !ev.start?.dateTime;

                        let timeStr = null;
                        if (!isAllDay && startRaw) {
                            const s = new Date(startRaw);
                            const e = new Date(endRaw);
                            const fmt = (d) =>
                                d.getHours().toString().padStart(2, "0") +
                                ":" +
                                d.getMinutes().toString().padStart(2, "0");
                            timeStr = fmt(s) + " – " + fmt(e);
                        } else {
                            timeStr = "Dia inteiro";
                        }

                        return {
                            summary: ev.summary,
                            start: startRaw,
                            end: endRaw,
                            timeStr,
                            location: ev.location || null,
                            isAllDay,
                        };
                    });

                    this.sendSocketNotification("GCAL_EVENTS", { events });
                    console.log("MMM-GoogleCalendar: " + events.length + " evento(s) carregado(s).");
                } catch (e) {
                    this.sendSocketNotification("GCAL_ERROR", { error: "Erro ao parsear eventos: " + e.message });
                }
            });
        });

        req.on("error", (e) => {
            this.sendSocketNotification("GCAL_ERROR", { error: e.message });
        });
        req.end();
    },
});
