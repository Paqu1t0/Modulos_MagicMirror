Module.register("MMM-Ultrasonic", {
    defaults: {},

    start: function() {
        this.distancia = "...";
        this.estado = "A iniciar sensor...";
        // Pede ao node_helper para arrancar o Python
        this.sendSocketNotification("START_SENSOR", null);
    },

    // Carrega ícones
    getStyles: function() {
        return ["font-awesome.css"];
    },

    getDom: function() {
        var wrapper = document.createElement("div");
        wrapper.className = "small bright"; // Letra branca e brilhante
        
        // Lógica para mudar o ícone conforme o estado
        let icon = "fa-eye"; // Ícone normal
        if (this.estado.includes("Desliga em")) icon = "fa-clock-o"; // Ícone contagem
        if (this.estado.includes("Poupança")) icon = "fa-eye-slash"; // Ícone ecrã desligado

        // HTML que vai para o ecrã
        wrapper.innerHTML = `
            <div style="text-align: center; padding: 10px; border-radius: 8px; background: rgba(255,255,255,0.1);">
                <div style="font-size: 1.2em; margin-bottom: 5px;">
                    <span class="fa ${icon}"></span> <b>Sensor de Presença</b>
                </div>
                <div>Distância: ${this.distancia} cm</div>
                <div style="font-size: 0.8em; color: #aaaaaa; margin-top: 5px;">${this.estado}</div>
            </div>
        `;
        
        return wrapper;
    },

    socketNotificationReceived: function(notification, payload) {
        if (notification === "SENSOR_DATA") {
            this.distancia = payload.distancia;
            this.estado = payload.estado;
            this.updateDom(); // Pede ao MagicMirror para desenhar os novos dados
        }
    }
});