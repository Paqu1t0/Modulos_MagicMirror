# MMM-GoogleCalendar

Módulo para [MagicMirror²](https://magicmirror.builders/) que mostra os teus próximos eventos do **Google Calendar** diretamente no espelho inteligente, com atualização automática via OAuth 2.0.

> Criado pela nossa equipa — não requer nenhuma app ou serviço externo além das credenciais da Google.

---

## Pré-visualização

```
┌──────────────────────────────────┐
│  📅  Próximos Eventos            │
├────────┬─────────────────────────┤
│  HOJE  │ Reunião de projeto      │
│        │  🕐 09:00 – 10:00       │
│        │  📍 Sala B, Porto       │
├────────┼─────────────────────────┤
│ AMANHÃ │ Médico                  │
│        │  🕐 14:30 – 15:00       │
├────────┼─────────────────────────┤
│ Sex 24/5│ Aniversário da Ana     │
│        │  Dia inteiro            │
└────────┴─────────────────────────┘
```

---

## Funcionalidades

- ✅ Mostra os **próximos N eventos** do teu calendário principal ou de qualquer outro
- ✅ Diferencia **Hoje**, **Amanhã** e datas futuras
- ✅ Exibe **hora de início e fim** para eventos com hora definida
- ✅ Suporta **eventos de dia inteiro**
- ✅ Mostra **localização** dos eventos (configurável)
- ✅ **Atualização automática** a cada X minutos (configurável)
- ✅ Autenticação segura via **OAuth 2.0** sem guardar a tua password

---

## Pré-requisitos

- MagicMirror² instalado e a funcionar
- Uma conta Google com o Google Calendar ativo
- Acesso à [Google Cloud Console](https://console.cloud.google.com)

---

## Instalação

### 1. Copiar o módulo para o MagicMirror

No Raspberry Pi, executa:

```bash
cd ~/MagicMirror/modules
cp -r /caminho/para/MMM-GoogleCalendar .
```

Ou se usares a nossa app, instala diretamente a partir do separador **Loja**.

---

## Obter as Credenciais Google (passo a passo)

Este é o passo mais importante. Segue com atenção:

### Passo 1 — Criar um projeto na Google Cloud

1. Acede a [console.cloud.google.com](https://console.cloud.google.com)
2. Clica em **"Selecionar projeto"** → **"Novo Projeto"**
3. Dá-lhe um nome (ex: `MagicMirrorCalendar`) e clica **Criar**

### Passo 2 — Ativar a Google Calendar API

1. No menu lateral, vai a **APIs e Serviços → Biblioteca**
2. Pesquisa por **"Google Calendar API"**
3. Clica nela e depois em **Ativar**

### Passo 3 — Criar credenciais OAuth 2.0

1. Vai a **APIs e Serviços → Credenciais**
2. Clica em **"+ Criar Credenciais"** → **"ID de cliente OAuth"**
3. Se pedido, configura o **Ecrã de Consentimento OAuth**:
   - Tipo de utilizador: **Externo**
   - Preenche o nome da aplicação (ex: `MagicMirror`)
   - Em **Âmbitos**, adiciona: `https://www.googleapis.com/auth/calendar.readonly`
   - Em **Utilizadores de teste**, adiciona o teu email Google
4. Volta às Credenciais → **"+ Criar Credenciais"** → **"ID de cliente OAuth"**
5. Tipo de aplicação: **Aplicação para computador (Desktop)**
6. Clica **Criar** e guarda:
   - **Client ID** (termina em `.apps.googleusercontent.com`)
   - **Client Secret**

### Passo 4 — Obter o Refresh Token

No terminal (pode ser no PC ou no Pi), executa:

```bash
# Substitui CLIENT_ID e CLIENT_SECRET pelos teus valores
curl "https://accounts.google.com/o/oauth2/auth?client_id=CLIENT_ID&redirect_uri=urn:ietf:wg:oauth:2.0:oob&scope=https://www.googleapis.com/auth/calendar.readonly&response_type=code&access_type=offline"
```

Ou em alternativa, usa o **OAuth 2.0 Playground** da Google:

1. Acede a [developers.google.com/oauthplayground](https://developers.google.com/oauthplayground)
2. Clica no ícone de configuração (⚙️) no canto superior direito
3. Marca **"Use your own OAuth credentials"** e preenche o Client ID e Secret
4. No campo de âmbitos, escreve: `https://www.googleapis.com/auth/calendar.readonly`
5. Clica **"Authorize APIs"** → faz login com a tua conta Google → **Allow**
6. Clica **"Exchange authorization code for tokens"**
7. Copia o valor de **`refresh_token`**

> ⚠️ **Guarda bem o Refresh Token!** Só aparece uma vez. Se perderes, terás de repetir o processo.

---

## Configuração no MagicMirror

Adiciona ao ficheiro `~/MagicMirror/config/config.js`:

```javascript
{
  module: "MMM-GoogleCalendar",
  position: "top_right",  // Posição no espelho
  config: {
    clientId:     "SEU_CLIENT_ID.apps.googleusercontent.com",
    clientSecret: "SEU_CLIENT_SECRET",
    refreshToken: "SEU_REFRESH_TOKEN",

    // Opções (todas opcionais — já têm valores por defeito)
    calendarId:     "primary",  // "primary" = calendário principal
                                // Ou usa o email do calendário, ex: "familia@gmail.com"
    maxEvents:      5,          // Quantos eventos mostrar no ecrã
    updateInterval: 300000,     // Intervalo de atualização em ms (300000 = 5 minutos)
    showLocation:   true,       // Mostrar ou não a localização do evento
    daysAhead:      7,          // Quantos dias à frente ir buscar eventos
  }
},
```

---

## Opções de Configuração

| Opção            | Tipo      | Padrão    | Descrição                                                      |
|------------------|-----------|-----------|----------------------------------------------------------------|
| `clientId`       | `string`  | `""`      | **Obrigatório.** O Client ID do teu projeto Google Cloud.     |
| `clientSecret`   | `string`  | `""`      | **Obrigatório.** O Client Secret do teu projeto Google Cloud. |
| `refreshToken`   | `string`  | `""`      | **Obrigatório.** O Refresh Token OAuth 2.0.                   |
| `calendarId`     | `string`  | `"primary"` | ID do calendário. `"primary"` usa o calendário principal.   |
| `maxEvents`      | `number`  | `5`       | Número máximo de eventos a exibir.                            |
| `updateInterval` | `number`  | `300000`  | Intervalo de atualização em milissegundos.                    |
| `showLocation`   | `boolean` | `true`    | Se `true`, mostra a localização do evento (quando disponível).|
| `daysAhead`      | `number`  | `7`       | Número de dias à frente para ir buscar eventos.               |

---

## Resolução de Problemas

### O módulo mostra "Não foi possível obter o token de acesso"

- Verifica se o `clientId`, `clientSecret` e `refreshToken` estão corretos no `config.js`
- Certifica-te de que a **Google Calendar API** está ativada no teu projeto
- Confirma que o teu email está na lista de **utilizadores de teste** no ecrã de consentimento

### Os eventos não atualizam

- O intervalo padrão é de 5 minutos. Não é suposto atualizar em tempo real.
- Verifica os logs do MagicMirror: `pm2 logs MagicMirror` ou `npm start` no terminal

### Aparece "Sem eventos nos próximos X dias"

- O teu calendário pode não ter eventos no período configurado
- Experimenta aumentar o valor de `daysAhead`
- Confirma que o `calendarId` é o correto (usa `"primary"` para o calendário principal)

### O módulo não aparece no espelho

- Confirma que a pasta `MMM-GoogleCalendar` está dentro de `~/MagicMirror/modules/`
- Verifica se o bloco de configuração está bem formatado no `config.js` (sem vírgulas a mais ou a menos)

---

## Estrutura de Ficheiros

```
MMM-GoogleCalendar/
├── MMM-GoogleCalendar.js    # Lógica do módulo (interface)
├── MMM-GoogleCalendar.css   # Estilos visuais
├── node_helper.js           # Backend: autenticação OAuth + chamadas à API Google
└── README.md                # Este ficheiro
```

---

## Créditos

Módulo desenvolvido pela nossa equipa como parte do projeto **Magic Mirror App**.  
Utiliza a [Google Calendar API v3](https://developers.google.com/calendar/api/v3/reference) via OAuth 2.0.
