/**
 * MMM-BusCPT — node_helper.js
 * Puxa tempos de chegada em tempo real diretamente da API oficial da STCP.
 */
const NodeHelper = require("node_helper");
const https = require("https");

module.exports = NodeHelper.create({
    start: function () {
        console.log("MMM-BusCPT: node_helper iniciado.");
    },

    socketNotificationReceived: function (notification, payload) {
        if (notification === "BUSCPT_FETCH") {
            this._fetchArrivals(payload.stopId);
        }
    },

    _fetchArrivals: function (stopId) {
        if (!stopId) {
            this.sendSocketNotification("BUSCPT_ERROR", { error: "Nenhuma paragem configurada." });
            return;
        }

        const url = `https://stcp.pt/api/stops/${stopId}/realtime`;

        const options = {
            headers: {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                "Accept": "application/json"
            },
            timeout: 10000
        };

        const req = https.get(url, options, (res) => {
            let data = "";
            res.on("data", (chunk) => (data += chunk));
            res.on("end", () => {
                try {
                    if (res.statusCode !== 200) {
                        this.sendSocketNotification("BUSCPT_ERROR", {
                            error: `Erro de rede: Código de estado ${res.statusCode}`
                        });
                        return;
                    }

                    const json = JSON.parse(data);
                    
                    // Validar se há dados válidos de paragem ou chegadas
                    if (!json || (!json.arrivals && !json.stop_name)) {
                        this.sendSocketNotification("BUSCPT_ERROR", {
                            error: "Formato de dados inesperado da STCP."
                        });
                        return;
                    }

                    this.sendSocketNotification("BUSCPT_DATA", json);
                } catch (e) {
                    this.sendSocketNotification("BUSCPT_ERROR", {
                        error: "Erro ao interpretar resposta: " + e.message
                    });
                }
            });
        });

        req.on("error", (e) => {
            this.sendSocketNotification("BUSCPT_ERROR", { error: "Erro de ligação: " + e.message });
        });

        req.on("timeout", () => {
            req.destroy();
            this.sendSocketNotification("BUSCPT_ERROR", { error: "Timeout ao contactar a API da STCP." });
        });
    }
});
