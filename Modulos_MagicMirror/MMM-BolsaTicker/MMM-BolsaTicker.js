/**
 * MMM-BolsaTicker
 * Módulo criado pela nossa equipa.
 * Mostra cotações em tempo real de ações, índices, crypto e moedas no espelho.
 *
 * Usa a Yahoo Finance API (gratuita, sem necessidade de API key).
 *
 * Configuração no config.js do MagicMirror:
 * {
 *   module: "MMM-BolsaTicker",
 *   position: "bottom_bar",
 *   config: {
 *     // Símbolos a mostrar (Yahoo Finance format)
 *     symbols: [
 *       "^GSPC",     // S&P 500
 *       "^IXIC",     // NASDAQ
 *       "^GDAXI",    // DAX (Alemanha)
 *       "PSI20.LS",  // PSI-20 (Portugal)
 *       "AAPL",      // Apple
 *       "TSLA",      // Tesla
 *       "NVDA",      // Nvidia
 *       "BTC-USD",   // Bitcoin
 *       "ETH-USD",   // Ethereum
 *       "EURUSD=X",  // EUR/USD
 *     ],
 *     displayMode: "ticker",  // "ticker" (scrolling) | "grid" (cards)
 *     updateInterval: 60000,  // Atualizar a cada 60 segundos
 *     tickerSpeed: 60,        // Velocidade do ticker em segundos por ciclo
 *     showChange: true,       // Mostrar variação (+ / -)
 *     showPercent: true,      // Mostrar percentagem
 *     showCurrency: true,     // Mostrar moeda (USD, EUR, ...)
 *     decimalPlaces: 2,       // Casas decimais
 *     colorize: true,         // Verde/vermelho consoante subida/descida
 *   }
 * }
 */
