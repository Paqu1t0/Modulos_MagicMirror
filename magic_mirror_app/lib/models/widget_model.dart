import 'package:flutter/material.dart';

/// IDs dos módulos criados pela nossa equipa.
const Set<String> ourModuleIds = {
  'MMM-GestorPaginas',
  'MMM-Ultrasonic',
  'MMM-PhotoSlideshow',
  'MMM-SpotifyNowPlaying',
  'MMM-GoogleCalendar',
  'MMM-BolsaTicker',
  'MMM-MotionWake',
  'MMM-MoodLighting',
  'MMM-BusCPT',
  'MMM-GasPrices',
};

class WidgetModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final IconData icon;
  final String? author;
  final String? repoUrl;
  final int stars;
  bool isInstalled;
  String? position;
  final String? imageUrl;
  bool isArchived;
  String? outdated;
  final bool isOurs;

  WidgetModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.icon,
    this.author,
    this.repoUrl,
    this.stars = 0,
    this.isInstalled = false,
    this.position,
    this.imageUrl,
    this.isArchived = false,
    this.outdated,
    bool? isOurs,
  }) : isOurs = isOurs ?? ourModuleIds.contains(id);

  /// Parse response from the local MagicMirror MMM-Remote-Control API.
  factory WidgetModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    return WidgetModel(
      id: id,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      icon: Icons.widgets,
      isInstalled: json['installed'] as bool? ?? false,
      position: json['position'] as String?,
      imageUrl: json['imageUrl'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      outdated: json['outdated'] as String?,
      isOurs: ourModuleIds.contains(id),
    );
  }

  /// Parse response from the public magicmirror.builders catalogue API.
  factory WidgetModel.fromCatalogueJson(Map<String, dynamic> json) {
    final fullName = json['name'] as String? ?? 'Unknown';
    final name = fullName.replaceAll('MMM-', '');
    
    final officialCat = json['category'] as String?;
    final tags = json['tags'] as List<dynamic>?;
    final description = json['description'] as String? ?? '';
    
    final category = detectCategory(
      name: fullName,
      description: description,
      tags: tags,
      officialCategory: officialCat,
    );

    final imageFile = json['image'] as String?;
    final imageUrl = imageFile != null ? 'https://modules.magicmirror.builders/screenshots/$imageFile' : null;

    return WidgetModel(
      id: fullName,
      name: name,
      description: description,
      category: category,
      icon: _iconForCategory(category),
      author: (json['maintainer'] as String?) ?? (json['author'] as String?),
      repoUrl: json['url'] as String?,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      isInstalled: false,
      imageUrl: imageUrl,
      isArchived: json['isArchived'] as bool? ?? false,
      outdated: json['outdated'] as String?,
      isOurs: ourModuleIds.contains(fullName),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'installed': isInstalled,
        'position': position,
        'imageUrl': imageUrl,
        'isArchived': isArchived,
        'outdated': outdated,
        'isOurs': isOurs,
      };

  static String detectCategory({
    required String name,
    required String description,
    List<dynamic>? tags,
    String? officialCategory,
  }) {
    final nameLower = name.toLowerCase();
    final descLower = description.toLowerCase();
    final tagsList = tags?.map((e) => e.toString().toLowerCase()).toList() ?? [];
    
    bool has(String term) =>
        nameLower.contains(term) ||
        descLower.contains(term) ||
        tagsList.any((t) => t.contains(term));
        
    // 1. Meteorologia
    if (has('weather') || has('clima') || has('meteo') || has('forecast') || has('climat') || has('rain') || has('temp') || has('wind') || has('sol') || has('chuva') || has('neve')) {
      return 'Meteorologia';
    }
    
    // 2. Calendário
    if (has('calendar') || has('todo') || has('agenda') || has('productivity') || has('clock') || has('time') || has('cron') || has('schedu') || has('date') || has('alarm') || has('horario') || has('relogio') || has('temporizador')) {
      return 'Calendário';
    }
    
    // 3. Notícias
    if (has('news') || has('rss') || has('social') || has('history') || has('day') || has('fact') || has('feed') || has('info') || has('onthisday') || has('ephemeris') || has('efemeride') || has('efeméride') || has('reddit') || has('twitter') || has('mastodon') || has('noticias') || has('artigo')) {
      return 'Notícias';
    }
    
    // 4. Multimédia
    if (has('music') || has('media') || has('spotify') || has('video') || has('player') || has('entertainment') || has('fun') || has('youtube') || has('vinyl') || has('radio') || has('cast') || has('album') || has('photo') || has('slideshow') || has('musica') || has('som') || has('foto')) {
      return 'Multimédia';
    }
    
    // 5. Deteção de Movimento
    if (has('motion') || has('camera') || has('security') || has('detection') || has('pir') || has('surveill') || has('face') || has('opencv') || has('webcam') || has('cctv') || has('ultrasonic') || has('movimento') || has('presenca')) {
      return 'Deteção de Movimento';
    }
    
    // 6. Transportes Públicos
    if (has('transport') || has('train') || has('bus') || has('subway') || has('metro') || has('transit') || has('flight') || has('commute') || has('autocarro') || has('comboio')) {
      return 'Transportes Públicos';
    }
    
    // 7. Casa Inteligente
    if (has('sensor') || has('iot') || has('smart home') || has('home automation') || has('domotica') || has('smart') || has('hue') || has('device') || has('control') || has('mqtt') || has('wled') || has('ping') || has('tuya') || has('xiaomi') || has('zigbee') || has('shelly') || has('sonoff') || has('lighting') || has('luz') || has('casa')) {
      return 'Casa Inteligente';
    }
    
    // 8. Desporto
    if (has('sport') || has('fit') || has('football') || has('soccer') || has('basketball') || has('health') || has('gym') || has('workout') || has('f1') || has('formula') || has('running') || has('desporto') || has('futebol') || has('passos') || has('saude')) {
      return 'Desporto';
    }
    
    // 9. Bolsa
    if (has('stock') || has('finance') || has('crypto') || has('bitcoin') || has('bolsa') || has('currency') || has('coin') || has('ethereum') || has('price') || has('gold') || has('silver') || has('financas') || has('moeda') || has('acoes')) {
      return 'Bolsa';
    }
    
    // 10. Controlo de Voz
    if (has('alexa') || has('assistant') || has('google assistant') || has('microphone') || has('voicecontrol') || has('voice control') || has('voicecommand') || has('microfone')) {
      return 'Controlo de Voz';
    }
    
    // 11. Leitura de Voz
    if (has('speech') || has('text-to-speech') || has('tts') || has('reader') || has('talk') || has('speak') || has('pronounce') || has('leitor')) {
      return 'Leitura de Voz';
    }
    
    // 12. Trânsito
    if (has('traffic') || has('transito') || has('route') || has('travel') || has('map') || has('road') || has('navigation') || has('viagem') || has('estrada') || has('mapa')) {
      return 'Trânsito';
    }
    
    // Fallbacks baseados na categoria oficial do catálogo
    if (officialCategory != null && officialCategory.isNotEmpty) {
      final off = officialCategory.toLowerCase();
      if (off.contains('weather')) return 'Meteorologia';
      if (off.contains('calendar') || off.contains('productivity')) return 'Calendário';
      if (off.contains('news') || off.contains('info') || off.contains('religion') || off.contains('education')) return 'Notícias';
      if (off.contains('sport') || off.contains('health')) return 'Desporto';
      if (off.contains('finance') || off.contains('crypto')) return 'Bolsa';
      if (off.contains('voice')) return 'Controlo de Voz';
      if (off.contains('transport') || off.contains('travel')) return 'Transportes Públicos';
      if (off.contains('entertainment') || off.contains('music')) return 'Multimédia';
    }
    
    return 'Geral';
  }

  static IconData _iconForCategory(String category) {
    switch (category) {
      case 'Calendário':          return Icons.calendar_month;
      case 'Multimédia':             return Icons.play_circle_outline;
      case 'Deteção de Movimento':  return Icons.directions_run;
      case 'Notícias':              return Icons.newspaper;
      case 'Transportes Públicos':  return Icons.directions_bus_filled_outlined;
      case 'Casa Inteligente':        return Icons.lightbulb_outline;
      case 'Desporto':            return Icons.sports_basketball;
      case 'Bolsa':             return Icons.show_chart;
      case 'Leitura de Voz':    return Icons.record_voice_over;
      case 'Trânsito':           return Icons.traffic;
      case 'Controlo de Voz':     return Icons.mic;
      case 'Meteorologia':           return Icons.cloud;
      case 'Geral':
      default:                  return Icons.widgets;
    }
  }
}

