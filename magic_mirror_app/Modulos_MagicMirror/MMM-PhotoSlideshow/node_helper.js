/**
 * MMM-PhotoSlideshow — node_helper.js (v2 — corrigido)
 *
 * Lê as fotos da pasta configurada e envia-as como data URIs (base64)
 * diretamente ao módulo front-end. Esta abordagem não depende de
 * servir ficheiros estáticos, funcionando em qualquer instalação do
 * MagicMirror sem configuração adicional.
 */
const NodeHelper = require("node_helper");
const fs = require("fs");
const path = require("path");

module.exports = NodeHelper.create({
    start: function () {
        console.log("MMM-PhotoSlideshow: node_helper v2 iniciado.");
        this.photoDir = null;
        this.lastFilesStr = null;
        this.watcher = null;
    },

    socketNotificationReceived: function (notification, payload) {
        if (notification === "GET_PHOTOS") {
            // Ignorar a pasta do payload porque utilizadores antigos podem ter caminhos errados no config.js
            this.photoDir = path.resolve(__dirname, "public/fotos");
            this._loadPhotos();
            
            // Iniciar verificação automática a cada 10 segundos
            if (!this.watcher) {
                this.watcher = setInterval(() => {
                    this._loadPhotos();
                }, 10000);
            }
        }
    },

    _loadPhotos: function () {
        if (!this.photoDir) return;
        const photoDir = this.photoDir;

        const SUPPORTED = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"];
        const MIME_MAP = {
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
            ".png": "image/png",
            ".gif": "image/gif",
            ".webp": "image/webp",
            ".bmp": "image/bmp",
        };

        try {
            if (!fs.existsSync(photoDir)) {
                try {
                    fs.mkdirSync(photoDir, { recursive: true });
                    console.log("MMM-PhotoSlideshow: Pasta criada automaticamente em " + photoDir);
                } catch (e) {
                    if (this.lastFilesStr !== "ERROR_DIR") {
                        this.lastFilesStr = "ERROR_DIR";
                        this.sendSocketNotification("PHOTOS_ERROR", {
                            error: "Não foi possível criar a pasta: " + photoDir,
                        });
                    }
                    return;
                }
            }

            const files = fs.readdirSync(photoDir).filter((f) => {
                const ext = path.extname(f).toLowerCase();
                return SUPPORTED.includes(ext);
            });

            const currentFilesStr = files.sort().join(",");
            
            // Se a lista de ficheiros for igual à última vez, não fazemos reload para poupar o CPU do Raspberry Pi
            if (this.lastFilesStr === currentFilesStr) {
                return;
            }
            this.lastFilesStr = currentFilesStr;

            if (files.length === 0) {
                this.sendSocketNotification("PHOTOS_ERROR", {
                    error: "Nenhuma foto encontrada em: " + photoDir,
                });
                return;
            }

            // Limitar a 15 fotos e embaralhar aleatoriamente
            const shuffled = files.sort(() => Math.random() - 0.5).slice(0, 15);

            const photos = [];
            for (const filename of shuffled) {
                photos.push({
                    name: path.basename(filename, path.extname(filename)),
                    // Enviar apenas o caminho relativo para o browser
                    // O MagicMirror serve a pasta modules nativamente.
                    url: `modules/MMM-PhotoSlideshow/public/fotos/${filename}?t=${Date.now()}`,
                });
            }

            this.sendSocketNotification("PHOTOS_LIST", { photos });
            console.log("MMM-PhotoSlideshow: " + photos.length + " foto(s) carregada(s) de " + photoDir);
        } catch (err) {
            if (this.lastFilesStr !== "ERROR_GENERAL") {
                this.lastFilesStr = "ERROR_GENERAL";
                this.sendSocketNotification("PHOTOS_ERROR", { error: err.message });
            }
        }
    },
});
