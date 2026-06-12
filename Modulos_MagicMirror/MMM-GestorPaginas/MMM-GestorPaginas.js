Module.register("MMM-GestorPaginas", {
    defaults: {
        totalPaginas: 3, // Podes alterar isto no config.js se quiseres mais páginas
        animacao: 500    // Meio segundo de transição suave
    },

    start: function() {
        this.paginaAtual = 1;
        this.sendSocketNotification("START_BUTTONS", null);
    },

    getStyles: function() {
        return ["font-awesome.css"];
    },

    // Apenas organiza os módulos quando o espelho acaba de arrancar a 100%
    notificationReceived: function(notification, payload, sender) {
        if (notification === "MODULE_DOM_CREATED" || notification === "ALL_MODULES_STARTED") {
            this.atualizarVisibilidadeModulos();
        }
        // Permite mudar de página via MMM-Remote-Control (app) sem precisar do node_helper
        if (notification === "BOTAO_PRESSIONADO") {
            const acao = this._parseAcao(payload);
            if (acao) {
                this.mudarPagina(acao);
            }
        }
    },

    // Desenha as bolinhas indicadoras no ecrã
    getDom: function() {
        var wrapper = document.createElement("div");
        wrapper.className = "small bright";
        
        let html = `<div style="display: flex; gap: 10px; justify-content: center; align-items: center;">`;
        for (let i = 1; i <= this.config.totalPaginas; i++) {
            if (i === this.paginaAtual) {
                // Bolinha cheia para a página atual
                html += `<span class="fa fa-circle" style="color: white; font-size: 1.2em;"></span>`;
            } else {
                // Bolinha vazia para as outras
                html += `<span class="fa fa-circle-o" style="color: gray;"></span>`;
            }
        }
        html += `</div><div style="font-size: 0.7em; color: gray; margin-top: 5px;">Página ${this.paginaAtual} de ${this.config.totalPaginas}</div>`;
        
        wrapper.innerHTML = html;
        return wrapper;
    },

    // Recebe o clique do Python
    socketNotificationReceived: function(notification, payload) {
        if (notification === "BOTAO_PRESSIONADO") {
            const acao = this._parseAcao(payload);
            if (acao) {
                this.mudarPagina(acao);
            }
        }
    },

    _parseAcao: function(payload) {
        if (!payload) return null;
        if (typeof payload === "string") {
            try {
                const parsed = JSON.parse(payload);
                payload = parsed;
            } catch (e) {
                return payload; // simples string tipo "proxima" ou "anterior"
            }
        }

        // Se o payload vier encapsulado num objecto com chave "payload" (comportamento de algumas APIs)
        if (typeof payload === "object" && payload.payload !== undefined) {
            payload = payload.payload;
        }

        let acao = null;
        if (typeof payload === "object") {
            // Se acao for "ir", preferimos "pagina" ou "page" se existirem
            if (payload.acao === "ir" && (payload.pagina !== undefined || payload.page !== undefined)) {
                acao = payload.pagina !== undefined ? payload.pagina : payload.page;
            } else {
                acao = payload.acao || payload.page || payload.pagina;
            }
        } else {
            acao = payload;
        }
        return acao;
    },

    mudarPagina: function(acao) {
        if (acao === "proxima") {
            this.paginaAtual++;
            if (this.paginaAtual > this.config.totalPaginas) this.paginaAtual = 1;
        } else if (acao === "anterior") {
            this.paginaAtual--;
            if (this.paginaAtual < 1) this.paginaAtual = this.config.totalPaginas;
        } else if (acao === "ir" || typeof acao === "number" || !isNaN(parseInt(acao))) {
            let num = parseInt(acao);
            if (!isNaN(num) && num >= 1 && num <= this.config.totalPaginas) {
                this.paginaAtual = num;
            }
        }
        this.updateDom(); // Atualiza as bolinhas no ecrã
        this.atualizarVisibilidadeModulos(); // Esconde/mostra os módulos
    },

    // A magia de esconder e mostrar módulos
    // A magia de esconder, mostrar e mover os módulos entre regiões dinamicamente
    atualizarVisibilidadeModulos: function() {
        const self = this;
        const modules = MM.getModules();
        
        modules.enumerate(function(module) {
            const classes = (module.data && typeof module.data.classes === "string") ? module.data.classes : "";

            // Módulos que devem estar SEMPRE visíveis (como o próprio gestor e o teu sensor)
            if (module.name === "MMM-GestorPaginas" || classes.includes("sempre_visivel")) {
                module.show(self.config.animacao, {lockString: self.identifier});
                return;
            }

            // Se o módulo tem a tag da página atual, mostra-o!
            if (classes.includes("pagina_" + self.paginaAtual)) {
                // 1. Mover dinamicamente o módulo para a sua posição nesta página se estiver configurado
                const posRegex = new RegExp("pagina_" + self.paginaAtual + "_pos_([a-z_]+)");
                const posMatch = classes.match(posRegex);
                let targetPos = null;
                
                if (posMatch) {
                    targetPos = posMatch[1];
                } else if (module.data && module.data.position) {
                    targetPos = module.data.position; // Fallback para posição original
                }

                if (targetPos) {
                    const regionSelector = ".region." + targetPos.replace(/_/g, ".") + " .container";
                    const container = document.querySelector(regionSelector);
                    const wrapper = document.getElementById(module.identifier);
                    if (container && wrapper && wrapper.parentElement !== container) {
                        container.appendChild(wrapper);
                    }
                }

                // 2. Mostrar o módulo
                module.show(self.config.animacao, {lockString: self.identifier});
            } else {
                // Se não tem, esconde-o!
                module.hide(self.config.animacao, {lockString: self.identifier});
            }
        });
    }
});