/**
 * MMM-GasPrices — node_helper.js
 * Puxa os preços de combustíveis mais baratos em tempo real da DGEG de Portugal.
 */
const NodeHelper = require("node_helper");
const https = require("https");

module.exports = NodeHelper.create({
    start: function () {
        console.log("MMM-GasPrices: node_helper iniciado.");
    },

    socketNotificationReceived: function (notification, payload) {
        if (notification === "GASPRICES_FETCH") {
            this._fetchPrices(payload.districtId, payload.fuels);
        }
    },

    _fetchPrices: async function (districtId, fuels) {
        const district = districtId || "13"; // Padrão: Porto (13)
        // Mapeamento dos combustíveis padrão se nenhum for passado
        const targetFuels = fuels || {
            gasolina: "3201",  // Gasolina simples 95
            gasoleo: "2101",   // Gasóleo simples
            gpl: "1120"        // GPL Auto
        };

        const results = {
            gasolina: [],
            gasoleo: [],
            gpl: []
        };

        const promises = Object.keys(targetFuels).map(async (key) => {
            const fuelId = targetFuels[key];
            try {
                const data = await this._fetchFuelData(district, fuelId);
                if (data && data.resultado) {
                    // Mapear dados e formatar
                    results[key] = data.resultado.map(p => ({
                        id: p.Id,
                        nome: p.Nome.trim(),
                        marca: p.Marca.trim() || "Genérico",
                        municipio: p.Municipio,
                        precoStr: p.Preco,
                        precoNum: parseFloat(p.Preco.replace(",", ".").replace("€", "").trim()),
                        combustivel: p.Combustivel,
                        morada: p.Morada,
                        atualizado: p.DataAtualizacao
                    }));
                }
            } catch (e) {
                console.error(`MMM-GasPrices: Erro a obter combustível ${key}: ${e.message}`);
            }
        });

        await Promise.all(promises);

        // Devolve os resultados compilados
        this.sendSocketNotification("GASPRICES_DATA", results);
    },

    _fetchFuelData: function (districtId, fuelId) {
        return new Promise((resolve, reject) => {
            const url = `https://precoscombustiveis.dgeg.gov.pt/api/PrecoComb/PesquisarPostos?idsTiposComb=${fuelId}&idMarca=&idTipoPosto=&idDistrito=${districtId}&idsMunicipios=&qtdPorPagina=5&pagina=1`;

            const options = {
                headers: {
                    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                    "Accept": "application/json, text/plain, */*"
                },
                timeout: 10000
            };

            const req = https.get(url, options, (res) => {
                let data = "";
                res.on("data", (chunk) => (data += chunk));
                res.on("end", () => {
                    try {
                        if (res.statusCode !== 200) {
                            reject(new Error(`Código de estado ${res.statusCode}`));
                            return;
                        }
                        const json = JSON.parse(data);
                        resolve(json);
                    } catch (e) {
                        reject(new Error("Erro de parse do JSON"));
                    }
                });
            });

            req.on("error", (e) => reject(e));
            req.on("timeout", () => {
                req.destroy();
                reject(new Error("Timeout de ligação à DGEG"));
            });
        });
    }
});
