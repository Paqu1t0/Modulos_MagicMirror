/**
 * MMM-SpotifyNowPlaying
 * Módulo criado pela nossa equipa.
 * Mostra a música atual do Spotify no espelho inteligente.
 *
 * Pré-requisito: criar uma app em https://developer.spotify.com/dashboard
 * e configurar o Client ID, Client Secret e Refresh Token no config.js.
 *
 * Configuração no config.js do MagicMirror:
 * {
 *   module: "MMM-SpotifyNowPlaying",
 *   position: "bottom_left",
 *   config: {
 *     clientId: "SEU_CLIENT_ID",
 *     clientSecret: "SEU_CLIENT_SECRET",
 *     refreshToken: "SEU_REFRESH_TOKEN",
 *     updateInterval: 5000,       // Atualização a cada 5 segundos
 *     showAlbumArt: true,         // Mostrar capa do álbum
 *     showProgressBar: true,      // Mostrar barra de progresso
 *     idleMessage: "🎵 Nada a tocar",
 *   }
 * }
 */
Module.register("MMM-SpotifyNowPlaying", {
    defaults: {
        clientId: "",
        clientSecret: "",
        refreshToken: "",
        updateInterval: 5000,
        showAlbumArt: true,
        showProgressBar: true,
        idleMessage: "Nada a tocar",
    },

    start: function () {
        this.currentTrack = null;
        this.isPlaying = false;
        this.progressMs = 0;
        this.durationMs = 0;
        this.updateTimer = null;

        Log.info("MMM-SpotifyNowPlaying: A iniciar...");

        if (!this.config.clientId || !this.config.refreshToken) {
            Log.warn("MMM-SpotifyNowPlaying: clientId e refreshToken são obrigatórios!");
            return;
        }

        this._fetchNowPlaying();
    },

    getStyles: function () {
        return ["MMM-SpotifyNowPlaying.css"];
    },

    getDom: function () {
        const wrapper = document.createElement("div");
        wrapper.className = "mmm-spotify-wrapper";

        if (!this.currentTrack || !this.isPlaying) {
            const card = document.createElement("div");
            card.className = "mmm-spotify-card mmm-spotify-card-idle";

            const art = document.createElement("div");
            art.className = "mmm-spotify-album-art mmm-spotify-album-art-idle";
            card.appendChild(art);

            const info = document.createElement("div");
            info.className = "mmm-spotify-info";

            const title = document.createElement("div");
            title.className = "mmm-spotify-title mmm-spotify-title-idle";
            let msg = this.config.idleMessage.replace('🎵 ', '').replace('🎵', '');
            title.innerText = msg || "Nada a tocar";
            info.appendChild(title);

            const artist = document.createElement("div");
            artist.className = "mmm-spotify-artist mmm-spotify-artist-idle";
            artist.innerText = "Spotify";
            info.appendChild(artist);

            if (this.config.showProgressBar) {
                const progressContainer = document.createElement("div");
                progressContainer.className = "mmm-spotify-progress-container";
                const bar = document.createElement("div");
                bar.className = "mmm-spotify-progress-bar mmm-spotify-progress-bar-idle";
                bar.style.width = "0%";
                progressContainer.appendChild(bar);
                info.appendChild(progressContainer);
            }

            card.appendChild(info);

            const logo = document.createElement("div");
            logo.className = "mmm-spotify-logo mmm-spotify-logo-idle";
            logo.innerHTML = `<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                <path fill="#1DB954" d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z"/>
            </svg>`;
            card.appendChild(logo);

            wrapper.appendChild(card);
            return wrapper;
        }

        const track = this.currentTrack;

        // Layout principal
        const card = document.createElement("div");
        card.className = "mmm-spotify-card";

        // Capa do álbum
        if (this.config.showAlbumArt && track.albumArt) {
            const art = document.createElement("img");
            art.className = "mmm-spotify-album-art";
            art.src = track.albumArt;
            art.alt = track.album;
            card.appendChild(art);
        }

        // Info da música
        const info = document.createElement("div");
        info.className = "mmm-spotify-info";

        const title = document.createElement("div");
        title.className = "mmm-spotify-title";
        title.innerText = track.name;
        info.appendChild(title);

        const artist = document.createElement("div");
        artist.className = "mmm-spotify-artist";
        artist.innerText = track.artists;
        info.appendChild(artist);

        const album = document.createElement("div");
        album.className = "mmm-spotify-album";
        album.innerText = track.album;
        info.appendChild(album);

        // Barra de progresso
        if (this.config.showProgressBar && this.durationMs > 0) {
            const progressContainer = document.createElement("div");
            progressContainer.className = "mmm-spotify-progress-container";

            const bar = document.createElement("div");
            bar.className = "mmm-spotify-progress-bar";
            const pct = Math.min((this.progressMs / this.durationMs) * 100, 100);
            bar.style.width = pct + "%";
            progressContainer.appendChild(bar);

            const times = document.createElement("div");
            times.className = "mmm-spotify-times";
            times.innerHTML = `<span>${this._msToTime(this.progressMs)}</span><span>${this._msToTime(this.durationMs)}</span>`;
            info.appendChild(progressContainer);
            info.appendChild(times);
        }

        card.appendChild(info);

        // Ícone do Spotify
        const logo = document.createElement("div");
        logo.className = "mmm-spotify-logo";
        logo.innerHTML = `<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <path fill="#1DB954" d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z"/>
        </svg>`;
        card.appendChild(logo);

        wrapper.appendChild(card);
        return wrapper;
    },

    socketNotificationReceived: function (notification, payload) {
        if (notification === "SPOTIFY_NOW_PLAYING") {
            this.currentTrack = payload.track;
            this.isPlaying = payload.isPlaying;
            this.progressMs = payload.progressMs || 0;
            this.durationMs = payload.durationMs || 0;
            this.updateDom();
            this._startProgressTimer();
        }
        if (notification === "SPOTIFY_ERROR") {
            Log.error("MMM-SpotifyNowPlaying: " + payload.error);
        }
    },

    _fetchNowPlaying: function () {
        this.sendSocketNotification("SPOTIFY_GET_NOW_PLAYING", {
            clientId: this.config.clientId,
            clientSecret: this.config.clientSecret,
            refreshToken: this.config.refreshToken,
        });

        if (this.updateTimer) clearTimeout(this.updateTimer);
        this.updateTimer = setTimeout(() => {
            this._fetchNowPlaying();
        }, this.config.updateInterval);
    },

    _startProgressTimer: function () {
        if (this.progressTimer) clearInterval(this.progressTimer);
        if (!this.isPlaying || this.progressMs >= this.durationMs) return;

        this.progressTimer = setInterval(() => {
            if (this.progressMs < this.durationMs) {
                this.progressMs += 1000;
                if (this.progressMs > this.durationMs) this.progressMs = this.durationMs;
                this.updateDom();
            } else {
                clearInterval(this.progressTimer);
            }
        }, 1000);
    },

    _msToTime: function (ms) {
        const totalSec = Math.floor(ms / 1000);
        const min = Math.floor(totalSec / 60);
        const sec = totalSec % 60;
        return `${min}:${sec.toString().padStart(2, "0")}`;
    },

    suspend: function () {
        if (this.updateTimer) clearTimeout(this.updateTimer);
        if (this.progressTimer) clearInterval(this.progressTimer);
    },

    resume: function () {
        this._fetchNowPlaying();
    },
});