final List<WidgetModel> demoWidgets = [
  WidgetModel(
    id: 'weather',
    name: 'Weather',
    description: 'Real-time weather updates with 5-day forecast and current conditions',
    category: 'Meteorologia',
    icon: Icons.cloud,
    isInstalled: false,
  ),
  WidgetModel(
    id: 'calendar',
    name: 'Calendar',
    description: 'Sync your events from Google Calendar, Outlook,...',
    category: 'Calendário',
    icon: Icons.calendar_month,
    isInstalled: true,
  ),
  WidgetModel(
    id: 'news',
    name: 'News Feed',
    description: 'Latest headlines from your favorite news sources and...',
    category: 'Notícias',
    icon: Icons.newspaper,
    isInstalled: false,
  ),
  WidgetModel(
    id: 'clock',
    name: 'Clock',
    description: 'Customizable clock with timezone support and...',
    category: 'Calendário',
    icon: Icons.access_time,
    isInstalled: true,
  ),
  WidgetModel(
    id: 'music',
    name: 'Music Player',
    description: 'Control Spotify, Apple Music, or local music playback',
    category: 'Multimédia',
    icon: Icons.play_circle_outline,
    isInstalled: false,
  ),
  WidgetModel(
    id: 'fitness',
    name: 'Fitness Tracker',
    description: 'Daily steps, calories, and workout summary from yo...',
    category: 'Desporto',
    icon: Icons.fitness_center,
    isInstalled: false,
  ),
  WidgetModel(
    id: 'email',
    name: 'Email Inbox',
    description: 'Quick view of unread emails and notifications',
    category: 'Calendário',
    icon: Icons.email,
    isInstalled: false,
  ),
  WidgetModel(
    id: 'photos',
    name: 'Photo Frame',
    description: 'Slideshow of your favorite photos from Google Photo...',
    category: 'Multimédia',
    icon: Icons.photo,
    isInstalled: false,
  ),

  // ─── Módulos Feitos por Nós ──────────────────────────────────────────────
  WidgetModel(
    id: 'MMM-GestorPaginas',
    name: 'Gestor de Páginas',
    description:
        'Navega entre diferentes páginas de conteúdo no espelho com botões físicos. '
        'Permite organizar os módulos em ecrãs separados e alternar entre eles.',
    category: 'Casa Inteligente',
    icon: Icons.view_carousel_outlined,
    author: 'A Nossa Equipa',
    stars: 0,
    isInstalled: false,
    isOurs: true,
  ),
  WidgetModel(
    id: 'MMM-Ultrasonic',
    name: 'Sensor Ultrassónico',
    description:
        'Deteta a presença de uma pessoa em frente ao espelho com sensor ultrassónico HC-SR04. '
        'Liga o ecrã automaticamente quando alguém se aproxima.',
    category: 'Deteção de Movimento',
    icon: Icons.sensors,
    author: 'A Nossa Equipa',
    stars: 0,
    isInstalled: false,
    isOurs: true,
  ),
  WidgetModel(
    id: 'MMM-PhotoSlideshow',
    name: 'Galeria de Fotos',
    description:
        'Exibe até 15 fotos personalizadas no espelho em modo slideshow rotativo. '
        'Suporta transições suaves (fade e slide) com intervalo configurável.',
    category: 'Multimédia',
    icon: Icons.photo_library_outlined,
    author: 'A Nossa Equipa',
    stars: 0,
    isInstalled: false,
    isOurs: true,
  ),
  WidgetModel(
    id: 'MMM-SpotifyNowPlaying',
    name: 'Spotify — A Tocar',
    description:
        'Mostra a música atual do Spotify no espelho: capa do álbum, título, artista '
        'e barra de progresso em tempo real. Liga-se via Spotify Web API.',
    category: 'Multimédia',
    icon: Icons.queue_music_outlined,
    author: 'A Nossa Equipa',
    stars: 0,
    isInstalled: false,
    isOurs: true,
  ),
  WidgetModel(
    id: 'MMM-GoogleCalendar',
    name: 'Google Calendar',
    description:
        'Sincroniza os teus eventos do Google Calendar e mostra-os no espelho. '
        'Login seguro com conta Google via OAuth 2.0.',
    category: 'Calendário',
    icon: Icons.event_note_outlined,
    author: 'A Nossa Equipa',
    stars: 0,
    isInstalled: false,
    isOurs: true,
  ),
  WidgetModel(
    id: 'MMM-BolsaTicker',
    name: 'Bolsa Ticker',
    description:
        'Cotações em tempo real de ações, índices, crypto e moedas. '
        'Modo ticker (scrolling) ou grelha de cards. S&P 500, NASDAQ, PSI-20, Bitcoin e muito mais — sem necessidade de API key.',
    category: 'Bolsa',
    icon: Icons.candlestick_chart_outlined,
    author: 'A Nossa Equipa',
    stars: 0,
    isInstalled: false,
    isOurs: true,
  ),
  WidgetModel(
    id: 'MMM-BusCPT',
    name: 'Autocarros em Tempo Real',
    description:
        'Integração de tempos de espera da STCP (Porto) em tempo real. '
        'Mostra contagens decrescentes e horários oficiais da tua paragem preferida (ex: Batalha).',
    category: 'Transportes Públicos',
    icon: Icons.directions_bus_filled_outlined,
    author: 'A Nossa Equipa',
    stars: 0,
    isInstalled: false,
    isOurs: true,
  ),
  WidgetModel(
    id: 'MMM-GasPrices',
    name: 'Combustíveis Baratos',
    description:
        'Puxa em tempo real os preços oficiais da DGEG para mostrar os postos de combustível mais baratos da tua zona (Gasolina/Gasóleo/GPL).',
    category: 'Trânsito',
    icon: Icons.local_gas_station_rounded,
    author: 'A Nossa Equipa',
    stars: 0,
    isInstalled: false,
    isOurs: true,
  ),
];
