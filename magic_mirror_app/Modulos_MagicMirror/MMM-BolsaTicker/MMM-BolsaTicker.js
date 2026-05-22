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

        if (this.config.displayMode === "ticker") {
            return this._buildTicker(wrapper);
        } else {
            return this._buildGrid(wrapper);
        }
    },

    _buildTicker: function (wrapper) {
        wrapper.className += " mmm-bolsa-ticker-mode";

        const track = document.createElement("div");
        track.className = "mmm-bolsa-ticker-track";
        // Duplicar para scroll infinito
        [...this.quotes, ...this.quotes].forEach((q) => {
            track.appendChild(this._buildTickerItem(q));
        });

        // Velocidade animação baseada no número de items
        const duration = this.config.tickerSpeed;
        track.style.animationDuration = duration + "s";

        wrapper.appendChild(track);
        return wrapper;
    },

    _buildGrid: function (wrapper) {
        wrapper.className += " mmm-bolsa-grid-mode";
        const grid = document.createElement("div");
        grid.className = "mmm-bolsa-grid";

        this.quotes.forEach((q) => {
            grid.appendChild(this._buildGridCard(q));
        });

        wrapper.appendChild(grid);
        return wrapper;
    },

    _buildTickerItem: function (q) {
        const item = document.createElement("span");
        item.className = "mmm-bolsa-ticker-item";

        const isUp = q.change >= 0;
        const changeClass = this.config.colorize
            ? (isUp ? "mmm-bolsa-up" : "mmm-bolsa-down")
            : "mmm-bolsa-neutral";
        const arrow = isUp ? "▲" : "▼";

        const label = this.symbolLabels[q.symbol] || q.shortName || q.symbol;
        const price = this._formatPrice(q.price, q.currency);
        const pct = q.changePercent !== undefined
            ? `${isUp ? "+" : ""}${q.changePercent.toFixed(2)}%`
            : "";

        item.innerHTML = `
            <span class="mmm-bolsa-label">${label}</span>
            <span class="mmm-bolsa-price">${price}</span>
            ${this.config.showPercent ? `<span class="${changeClass}"> ${arrow} ${pct}</span>` : ""}
            <span class="mmm-bolsa-sep">·</span>
        `;
        return item;
    },

    _buildGridCard: function (q) {
        const card = document.createElement("div");
        card.className = "mmm-bolsa-grid-card";

        const isUp = q.change >= 0;
        const changeClass = this.config.colorize
            ? (isUp ? "mmm-bolsa-up" : "mmm-bolsa-down")
            : "mmm-bolsa-neutral";
        const arrow = isUp ? "▲" : "▼";

        const label = this.symbolLabels[q.symbol] || q.shortName || q.symbol;
        const price = this._formatPrice(q.price, q.currency);
        const pct = q.changePercent !== undefined
            ? `${isUp ? "+" : ""}${q.changePercent.toFixed(2)}%`
            : "";
        const changeAbs = q.change !== undefined
            ? `${isUp ? "+" : ""}${q.change.toFixed(this.config.decimalPlaces)}`
            : "";

        card.innerHTML = `
            <div class="mmm-bolsa-card-label">${label}</div>
            <div class="mmm-bolsa-card-price">${price}</div>
            <div class="mmm-bolsa-card-change ${changeClass}">
                ${arrow} ${pct}
                ${this.config.showChange ? `<span class="mmm-bolsa-card-abs">(${changeAbs})</span>` : ""}
            </div>
        `;
        card.classList.add(isUp ? "mmm-bolsa-card-up" : "mmm-bolsa-card-down");
        return card;
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
            this.updateDom();
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
