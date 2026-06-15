#  Magic Mirror — Control Center

Uma aplicação Flutter multiplataforma que serve como painel de controlo para um **espelho inteligente (Magic Mirror)** baseado em Raspberry Pi. Permite gerir e configurar módulos personalizados diretamente a partir do telemóvel, tablet ou computador, comunicando com o Raspberry Pi via SSH.

---

## 📱 Plataformas Suportadas

- Android
- iOS
- Web
- Linux
- macOS
- Windows

---

## ✨ Funcionalidades

- Controlo remoto do Magic Mirror via **SSH** (utilizando `dartssh2`)
- Gestão de módulos personalizados instalados no espelho
- Interface intuitiva com suporte a **Material Design**
- Visualização de conteúdos em **Markdown**
- Carregamento de ficheiros de configuração locais
- Abertura de links externos com `url_launcher`
- Persistência de preferências locais com `shared_preferences`

---

## 🧩 Módulos Incluídos

O projeto inclui os seguintes módulos para o Magic Mirror²:

| Módulo | Descrição |
|---|---|
| `MMM-BolsaTicker` | Ticker de cotações da bolsa de valores |
| `MMM-BusCPT` | Horários de autocarros em tempo real |
| `MMM-GasPrices` | Preços dos combustíveis |
| `MMM-GestorPaginas` | Gestor de páginas/cenas do espelho |
| `MMM-GoogleCalendar` | Integração com o Google Calendar |
| `MMM-PhotoSlideshow` | Apresentação de fotografias em slideshow |
| `MMM-SpotifyNowPlaying` | Música a tocar no Spotify em tempo real |
| `MMM-Ultrasonic` | Sensor ultrassónico para deteção de presença |

---

## 🚀 Instalação e Configuração

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `^3.7.0`
- Dart `^3.7.0`
- Um Raspberry Pi com [MagicMirror²](https://magicmirror.builders/) instalado

### Clonar o repositório

```bash
git clone https://github.com/Paqu1t0/Modulos_MagicMirror.git
cd Modulos_MagicMirror
```

### Instalar dependências

```bash
flutter pub get
```

### Executar a aplicação

```bash
# Android / iOS
flutter run

# Web
flutter run -d chrome

# Linux / macOS / Windows
flutter run -d <platform>
```

---

## 📦 Dependências Principais

| Pacote | Versão | Utilização |
|---|---|---|
| `http` | ^1.2.1 | Pedidos HTTP |
| `dartssh2` | ^2.12.0 | Ligação SSH ao Raspberry Pi |
| `shared_preferences` | ^2.2.3 | Armazenamento local de preferências |
| `flutter_markdown` | ^0.7.7+1 | Renderização de Markdown |
| `url_launcher` | ^6.3.0 | Abertura de URLs |
| `file_picker` | ^8.1.1 | Seleção de ficheiros locais |

---

## 📁 Estrutura do Projeto

```
Modulos_MagicMirror/
├── Modulos_MagicMirror/       # Módulos do Magic Mirror²
│   ├── MMM-BolsaTicker/
│   ├── MMM-BusCPT/
│   ├── MMM-GasPrices/
│   ├── MMM-GestorPaginas/
│   ├── MMM-GoogleCalendar/
│   ├── MMM-PhotoSlideshow/
│   ├── MMM-SpotifyNowPlaying/
│   └── MMM-Ultrasonic/
├── lib/                       # Código Dart/Flutter
├── android/                   # Configuração Android
├── ios/                       # Configuração iOS
├── web/                       # Configuração Web
├── linux/                     # Configuração Linux
├── macos/                     # Configuração macOS
├── windows/                   # Configuração Windows
├── test/                      # Testes
└── pubspec.yaml               # Dependências do projeto
```

---

