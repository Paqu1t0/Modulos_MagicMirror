const NodeHelper = require("node_helper");
const { spawn } = require("child_process");
const path = require("path");

module.exports = NodeHelper.create({
    start: function() {
        console.log("A iniciar node_helper para: " + this.name);
    },

    socketNotificationReceived: function(notification, payload) {
        if (notification === "START_BUTTONS") {
            this.startPythonScript();
        }
    },

    startPythonScript: function() {
        const pythonProcess = spawn("python3", [path.join(__dirname, "botoes.py")]);

        pythonProcess.stdout.on("data", (data) => {
            const linhas = data.toString().trim().split('\n');
            for (let linha of linhas) {
                try {
                    const result = JSON.parse(linha);
                    this.sendSocketNotification("BOTAO_PRESSIONADO", result);
                } catch (e) {
                    // Ignora texto não-JSON
                }
            }
        });
    }
});