Module.register("MMM-BolsaTicker", {
    defaults: {
        symbols: [
            "^GSPC",     // S&P 500
            "^IXIC",     // NASDAQ
            "^GDAXI",    // DAX
            "PSI20.LS",  // PSI-20
            "AAPL",      // Apple
            "TSLA",      // Tesla
            "NVDA",      // Nvidia
            "BTC-USD",   // Bitcoin
            "ETH-USD",   // Ethereum
            "EURUSD=X",  // EUR/USD
        ],
        displayMode: "ticker",
        updateInterval: 60000,
        tickerSpeed: 60,
        showChange: true,
        showPercent: true,
        showCurrency: true,
        decimalPlaces: 2,
        colorize: true,
    },

    // Nomes amigáveis para os símbolos mais comuns
    symbolLabels: {
        "^GSPC":    "S&P 500",
        "^IXIC":    "NASDAQ",
        "^DJI":     "Dow Jones",
        "^GDAXI":   "DAX",
        "^FTSE":    "FTSE 100",
        "^FCHI":    "CAC 40",
        "PSI20.LS": "PSI-20",
        "^IBEX":    "IBEX 35",
        "^N225":    "Nikkei",
        "BTC-USD":  "Bitcoin",
        "ETH-USD":  "Ethereum",
        "DOGE-USD": "Dogecoin",
        "EURUSD=X": "EUR/USD",
        "GBPUSD=X": "GBP/USD",
        "USDJPY=X": "USD/JPY",
    },

    start: function () {
        this.quotes = [];
        this.loaded = false;
        this.error = null;
        this.tickerPosition = 0;

        Log.info("MMM-BolsaTicker: A iniciar...");
        this._fetchQuotes();
    },

    getScripts: function () {
        return ["https://cdn.jsdelivr.net/npm/chart.js"];
    },

    getStyles: function () {
        return ["MMM-BolsaTicker.css"];
    },

    getDom: function () {
        const wrapper = document.createElement("div");
        wrapper.className = "mmm-bolsa-wrapper";

        if (!this.loaded) {
            wrapper.innerHTML = `<span class="mmm-bolsa-loading">📈 A carregar cotações...</span>`;
            return wrapper;
        }

        if (this.error) {
            wrapper.innerHTML = `<span class="mmm-bolsa-error">⚠️ ${this.error}</span>`;
            return wrapper;
        }

        if (this.quotes.length === 0) {
            wrapper.innerHTML = `<span class="mmm-bolsa-error">Sem dados disponíveis.</span>`;
            return wrapper;
        }

        return this._buildCharts(wrapper);
    },

    _buildCharts: function (wrapper) {
        wrapper.className += " mmm-bolsa-charts-mode";
        
        const cryptoCurrencies = this.quotes.filter(q => q.symbol.includes("USD") || q.symbol.includes("=X"));
        const stocks = this.quotes.filter(q => !q.symbol.includes("USD") && !q.symbol.includes("=X"));

        if (cryptoCurrencies.length > 0) {
            wrapper.appendChild(this._buildChartSection("Moedas & Crypto", "crypto"));
        }
        
        if (stocks.length > 0) {
            wrapper.appendChild(this._buildChartSection("Ações & Índices", "stocks"));
        }

        // Agendar desenho apenas após o DOM ser inserido no ecrã na primeira vez
        setTimeout(() => {
            this._updateChartsData();
        }, 800);

        return wrapper;
    },

    _buildChartSection: function (titleText, idPrefix) {
        const section = document.createElement("div");
        section.className = "mmm-bolsa-chart-section";

        const header = document.createElement("div");
        header.className = "mmm-bolsa-chart-header";
        
        const title = document.createElement("div");
        title.className = "mmm-bolsa-chart-title";
        title.innerText = titleText;
        header.appendChild(title);

        const legend = document.createElement("div");
        legend.id = `bolsa-legend-${idPrefix}`;
        legend.className = "mmm-bolsa-chart-legend-text";
        header.appendChild(legend);

        section.appendChild(header);

        const canvasContainer = document.createElement("div");
        canvasContainer.className = "mmm-bolsa-canvas-container";
        const canvas = document.createElement("canvas");
        canvas.id = `bolsa-chart-${idPrefix}`;
        canvasContainer.appendChild(canvas);
        
        section.appendChild(canvasContainer);
        return section;
    },

    _updateChartsData: function () {
        const cryptoCurrencies = this.quotes.filter(q => q.symbol.includes("USD") || q.symbol.includes("=X"));
        const stocks = this.quotes.filter(q => !q.symbol.includes("USD") && !q.symbol.includes("=X"));

        if (cryptoCurrencies.length > 0) this._drawChart("crypto", cryptoCurrencies);
        if (stocks.length > 0) this._drawChart("stocks", stocks);
    },

    _drawChart: function (idPrefix, quotes) {
        const canvas = document.getElementById(`bolsa-chart-${idPrefix}`);
        if (!canvas) return;

        const colors = [
            "#4ade80", // Verde
            "#38bdf8", // Azul Claro
            "#f472b6", // Rosa
            "#fbbf24", // Amarelo
            "#a78bfa", // Roxo
            "#f87171", // Vermelho
            "#ffffff", // Branco
            "#ff7f50", // Laranja/Coral
            "#00ffff"  // Ciano
        ];

        const legendDiv = document.getElementById(`bolsa-legend-${idPrefix}`);
        if (legendDiv) {
            legendDiv.innerHTML = "";
            quotes.forEach((q, index) => {
                const isUp = q.change >= 0;
                const changeColor = isUp ? "#4ade80" : "#f87171";
                const lineColor = colors[index % colors.length];
                const changeStr = q.changePercent !== undefined ? `${isUp ? "+" : ""}${q.changePercent.toFixed(2)}%` : "";
                
                const span = document.createElement("span");
                // Criar pequeno quadrado/círculo com a cor da linha correspondente
                span.innerHTML = `
                    <span style="display:inline-block; width:10px; height:10px; border-radius:50%; background-color:${lineColor}; margin-right:4px;"></span>
                    <span style="color: rgba(255,255,255,0.95); font-weight: bold; font-size:1.1em; margin-right:4px;">${this.symbolLabels[q.symbol] || q.shortName}</span>
                    <span style="color: ${changeColor};">${changeStr}</span>
                `;
                legendDiv.appendChild(span);
            });
        }

        const ctx = canvas.getContext("2d");
        if (!this.charts) this.charts = {};

        const datasets = [];
        let maxDataLength = 0;
        let globalLabels = [];

        quotes.forEach((q, index) => {
            if (!q.history || q.history.length === 0) return;
            
            let basePrice = q.history.find(p => p !== null);
            if (!basePrice) return;

            const data = q.history.map(p => {
                if (p === null) return null;
                return ((p - basePrice) / basePrice) * 100;
            });

            if (data.length > maxDataLength) {
                maxDataLength = data.length;
            }

            // Usamos os timestamps da primeira ação como as horas globais no eixo X
            if (globalLabels.length === 0 && q.timestamps && q.timestamps.length > 0) {
                globalLabels = q.timestamps.map(ts => {
                    const d = new Date(ts * 1000);
                    const day = d.getDate().toString().padStart(2, '0');
                    const month = (d.getMonth() + 1).toString().padStart(2, '0');
                    const hour = d.getHours().toString().padStart(2, '0');
                    const min = d.getMinutes().toString().padStart(2, '0');
                    // Retorna "Dia/Mês HH:MM"
                    return `${day}/${month} ${hour}:${min}`;
                });
            }

            datasets.push({
                label: this.symbolLabels[q.symbol] || q.shortName,
                data: data,
                borderColor: colors[index % colors.length],
                borderWidth: 2,
                pointRadius: 0,
                tension: 0.2, // curvas suaves
                fill: false,
                spanGaps: true, // Ignorar nulls
            });
        });

        if (datasets.length === 0) return;

        // Se por algum motivo as labels globais falharem, cria dummies para não quebrar
        if (globalLabels.length < maxDataLength) {
            const diff = maxDataLength - globalLabels.length;
            for (let i = 0; i < diff; i++) globalLabels.push("");
        }

        if (this.charts[idPrefix]) {
            this.charts[idPrefix].data.labels = globalLabels;
            this.charts[idPrefix].data.datasets = datasets;
            this.charts[idPrefix].update();
        } else {
            // @ts-ignore
            this.charts[idPrefix] = new Chart(ctx, {
                type: 'line',
                data: {
                    labels: globalLabels,
                    datasets: datasets
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: { display: false },
                        tooltip: { enabled: false }
                    },
                    scales: {
                        x: {
                            display: true,
                            ticks: { 
                                color: 'rgba(255,255,255,0.4)', 
                                maxTicksLimit: 5,
                                maxRotation: 45, // Diagonal
                                minRotation: 45
                            },
                            grid: { 
                                display: true, 
                                color: 'rgba(255,255,255,0.12)' // Linhas verticais a cinzento claro
                            }
                        },
                        y: {
                            display: true,
                            position: 'right',
                            ticks: { 
                                color: 'rgba(255,255,255,0.6)',
                                callback: function(value) { return value > 0 ? '+' + value.toFixed(1) + '%' : value.toFixed(1) + '%'; }
                            },
                            grid: { 
                                display: true,
                                color: 'rgba(255,255,255,0.12)' // Linhas horizontais a cinzento claro
                            }
                        }
                    },
                    animation: { duration: 400 }
                }
            });
        }
    },

    _formatPrice: function (price, currency) {
        if (price === null || price === undefined) return "—";
        const formatted = parseFloat(price).toLocaleString("pt-PT", {
            minimumFractionDigits: this.config.decimalPlaces,
            maximumFractionDigits: this.config.decimalPlaces,
        });
        if (!this.config.showCurrency || !currency) return formatted;
        const symbols = { "USD": "$", "EUR": "€", "GBP": "£", "JPY": "¥", "BTC": "₿" };
        const sym = symbols[currency] || currency + " ";
        return sym + formatted;
    },

    socketNotificationReceived: function (notification, payload) {
        if (notification === "BOLSA_QUOTES") {
            this.quotes = payload.quotes;
            this.loaded = true;
            this.error = null;
            
            if (!this.firstDrawCompleted) {
                this.firstDrawCompleted = true;
                this.updateDom(); // Cria a estrutura inicial
            } else {
                this._updateChartsData(); // Atualiza apenas os gráficos sem destruir a DOM
            }
        }
        if (notification === "BOLSA_ERROR") {
            this.error = payload.error;
            this.loaded = true;
            this.updateDom();
        }
    },

    _fetchQuotes: function () {
        this.sendSocketNotification("BOLSA_FETCH", {
            symbols: this.config.symbols,
        });
        if (this.fetchTimer) clearTimeout(this.fetchTimer);
        this.fetchTimer = setTimeout(() => this._fetchQuotes(), this.config.updateInterval);
    },

    suspend: function () {
        if (this.fetchTimer) clearTimeout(this.fetchTimer);
    },

    resume: function () {
        this._fetchQuotes();
    },
});
