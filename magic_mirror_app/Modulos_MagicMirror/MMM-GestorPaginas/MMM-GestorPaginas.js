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
            if (payload.acao === "proxima") {
                this.paginaAtual++;
                if (this.paginaAtual > this.config.totalPaginas) this.paginaAtual = 1;
            } else if (payload.acao === "anterior") {
                this.paginaAtual--;
                if (this.paginaAtual < 1) this.paginaAtual = this.config.totalPaginas;
            }
            
            this.updateDom(); // Atualiza as bolinhas no ecrã
            this.atualizarVisibilidadeModulos(); // Esconde as coisas da página velha e mostra da nova
        }
    },

    // A magia de esconder e mostrar módulos
    // A magia de esconder, mostrar e mover os módulos entre regiões dinamicamente
    atualizarVisibilidadeModulos: function() {
        const self = this;
        const modules = MM.getModules();
        
        modules.enumerate(function(module) {
            const classes = (module.data && typeof module.data.classes === "string") ? module.data.classes : "";

            // Módulos que devem estar SEMPRE visíveis (como o próprio gestor e o teu sensor)
            if (module.name === "MMM-GestorPaginas" || module.name === "MMM-Ultrasonic" || classes.includes("sempre_visivel")) {
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