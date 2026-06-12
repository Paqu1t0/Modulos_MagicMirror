/**
 * MMM-GoogleCalendar
 * Módulo criado pela nossa equipa.
 * Mostra eventos do Google Calendar no espelho inteligente.
 *
 * Pré-requisito: criar credenciais OAuth 2.0 em https://console.cloud.google.com
 * e obter o refresh_token com o scope "https://www.googleapis.com/auth/calendar.readonly"
 *
 * Configuração no config.js do MagicMirror:
 * {
 *   module: "MMM-GoogleCalendar",
 *   position: "top_right",
 *   config: {
 *     clientId: "SEU_CLIENT_ID",
 *     clientSecret: "SEU_CLIENT_SECRET",
 *     refreshToken: "SEU_REFRESH_TOKEN",
 *     calendarId: "primary",       // "primary" ou email do calendário
 *     maxEvents: 5,                // Máximo de eventos a mostrar
 *     updateInterval: 300000,      // Atualizar a cada 5 minutos
 *     showLocation: true,          // Mostrar localização do evento
 *     daysAhead: 7,               // Quantos dias à frente buscar
 *   }
 * }
 */
Module.register("MMM-GoogleCalendar", {
    defaults: {
        clientId: "",
        clientSecret: "",
        refreshToken: "",
        calendarId: "primary",
        maxEvents: 5,
        updateInterval: 300000,
        showLocation: true,
        daysAhead: 7,
    },

    start: function () {
        this.events = [];
        this.loaded = false;
        this.error = null;

        Log.info("MMM-GoogleCalendar: A iniciar...");

        if (!this.config.clientId || !this.config.refreshToken) {
            this.error = "clientId e refreshToken são obrigatórios!";
            return;
        }

        this._fetchEvents();
    },

    getStyles: function () {
        return ["MMM-GoogleCalendar.css"];
    },

    getDom: function () {
        const wrapper = document.createElement("div");
        wrapper.className = "mmm-gcal-wrapper";

        if (this.error) {
            const err = document.createElement("div");
            err.className = "mmm-gcal-error";
            err.innerHTML = '<i class="fa fa-exclamation-triangle"></i> ' + this.error;
            wrapper.appendChild(err);
            return wrapper;
        }

        if (!this.loaded) {
            const loading = document.createElement("div");
            loading.className = "mmm-gcal-loading";
            loading.innerHTML = '<i class="fa fa-calendar fa-spin"></i> A sincronizar calendário...';
            wrapper.appendChild(loading);
            return wrapper;
        }

        // Título
        const header = document.createElement("div");
        header.className = "mmm-gcal-header";
        header.innerHTML = `<span class="mmm-gcal-icon"><i class="fa fa-calendar"></i></span> <span>Próximos Eventos</span>`;
        wrapper.appendChild(header);

        if (this.events.length === 0) {
            const empty = document.createElement("div");
            empty.className = "mmm-gcal-empty";
            empty.innerText = "Sem eventos nos próximos " + this.config.daysAhead + " dias.";
            wrapper.appendChild(empty);
            return wrapper;
        }

        const list = document.createElement("ul");
        list.className = "mmm-gcal-list";

        this.events.forEach((event) => {
            const item = document.createElement("li");
            item.className = "mmm-gcal-item";

            // Indicador de data
            const dateTag = document.createElement("div");
            dateTag.className = "mmm-gcal-date-tag";
            dateTag.innerHTML = this._formatDate(event.start);
            item.appendChild(dateTag);

            // Info do evento
            const info = document.createElement("div");
            info.className = "mmm-gcal-info";

            const title = document.createElement("div");
            title.className = "mmm-gcal-title";
            title.innerText = event.summary || "(Sem título)";
            info.appendChild(title);

            if (event.timeStr) {
                const time = document.createElement("div");
                time.className = "mmm-gcal-time";
                time.innerHTML = '<i class="fa fa-clock-o"></i> ' + event.timeStr;
                info.appendChild(time);
            }

            if (this.config.showLocation && event.location) {
                const loc = document.createElement("div");
                loc.className = "mmm-gcal-location";
                loc.innerHTML = '<i class="fa fa-map-marker"></i> ' + event.location;
                info.appendChild(loc);
            }

            item.appendChild(info);
            list.appendChild(item);
        });

        wrapper.appendChild(list);
        return wrapper;
    },

    socketNotificationReceived: function (notification, payload) {
        if (notification === "GCAL_EVENTS") {
            this.events = payload.events;
            this.loaded = true;
            this.error = null;
            this.updateDom();
        }
        if (notification === "GCAL_ERROR") {
            this.error = payload.error;
            this.loaded = true;
            this.updateDom();
        }
    },

    _fetchEvents: function () {
        this.sendSocketNotification("GCAL_FETCH", {
            clientId: this.config.clientId,
            clientSecret: this.config.clientSecret,
            refreshToken: this.config.refreshToken,
            calendarId: this.config.calendarId,
            maxEvents: this.config.maxEvents,
            daysAhead: this.config.daysAhead,
        });

        if (this.fetchTimer) clearTimeout(this.fetchTimer);
        this.fetchTimer = setTimeout(() => {
            this._fetchEvents();
        }, this.config.updateInterval);
    },

    _formatDate: function (dateStr) {
        const date = new Date(dateStr);
        const today = new Date();
        const tomorrow = new Date(today);
        tomorrow.setDate(today.getDate() + 1);

        if (date.toDateString() === today.toDateString()) return "HOJE";
        if (date.toDateString() === tomorrow.toDateString()) return "AMANHÃ";

        const days = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"];
        return days[date.getDay()] + " " + date.getDate() + "/" + (date.getMonth() + 1);
    },

    suspend: function () {
        if (this.fetchTimer) clearTimeout(this.fetchTimer);
    },

    resume: function () {
        this._fetchEvents();
    },
});
