const NodeHelper = require("node_helper");
const { spawn } = require("child_process");
const path = require("path");
const http = require("http");

module.exports = NodeHelper.create({
    start: function() {
        console.log("A iniciar node_helper para: " + this.name);
        this._startHttpServer();
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
    },

    // ── Servidor HTTP para receber comandos da app ──────────────────────────────
    _startHttpServer: function() {
        const self = this;
        const PORT = 8765;

        const server = http.createServer((req, res) => {
            // CORS para permitir requests da app Flutter
            res.setHeader("Access-Control-Allow-Origin", "*");
            res.setHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
            res.setHeader("Access-Control-Allow-Headers", "Content-Type");

            if (req.method === "OPTIONS") {
                res.writeHead(204);
                res.end();
                return;
            }

            if (req.method === "POST" && req.url === "/pagina") {
                let body = "";
                req.on("data", chunk => body += chunk);
                req.on("end", () => {
                    try {
                        const data = JSON.parse(body);
                        const acao = data.acao;
                        const isNumber = !isNaN(parseInt(acao));
                        if (acao === "proxima" || acao === "anterior" || acao === "ir" || isNumber) {
                            self.sendSocketNotification("BOTAO_PRESSIONADO", data);
                            res.writeHead(200, { "Content-Type": "application/json" });
                            res.end(JSON.stringify({ ok: true, acao: acao }));
                        } else {
                            res.writeHead(400);
                            res.end(JSON.stringify({ error: "acao inválida. Usa proxima, anterior, ir ou um número de página." }));
                        }
                    } catch (e) {
                        res.writeHead(400);
                        res.end(JSON.stringify({ error: "JSON inválido" }));
                    }
                });
            } else if (req.method === "GET" && req.url === "/pagina/status") {
                // Permite saber qual a página atual (o módulo comunica via broadcast)
                res.writeHead(200, { "Content-Type": "application/json" });
                res.end(JSON.stringify({ ok: true, porta: PORT }));
            } else {
                res.writeHead(404);
                res.end(JSON.stringify({ error: "Rota não encontrada" }));
            }
        });

        server.listen(PORT, () => {
            console.log("MMM-GestorPaginas: HTTP server a ouvir na porta " + PORT);
        });

        server.on("error", (err) => {
            console.error("MMM-GestorPaginas: Erro no servidor HTTP:", err.message);
        });
    }
});