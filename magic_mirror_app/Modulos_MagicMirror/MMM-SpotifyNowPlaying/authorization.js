const readline = require('readline');
const https = require('https');
const querystring = require('querystring');
const fs = require('fs');
const path = require('path');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

console.log("\n=======================================================");
console.log(" MMM-SpotifyNowPlaying - Gerador de Refresh Token");
console.log("=======================================================\n");

let autoClientId = "";
let autoClientSecret = "";

// Tentar ler da configuração automaticamente
try {
    const configPath = path.resolve(__dirname, "../../config/config.js");
    if (fs.existsSync(configPath)) {
        const configModule = require(configPath);
        const spotifyModule = configModule.modules.find(m => m.module === "MMM-SpotifyNowPlaying");
        if (spotifyModule && spotifyModule.config) {
            autoClientId = spotifyModule.config.clientId || "";
            autoClientSecret = spotifyModule.config.clientSecret || "";
        }
    }
} catch (e) {
    // Ignorar erros de leitura e pedir manualmente
}

function startAuthFlow(clientId, clientSecret) {
    clientId = clientId.trim();
    clientSecret = clientSecret.trim();
    const redirectUri = "http://127.0.0.1:8888/callback";
    const scope = "user-read-currently-playing user-read-playback-state";
    
    const authUrl = "https://accounts.spotify.com/authorize?" + querystring.stringify({
        response_type: "code",
        client_id: clientId,
        scope: scope,
        redirect_uri: redirectUri
    });

    console.log("\n-------------------------------------------------------");
    console.log("Abre o seguinte link no browser do teu telemóvel ou PC:");
    console.log(authUrl);
    console.log("-------------------------------------------------------\n");
    console.log("Após fazeres login e aceitares as permissões, serás redirecionado");
    console.log("para um endereço que começa por http://127.0.0.1:8888/callback?code=...");
    console.log("(Não faz mal se o browser disser que não encontrou a página!)\n");

    const askForUrl = () => {
        rl.question("\n👉 Copia o link inteiro da barra de endereço do browser e cola aqui:\n> ", (responseUrl) => {
            
            responseUrl = responseUrl.trim();
            if (!responseUrl) {
                // Se estiver vazio (por exemplo, um ENTER acidental), pergunta de novo
                return askForUrl();
            }
            
            let code;
            
            try {
                if (responseUrl.includes("code=")) {
                    code = responseUrl.split("code=")[1].split("&")[0];
                } else {
                    code = responseUrl; // caso o user tenha copiado só o código
                }
            } catch (e) {
                console.log("\nErro: Não foi possível ler o código desse link.");
                return askForUrl();
            }

            console.log("\nA gerar o Refresh Token...");

            const authString = Buffer.from(clientId + ":" + clientSecret).toString("base64");
            const body = querystring.stringify({
                grant_type: "authorization_code",
                code: code,
                redirect_uri: redirectUri
            });

            const options = {
                hostname: "accounts.spotify.com",
                path: "/api/token",
                method: "POST",
                headers: {
                    "Authorization": "Basic " + authString,
                    "Content-Type": "application/x-www-form-urlencoded",
                    "Content-Length": Buffer.byteLength(body),
                },
            };

            const req = https.request(options, (res) => {
                let data = "";
                res.on("data", (chunk) => (data += chunk));
                res.on("end", () => {
                    try {
                        const json = JSON.parse(data);
                        if (json.refresh_token) {
                            console.log("\n✅ SUCESSO! ✅\n");
                            console.log("O teu Refresh Token é:");
                            console.log("\n" + json.refresh_token + "\n");
                            console.log("Copia isto, cola na opção 'refreshToken' no Formulário da App, e Guarda!");
                        } else {
                            console.log("\n❌ ERRO da API do Spotify:");
                            console.log(json);
                        }
                    } catch (e) {
                        console.log("\n❌ ERRO ao ler resposta do Spotify:", e);
                    }
                    rl.close();
                });
            });

            req.on("error", (e) => {
                console.error("\n❌ ERRO de rede:", e);
                rl.close();
            });

            req.write(body);
            req.end();
        });
    };
    
    askForUrl();
}

if (autoClientId && autoClientSecret) {
    console.log("✅ Client ID e Client Secret lidos automaticamente do teu MagicMirror!");
    startAuthFlow(autoClientId, autoClientSecret);
} else {
    console.log("⚠️ Client ID e Client Secret não encontrados.");
    console.log("Dica: Se preencheres primeiro o 'Formulário' na App e Guardares, não precisas de escrever aqui!\n");
    rl.question("1. Insere o teu Spotify Client ID: ", (ansId) => {
        rl.question("2. Insere o teu Spotify Client Secret: ", (ansSecret) => {
            startAuthFlow(ansId, ansSecret);
        });
    });
}
