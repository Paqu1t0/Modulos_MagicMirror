# MMM-SpotifyNowPlaying

Este módulo exibe no espelho a música que está atualmente a tocar no Spotify, com a capa do álbum, título, artista e barra de progresso.

## Como configurar

Para que este módulo funcione, é necessário associá-lo à tua conta do Spotify através das credenciais de Developer (API).
Segue os passos:

1. Vai a [Spotify Developer Dashboard](https://developer.spotify.com/dashboard) e faz login.
2. Cria uma nova aplicação (App).
3. Entra na app que criaste, vai a **Settings** e preenche o seguinte:
   - **Redirect URIs**: `http://127.0.0.1:8888/callback` (Importante para gerar os tokens).
4. Copia o **Client ID** e o **Client Secret**.

### Obter o Refresh Token
Para obteres o teu Refresh Token, precisas de correr o script gerador através do separador **Terminal** na configuração deste módulo. 

1. Na App, abre a configuração do módulo **MMM-SpotifyNowPlaying**.
2. Desliza para a direita para ires para o separador **Terminal**.
3. (Apenas se for a primeira vez), instala as dependências com o comando `npm install`.
4. Corre o script com o comando:

```bash
node authorization.js
```

O script vai guiar-te passo a passo. Vai pedir-te para inserires o *Client ID*, depois o *Client Secret*, e de seguida dá-te um link para abrires no browser do telemóvel e copiares o link de resposta. No final, irá cuspir o teu **Refresh Token**.

### Configuração no Formulário
Depois de teres o Refresh Token gerado pelo terminal, volta ao separador **Formulário** na app do telemóvel e cola lá o token no campo `refreshToken`, preenchendo também o `clientId` e `clientSecret`. Grava as definições e estás pronto!

Desfruta da tua música no espelho!
