/**
 * MMM-PhotoSlideshow
 * Módulo criado pela nossa equipa.
 * Exibe um slideshow rotativo de fotos personalizadas no espelho.
 *
 * Configuração no config.js do MagicMirror:
 * {
 *   module: "MMM-PhotoSlideshow",
 *   position: "fullscreen_below",
 *   config: {
 *     photoDir: "/home/pi/fotos",     // Pasta com as fotos no Raspberry Pi
 *     interval: 10000,                // Intervalo entre fotos em ms (padrão: 10s)
 *     transitionEffect: "fade",       // "fade" | "slide" | "zoom"
 *     overlayOpacity: 0.35,          // Escurecimento sobre as fotos (0 a 1)
 *     showCaption: true,              // Mostrar o nome do ficheiro como legenda
 *   }
 * }
 */
Module.register("MMM-PhotoSlideshow", {
    defaults: {
        photoDir: "/home/pi/fotos",
        interval: 10000,
        transitionEffect: "fade",
        overlayOpacity: 0.35,
        showCaption: false,
    },

    start: function () {
        this.photos = [];
        this.currentIndex = 0;
        this.loaded = false;
        this.transitioning = false;

        Log.info("MMM-PhotoSlideshow: A iniciar módulo...");
        this.sendSocketNotification("GET_PHOTOS", { photoDir: this.config.photoDir });
    },

    getStyles: function () {
        return ["MMM-PhotoSlideshow.css"];
    },

    getDom: function () {
        const wrapper = document.createElement("div");
        wrapper.className = "mmm-photoslideshow-wrapper";

        if (!this.loaded) {
            const loading = document.createElement("div");
            loading.className = "mmm-photoslideshow-loading";
            loading.innerHTML = "⏳ A carregar fotos...";
            wrapper.appendChild(loading);
            return wrapper;
        }

        if (this.photos.length === 0) {
            const noPhotos = document.createElement("div");
            noPhotos.className = "mmm-photoslideshow-empty";
            noPhotos.innerHTML = "📷 Nenhuma foto encontrada em:<br><code>" + this.config.photoDir + "</code>";
            wrapper.appendChild(noPhotos);
            return wrapper;
        }

        // Overlay escuro por cima da foto
        const overlay = document.createElement("div");
        overlay.className = "mmm-photoslideshow-overlay";
        overlay.style.opacity = this.config.overlayOpacity;
        wrapper.appendChild(overlay);

        // Imagem atual
        const img = document.createElement("img");
        img.className = "mmm-photoslideshow-image " + this.config.transitionEffect;
        img.src = this.photos[this.currentIndex].url;
        img.alt = this.photos[this.currentIndex].name;
        wrapper.appendChild(img);

        // Legenda
        if (this.config.showCaption) {
            const caption = document.createElement("div");
            caption.className = "mmm-photoslideshow-caption";
            caption.innerText = this.photos[this.currentIndex].name;
            wrapper.appendChild(caption);
        }

        // Indicadores (pontinhos)
        if (this.photos.length <= 15) {
            const dots = document.createElement("div");
            dots.className = "mmm-photoslideshow-dots";
            this.photos.forEach((_, i) => {
                const dot = document.createElement("span");
                dot.className = "mmm-photoslideshow-dot" + (i === this.currentIndex ? " active" : "");
                dots.appendChild(dot);
            });
            wrapper.appendChild(dots);
        }

        return wrapper;
    },

    socketNotificationReceived: function (notification, payload) {
        if (notification === "PHOTOS_LIST") {
            this.photos = payload.photos;
            this.loaded = true;
            this.currentIndex = 0;
            this.updateDom();
            this._startSlideshow();
        }
        if (notification === "PHOTOS_ERROR") {
            Log.error("MMM-PhotoSlideshow: Erro ao ler fotos — " + payload.error);
            this.loaded = true;
            this.photos = [];
            this.updateDom();
        }
    },

    _startSlideshow: function () {
        if (this.slideshowTimer) clearInterval(this.slideshowTimer);
        if (this.photos.length <= 1) return;

        this.slideshowTimer = setInterval(() => {
            this.currentIndex = (this.currentIndex + 1) % this.photos.length;
            this.updateDom();
        }, this.config.interval);
    },

    suspend: function () {
        if (this.slideshowTimer) clearInterval(this.slideshowTimer);
    },

    resume: function () {
        this._startSlideshow();
    },
});
