/**
 * MMM-GasPrices
 * Módulo para MagicMirror² criado pela nossa equipa.
 * Puxa os preços oficiais da DGEG em tempo real e exibe os postos mais baratos da tua zona (Gasolina/Gasóleo/GPL).
 */
Module.register("MMM-GasPrices", {
    defaults: {
        districtId: "13",            // Porto por defeito
        updateInterval: 3600000,     // Atualizar dados DGEG a cada 1 hora
        rotateInterval: 10000,       // Rodar entre combustíveis a cada 10 segundos
        showTypes: ["gasolina", "gasoleo", "gpl"], // Quais combustíveis exibir
        fuels: {
            gasolina: "3201",        // Gasolina simples 95
            gasoleo: "2101",         // Gasóleo simples
            gpl: "1120"              // GPL Auto
        }
    },

    start: function () {
        Log.info("MMM-GasPrices: A iniciar...");
        this.pricesData = null;
        this.loaded = false;
        this.error = null;
        this.activeFuelIndex = 0;

        this.getData();

        // Ciclo para ir buscar novos dados
        var self = this;
        setInterval(function () {
            self.getData();
        }, this.config.updateInterval);

        // Ciclo dinâmico para rodar entre os combustíveis ativos
        setInterval(function () {
            if (self.loaded && !self.error && self.pricesData) {
                const activeFuels = self.config.showTypes.filter(f => self.pricesData[f] && self.pricesData[f].length > 0);
                if (activeFuels.length > 1) {
                    self.activeFuelIndex = (self.activeFuelIndex + 1) % activeFuels.length;
                    self.updateDom(400); // transição suave de 400ms
                }
            }
        }, this.config.rotateInterval);
    },

    getStyles: function () {
        return ["MMM-GasPrices.css"];
    },

    getData: function () {
        this.sendSocketNotification("GASPRICES_FETCH", {
            districtId: this.config.districtId,
            fuels: this.config.fuels
        });
    },

    socketNotificationReceived: function (notification, payload) {
        if (notification === "GASPRICES_DATA") {
            this.pricesData = payload;
            this.loaded = true;
            this.error = null;
            this.updateDom();
        } else if (notification === "GASPRICES_ERROR") {
            this.error = payload.error;
            this.loaded = true;
            this.updateDom();
        }
    },

    getDom: function () {
        const wrapper = document.createElement("div");
        wrapper.className = "mmm-gasprices-wrapper";

        if (!this.loaded) {
            wrapper.innerHTML = '<span class="mmm-gasprices-loading"><i class="fa fa-spinner fa-pulse"></i> ⛽ A carregar preços DGEG...</span>';
            return wrapper;
        }

        if (this.error) {
            wrapper.innerHTML = `<span class="mmm-gasprices-error">⚠️ ${this.error}</span>`;
            return wrapper;
        }

        if (!this.pricesData) {
            wrapper.innerHTML = '<span class="mmm-gasprices-error">Sem dados disponíveis de momento.</span>';
            return wrapper;
        }

        // Descobrir quais os combustíveis configurados e ativos
        const activeFuels = this.config.showTypes.filter(f => this.pricesData[f] && this.pricesData[f].length > 0);

        if (activeFuels.length === 0) {
            wrapper.innerHTML = '<span class="mmm-gasprices-empty">Nenhum combustível ativo com dados.</span>';
            return wrapper;
        }

        // Proteger index ativo se o array mudar
        if (this.activeFuelIndex >= activeFuels.length) {
            this.activeFuelIndex = 0;
        }

        const currentFuelKey = activeFuels[this.activeFuelIndex];
        const currentList = this.pricesData[currentFuelKey];

        // Header do Módulo
        const header = document.createElement("div");
        header.className = "mmm-gasprices-header";
        
        // Formatar título amigável de acordo com o combustível
        let fuelTitle = "Combustíveis";
        let fuelClass = "gas-brand-generic";
        if (currentFuelKey === "gasolina") {
            fuelTitle = "Gasolina 95 Simples";
            fuelClass = "gas-brand-gasolina";
        } else if (currentFuelKey === "gasoleo") {
            fuelTitle = "Gasóleo Simples";
            fuelClass = "gas-brand-gasoleo";
        } else if (currentFuelKey === "gpl") {
            fuelTitle = "GPL Automóvel";
            fuelClass = "gas-brand-gpl";
        }

        header.innerHTML = `<i class="fa fa-filter mmm-gasprices-icon ${fuelClass}"></i> ${fuelTitle}`;
        wrapper.appendChild(header);

        // Subtítulo do Distrito
        const sub = document.createElement("div");
        sub.className = "mmm-gasprices-sub";
        sub.innerText = "Mais Baratos do Distrito";
        wrapper.appendChild(sub);

        // Tabela de Preços
        const table = document.createElement("table");
        table.className = "mmm-gasprices-table small";

        currentList.forEach((station, index) => {
            const tr = document.createElement("tr");
            tr.className = "mmm-gasprices-row";
            if (index === 0) tr.className += " mmm-gasprices-row-cheapest"; // Destacar o mais barato

            // 1. Posição / Medalha
            const tdPos = document.createElement("td");
            tdPos.className = "mmm-gasprices-pos-cell";
            tdPos.innerHTML = index === 0 ? "🥇" : `<span>${index + 1}</span>`;
            tr.appendChild(tdPos);

            // 2. Detalhes do Posto (Nome + Concelho)
            const tdInfo = document.createElement("td");
            tdInfo.className = "mmm-gasprices-info-cell align-left";
            
            const stationName = document.createElement("div");
            stationName.className = "mmm-gasprices-station-name";
            stationName.innerText = station.nome;
            
            const stationLoc = document.createElement("div");
            stationLoc.className = "mmm-gasprices-station-loc";
            stationLoc.innerText = `${station.municipio}`;

            tdInfo.appendChild(stationName);
            tdInfo.appendChild(stationLoc);
            tr.appendChild(tdInfo);

            // 3. Preço por litro
            const tdPrice = document.createElement("td");
            tdPrice.className = "mmm-gasprices-price-cell align-right";
            
            const priceVal = document.createElement("span");
            priceVal.className = `mmm-gasprices-price-badge ${fuelClass}-badge`;
            priceVal.innerText = station.precoStr;

            tdPrice.appendChild(priceVal);
            tr.appendChild(tdPrice);

            table.appendChild(tr);
        });

        wrapper.appendChild(table);

        // Indicador de Progresso / Carrossel (Pequenos pontinhos na parte inferior)
        if (activeFuels.length > 1) {
            const dotsContainer = document.createElement("div");
            dotsContainer.className = "mmm-gasprices-dots";
            for (let i = 0; i < activeFuels.length; i++) {
                const dot = document.createElement("span");
                dot.className = "mmm-gasprices-dot" + (i === this.activeFuelIndex ? " active" : "");
                dotsContainer.appendChild(dot);
            }
            wrapper.appendChild(dotsContainer);
        }

        return wrapper;
    }
});
