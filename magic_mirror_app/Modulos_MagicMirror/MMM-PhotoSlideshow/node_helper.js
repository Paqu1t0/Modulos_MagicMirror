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
    },

    socketNotificationReceived: function (notification, payload) {
        if (notification === "GET_PHOTOS") {
            this._loadPhotos(payload.photoDir);
        }
    },

    _loadPhotos: function (photoDir) {
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
                this.sendSocketNotification("PHOTOS_ERROR", {
                    error: "Pasta não encontrada: " + photoDir,
                });
                return;
            }

            const files = fs.readdirSync(photoDir).filter((f) => {
                const ext = path.extname(f).toLowerCase();
                return SUPPORTED.includes(ext);
            });

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
                try {
                    const fullPath = path.join(photoDir, filename);
                    const ext = path.extname(filename).toLowerCase();
                    const mime = MIME_MAP[ext] || "image/jpeg";
                    const data = fs.readFileSync(fullPath);
                    const base64 = data.toString("base64");
                    photos.push({
                        name: path.basename(filename, ext),
                        // Data URI: funciona diretamente como src de qualquer <img>
                        url: `data:${mime};base64,${base64}`,
                    });
                } catch (readErr) {
                    console.warn("MMM-PhotoSlideshow: Não foi possível ler " + filename + " — " + readErr.message);
                }
            }

            this.sendSocketNotification("PHOTOS_LIST", { photos });
            console.log("MMM-PhotoSlideshow: " + photos.length + " foto(s) carregada(s) de " + photoDir);
        } catch (err) {
            this.sendSocketNotification("PHOTOS_ERROR", { error: err.message });
        }
    },
});
