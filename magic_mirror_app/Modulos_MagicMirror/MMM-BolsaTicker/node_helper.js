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

        let parsedSymbols = symbols;
        if (typeof symbols === "string") {
            // Caso venha como string tipo "[AAPL, MSFT]" ou "AAPL, MSFT"
            parsedSymbols = symbols.replace(/[\[\]'"]/g, '').split(',');
        }

        if (!Array.isArray(parsedSymbols)) {
            parsedSymbols = [parsedSymbols];
        }

        // Use a Set to remove any duplicate symbols the user might have accidentally entered
        const cleanSymbols = [...new Set(parsedSymbols.map(s => s.trim().toUpperCase()).filter(s => s))];
        if (cleanSymbols.length === 0) {
            this.sendSocketNotification("BOLSA_ERROR", { error: "Formato de símbolos inválido." });
            return;
        }

        // Yahoo Finance v8 — endpoint público sem autenticação
        const symbolsParam = encodeURIComponent(cleanSymbols.join(","));
        // Usar range=5d para garantir que temos sempre dados históricos suficientes para
        // desenhar a linha do gráfico, mesmo que o mercado tenha acabado de abrir ou seja fim de semana!
        const path = `/v8/finance/spark?symbols=${symbolsParam}&range=5d&interval=15m`;

        const options = {
            hostname: "query1.finance.yahoo.com",
            path: path,
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
                    const quotes = [];
                    
                    for (const sym of cleanSymbols) {
                        const q = json[sym];
                        if (q && q.close && q.close.length > 0) {
                            let currentPrice = null;
                            for (let i = q.close.length - 1; i >= 0; i--) {
                                if (q.close[i] !== null) {
                                    currentPrice = q.close[i];
                                    break;
                                }
                            }
                            
                            if (currentPrice !== null) {
                                const prevClose = q.chartPreviousClose || q.previousClose || currentPrice;
                                const change = currentPrice - prevClose;
                                const changePercent = (change / prevClose) * 100;
                                
                                quotes.push({
                                    symbol: q.symbol || sym,
                                    shortName: q.symbol || sym,
                                    price: currentPrice,
                                    change: change,
                                    changePercent: changePercent,
                                    currency: "USD",
                                    marketState: "REGULAR",
                                    history: q.close || [], // Array de preços do dia
                                    timestamps: q.timestamp || [], // Array de tempo
                                });
                            }
                        } else {
                            console.log("MMM-BolsaTicker: Símbolo não encontrado ou sem dados: " + sym);
                        }
                    }

                    if (quotes.length === 0) {
                        this.sendSocketNotification("BOLSA_ERROR", {
                            error: "Sem dados da Yahoo Finance. Verifica os símbolos ou a ligação.",
                        });
                        console.error("MMM-BolsaTicker Resposta Yahoo:", data);
                        return;
                    }

                    this.sendSocketNotification("BOLSA_QUOTES", { quotes });
                    console.log("MMM-BolsaTicker: " + quotes.length + " cotação(ões) recebida(s).");
                } catch (e) {
                    this.sendSocketNotification("BOLSA_ERROR", {
                        error: "Erro ao parsear resposta da Bolsa: " + e.message,
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
