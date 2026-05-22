/**
 * MMM-BolsaTicker — node_helper.js
 * Obtém cotações em tempo real via Yahoo Finance API (sem API key).
 */
const NodeHelper = require("node_helper");
const https = require("https");

module.exports = NodeHelper.create({
    start: function () {
        console.log("MMM-BolsaTicker: node_helper iniciado.");
    },

    socketNotificationReceived: function (notification, payload) {
        if (notification === "BOLSA_FETCH") {
            this._fetchQuotes(payload.symbols);
        }
    },

    _fetchQuotes: function (symbols) {
        if (!symbols || symbols.length === 0) {
            this.sendSocketNotification("BOLSA_ERROR", { error: "Nenhum símbolo configurado." });
            return;
        }

        // Yahoo Finance v8 — endpoint público sem autenticação
        const symbolsParam = encodeURIComponent(symbols.join(","));
        const path = `/v8/finance/spark?symbols=${symbolsParam}&range=1d&interval=1d`;

        // Usar o endpoint quote para dados mais ricos
        const quotePath = `/v7/finance/quote?symbols=${symbolsParam}&fields=shortName,regularMarketPrice,regularMarketChange,regularMarketChangePercent,currency`;

        const options = {
            hostname: "query1.finance.yahoo.com",
            path: quotePath,
            method: "GET",
            headers: {
                "User-Agent": "Mozilla/5.0 (compatible; MagicMirror/1.0)",
                "Accept": "application/json",
            },
        };

        const req = https.request(options, (res) => {
            let data = "";
            res.on("data", (chunk) => (data += chunk));
            res.on("end", () => {
                try {
                    const json = JSON.parse(data);
                    const result = json?.quoteResponse?.result;

                    if (!result || result.length === 0) {
                        this.sendSocketNotification("BOLSA_ERROR", {
                            error: "Sem dados da Yahoo Finance. Verifica os símbolos.",
                        });
                        return;
                    }

                    const quotes = result.map((q) => ({
                        symbol: q.symbol,
                        shortName: q.shortName || q.longName || q.symbol,
                        price: q.regularMarketPrice,
                        change: q.regularMarketChange,
                        changePercent: q.regularMarketChangePercent,
                        currency: q.currency || "USD",
                        marketState: q.marketState, // REGULAR | PRE | POST | CLOSED
                    }));

                    this.sendSocketNotification("BOLSA_QUOTES", { quotes });
                    console.log("MMM-BolsaTicker: " + quotes.length + " cotação(ões) recebida(s).");
                } catch (e) {
                    this.sendSocketNotification("BOLSA_ERROR", {
                        error: "Erro ao parsear resposta: " + e.message,
                    });
                }
            });
        });

        req.on("error", (e) => {
            this.sendSocketNotification("BOLSA_ERROR", { error: "Erro de rede: " + e.message });
        });

        req.setTimeout(10000, () => {
            req.destroy();
            this.sendSocketNotification("BOLSA_ERROR", { error: "Timeout ao ligar à Yahoo Finance." });
        });

        req.end();
    },
});
