/**
 * MMM-BusCPT
 * Módulo para MagicMirror² criado pela nossa equipa.
 * Mostra contagens decrescentes para as próximas carreiras da STCP (Porto).
 */
Module.register("MMM-BusCPT", {
    defaults: {
        stopId: "BTLH6",          // Código da paragem (ex: BTLH6 = Batalha)
        updateInterval: 30000,    // Atualizar a cada 30 segundos
        maxResults: 5,            // Número máximo de carreiras a exibir
        showColors: true          // Usar cores específicas das carreiras
    },

    start: function () {
        Log.info("MMM-BusCPT: A iniciar...");
        this.stopData = null;
        this.loaded = false;
        this.error = null;

        this.getData();
        
        // Ciclo automático de atualização
        var self = this;
        setInterval(function () {
            self.getData();
        }, this.config.updateInterval);
    },

    getStyles: function () {
        return ["MMM-BusCPT.css"];
    },

    getData: function () {
        this.sendSocketNotification("BUSCPT_FETCH", {
            stopId: this.config.stopId
        });
    },

    socketNotificationReceived: function (notification, payload) {
        if (notification === "BUSCPT_DATA") {
            this.stopData = payload;
            this.loaded = true;
            this.error = null;
            this.updateDom();
        } else if (notification === "BUSCPT_ERROR") {
            this.error = payload.error;
            this.loaded = true;
            this.updateDom();
        }
    },

    getDom: function () {
        const wrapper = document.createElement("div");
        wrapper.className = "mmm-buscpt-wrapper";

        if (!this.loaded) {
            wrapper.innerHTML = '<span class="mmm-buscpt-loading"><i class="fa fa-spinner fa-pulse"></i> 🚌 A carregar horários STCP...</span>';
            return wrapper;
        }

        if (this.error) {
            wrapper.innerHTML = `<span class="mmm-buscpt-error">⚠️ ${this.error}</span>`;
            return wrapper;
        }

        if (!this.stopData) {
            wrapper.innerHTML = '<span class="mmm-buscpt-error">Sem dados disponíveis.</span>';
            return wrapper;
        }

        // Título / Nome da Paragem
        const header = document.createElement("div");
        header.className = "mmm-buscpt-header";
        
        const stopName = this.stopData.stop_name || "Paragem";
        const stopId = this.stopData.stop_id || this.config.stopId;
        header.innerHTML = `<i class="fa fa-bus mmm-buscpt-bus-icon"></i> ${stopName} <span class="mmm-buscpt-stop-id">(${stopId})</span>`;
        wrapper.appendChild(header);

        // Tabela de Chegadas
        const table = document.createElement("table");
        table.className = "mmm-buscpt-table small";

        const arrivals = this.stopData.arrivals || [];
        if (arrivals.length === 0) {
            const noArrivalsRow = document.createElement("tr");
            noArrivalsRow.innerHTML = '<td colspan="3" class="mmm-buscpt-empty">Sem autocarros previstos de momento.</td>';
            table.appendChild(noArrivalsRow);
            wrapper.appendChild(table);
            return wrapper;
        }

        // Limitar número de resultados exibidos
        const displayLimit = Math.min(arrivals.length, this.config.maxResults);

        for (let i = 0; i < displayLimit; i++) {
            const arrival = arrivals[i];
            const tr = document.createElement("tr");
            tr.className = "mmm-buscpt-row";

            // 1. Número da Carreira
            const tdRoute = document.createElement("td");
            tdRoute.className = "mmm-buscpt-route-cell";
            
            const badge = document.createElement("span");
            badge.className = "mmm-buscpt-route-badge";
            badge.innerText = arrival.route_short_name || "??";
            
            if (this.config.showColors) {
                // Definir cor personalizada se fornecida pela API ou usar padrão STCP (azul-escuro)
                const routeColor = arrival.route_color || "#0A2540";
                const textColor = arrival.route_text_color || "#FFFFFF";
                badge.style.backgroundColor = routeColor;
                badge.style.color = textColor;
            }
            tdRoute.appendChild(badge);
            tr.appendChild(tdRoute);

            // 2. Destino
            const tdDest = document.createElement("td");
            tdDest.className = "mmm-buscpt-dest-cell align-left";
            
            // Limpar caracteres estranhos como asteriscos iniciais (comuns na API da STCP para sinalizar variantes)
            let headsign = arrival.trip_headsign || "STCP";
            if (headsign.startsWith("*")) {
                headsign = headsign.substring(1);
            }
            tdDest.innerText = headsign;
            tr.appendChild(tdDest);

            // 3. Tempo Restante
            const tdTime = document.createElement("td");
            tdTime.className = "mmm-buscpt-time-cell align-right";

            const minutes = arrival.arrival_minutes;
            if (minutes === 0 || minutes === null) {
                tdTime.innerHTML = '<span class="mmm-buscpt-pulse-now">A chegar</span>';
            } else if (minutes === 1) {
                tdTime.innerHTML = '<span class="mmm-buscpt-pulse-now">1 min</span>';
            } else {
                tdTime.innerHTML = `<span class="mmm-buscpt-time-val">${minutes} min</span>`;
            }
            tr.appendChild(tdTime);

            table.appendChild(tr);
        }

        wrapper.appendChild(table);
        return wrapper;
    }
});
