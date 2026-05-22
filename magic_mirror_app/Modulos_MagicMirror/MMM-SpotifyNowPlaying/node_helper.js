/**
 * MMM-SpotifyNowPlaying — node_helper.js
 * Comunica com a Spotify Web API para obter a música atual.
 */
const NodeHelper = require("node_helper");
const https = require("https");
const querystring = require("querystring");

module.exports = NodeHelper.create({
    start: function () {
        console.log("MMM-SpotifyNowPlaying: node_helper iniciado.");
        this.accessToken = null;
        this.tokenExpiry = 0;
    },

    socketNotificationReceived: function (notification, payload) {
        if (notification === "SPOTIFY_GET_NOW_PLAYING") {
            this._getAccessToken(payload).then((token) => {
                if (token) this._fetchNowPlaying(token);
            });
        }
    },

    _getAccessToken: function (config) {
        return new Promise((resolve) => {
            // Reutilizar token se ainda for válido
            if (this.accessToken && Date.now() < this.tokenExpiry) {
                return resolve(this.accessToken);
            }

            const authString = Buffer.from(config.clientId + ":" + config.clientSecret).toString("base64");
            const body = querystring.stringify({ grant_type: "refresh_token", refresh_token: config.refreshToken });

            const options = {
                hostname: "accounts.spotify.com",
                path: "/api/token",
                method: "POST",
                headers: {
                    "Authorization": "Basic " + authString,
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
                            console.error("MMM-SpotifyNowPlaying: Falha ao obter access_token:", json);
                            resolve(null);
                        }
                    } catch (e) {
                        console.error("MMM-SpotifyNowPlaying: Erro ao parsear token:", e);
                        resolve(null);
                    }
                });
            });

            req.on("error", (e) => {
                console.error("MMM-SpotifyNowPlaying: Erro HTTPS:", e);
                resolve(null);
            });

            req.write(body);
            req.end();
        });
    },

    _fetchNowPlaying: function (token) {
        const options = {
            hostname: "api.spotify.com",
            path: "/v1/me/player/currently-playing",
            method: "GET",
            headers: { "Authorization": "Bearer " + token },
        };

        const req = https.request(options, (res) => {
            if (res.statusCode === 204) {
                // Nada a tocar
                this.sendSocketNotification("SPOTIFY_NOW_PLAYING", {
                    isPlaying: false,
                    track: null,
                });
                return;
            }

            let data = "";
            res.on("data", (chunk) => (data += chunk));
            res.on("end", () => {
                try {
                    const json = JSON.parse(data);
                    if (!json.item) {
                        this.sendSocketNotification("SPOTIFY_NOW_PLAYING", { isPlaying: false, track: null });
                        return;
                    }

                    const track = {
                        name: json.item.name,
                        artists: json.item.artists.map((a) => a.name).join(", "),
                        album: json.item.album.name,
                        albumArt: json.item.album.images[0]?.url || null,
                        id: json.item.id,
                    };

                    this.sendSocketNotification("SPOTIFY_NOW_PLAYING", {
                        isPlaying: json.is_playing,
                        track,
                        progressMs: json.progress_ms || 0,
                        durationMs: json.item.duration_ms || 0,
                    });
                } catch (e) {
                    this.sendSocketNotification("SPOTIFY_ERROR", { error: "Erro ao parsear resposta: " + e.message });
                }
            });
        });

        req.on("error", (e) => {
            this.sendSocketNotification("SPOTIFY_ERROR", { error: e.message });
        });

        req.end();
    },
});
