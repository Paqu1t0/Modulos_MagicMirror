const NodeHelper = require("node_helper");
const { spawn } = require("child_process");
const path = require("path");

module.exports = NodeHelper.create({
    start: function() {
        console.log("A iniciar node_helper para: " + this.name);
    },

    socketNotificationReceived: function(notification, payload) {
        if (notification === "START_SENSOR") {
            this.startPythonScript();
        }
    },

    startPythonScript: function() {
        // Corre o ficheiro sensor.py que está na mesma pasta
        const pythonProcess = spawn("python3", [path.join(__dirname, "sensor.py")]);

        // Apanha o texto que o Python imprime
        pythonProcess.stdout.on("data", (data) => {
            const linhas = data.toString().trim().split('\n');
            for (let linha of linhas) {
                try {
                    const result = JSON.parse(linha); // Converte para objeto
                    this.sendSocketNotification("SENSOR_DATA", result); // Envia para o espelho
                } catch (e) {
                    // Ignora se o Python imprimir algum erro do sistema que não seja JSON
                }
            }
        });

        pythonProcess.stderr.on("data", (data) => {
            console.error("Erro no sensor.py:", data.toString());
        });
    }
});