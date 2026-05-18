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
        if (notification === "MODULE_DOM_CREATED") {
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
    atualizarVisibilidadeModulos: function() {
        const self = this;
        const modules = MM.getModules();
        
        modules.enumerate(function(module) {
            // Módulos que devem estar SEMPRE visíveis (como o próprio gestor e o teu sensor)
            if (module.name === "MMM-GestorPaginas" || module.name === "MMM-Ultrasonic" || module.data.classes.includes("sempre_visivel")) {
                module.show(self.config.animacao, {lockString: self.identifier});
                return;
            }

            // Se o módulo tem a tag da página atual, mostra-o!
            if (module.data.classes.includes("pagina_" + self.paginaAtual)) {
                module.show(self.config.animacao, {lockString: self.identifier});
            } else {
                // Se não tem, esconde-o!
                module.hide(self.config.animacao, {lockString: self.identifier});
            }
        });
    }
});