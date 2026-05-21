const NodeHelper = require("node_helper");
const { spawn } = require("child_process");
const path = require("path");

module.exports = NodeHelper.create({
    start: function() {
        console.log("[MMM-Ultrasonic] node_helper iniciado.");
        this.pythonProcess = null;
        this.restarting = false;
    },

    socketNotificationReceived: function(notification, payload) {
        if (notification === "START_SENSOR") {
            // Evita arrancar múltiplas instâncias
            if (!this.pythonProcess) {
                this.startPythonScript();
            }
        }
        // Permite reiniciar o sensor a pedido da app (após atualizar config)
        if (notification === "RESTART_SENSOR") {
            this.restartPythonScript();
        }
    },

    startPythonScript: function() {
        this.restarting = false;
        console.log("[MMM-Ultrasonic] A iniciar sensor.py...");

        const pythonProcess = spawn("python3", [path.join(__dirname, "sensor.py")]);
        this.pythonProcess = pythonProcess;

        // Apanha o texto que o Python imprime
        pythonProcess.stdout.on("data", (data) => {
            const linhas = data.toString().trim().split('\n');
            for (let linha of linhas) {
                try {
                    const result = JSON.parse(linha);
                    this.sendSocketNotification("SENSOR_DATA", result);
                } catch (e) {
                    // Ignora linhas que não sejam JSON
                }
            }
        });

        pythonProcess.stderr.on("data", (data) => {
            // stderr do sensor.py (mensagens de debug e avisos de config reload)
            console.log("[MMM-Ultrasonic] sensor.py:", data.toString().trim());
        });

        // AUTO-RESTART: quando o sensor.py termina (seja por crash ou pkill),
        // reinicia automaticamente após 2 segundos para retomar a leitura.
        pythonProcess.on("close", (code) => {
            this.pythonProcess = null;
            if (!this.restarting) {
                console.log(`[MMM-Ultrasonic] sensor.py terminou (código: ${code}). A reiniciar em 2s...`);
                this.sendSocketNotification("SENSOR_DATA", {
                    distancia: 0,
                    estado: "A recarregar configuração...",
                    limite: 0,
                    tempo: 0
                });
                setTimeout(() => {
                    this.startPythonScript();
                }, 2000);
            }
        });
    },

    restartPythonScript: function() {
        this.restarting = true;
        if (this.pythonProcess) {
            console.log("[MMM-Ultrasonic] A reiniciar sensor.py (pedido da app)...");
            this.pythonProcess.kill("SIGTERM");
            this.pythonProcess = null;
        }
        // Reinicia após 1 segundo
        setTimeout(() => {
            this.startPythonScript();
        }, 1000);
    }
});