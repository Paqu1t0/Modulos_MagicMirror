import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/widget_model.dart';

/// Mostra uma pré-visualização em alta definição e interativa de um módulo.
/// Focado em demonstrar o comportamento do widget com animações e dados simulados.
class MirrorPreviewSheet extends StatelessWidget {
  final WidgetModel module;

  const MirrorPreviewSheet({super.key, required this.module});

  @override
  Widget build(BuildContext context) {
    final hasRealImage = module.imageUrl != null;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Pega de Arrasto (Visual indicator for BottomSheet)
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Título, Ícone e Botão Voltar atrás
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(module.icon, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasRealImage ? 'Captura de Ecrã Real' : 'Simulador de Widget (Tempo Real)',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Botão elegante de Voltar atrás
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppTheme.textSecondary),
                  label: Text(
                    'Voltar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.iconBg,
                    foregroundColor: AppTheme.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Ecrã do Widget (Grande, Animado, Premium) ───────────────────
          _DetailedPreviewCard(module: module),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Visualização em Alta Definição (HD) e Animada ──────────────────────────────

class _DetailedPreviewCard extends StatefulWidget {
  final WidgetModel module;

  const _DetailedPreviewCard({required this.module});

  @override
  State<_DetailedPreviewCard> createState() => _DetailedPreviewCardState();
}

class _DetailedPreviewCardState extends State<_DetailedPreviewCard>
    with TickerProviderStateMixin {
  // Controladores de Animação
  late AnimationController _rotationController; // Rotação do disco Vinyl
  late AnimationController _pulseController;    // Pulsação (Bandeiras LIVE, Clima)
  late AnimationController _eqController;       // Equalizador de música animado

  // Timers para atualizações ao vivo
  Timer? _clockTimer;
  Timer? _newsTimer;
  Timer? _iotTimer;
  Timer? _busTimer;
  Timer? _gasTimer;

  // Estado do Relógio
  late DateTime _dateTime;

  // Estado das Notícias (Carousel auto-rotativo)
  int _newsIndex = 0;
  final List<String> _newsHeadlines = [
    'MagicMirror² v2.26 lançada com melhorias na API SSH de emparelhamento.',
    'Novos ecrãs inteligentes baseados em painéis OLED transparentes são apresentados.',
    'Comunidade atinge recorde de mais de 1400 módulos adicionais registados!',
  ];

  // Estado do IoT (Sensores a flutuar ao vivo)
  double _roomTemp = 21.5;
  int _humidity = 48;
  bool _lightOn = true;
  bool _imageLoadFailed = false;

  // Estado dos Autocarros (STCP)
  final List<Map<String, dynamic>> _busArrivals = [
    {'route': '9M', 'dest': 'Gondomar (Souto)', 'min': 2, 'color': const Color(0xFF212121), 'text': Colors.white},
    {'route': '207', 'dest': 'Campanhã', 'min': 7, 'color': const Color(0xFF0038A8), 'text': Colors.white},
    {'route': '400', 'dest': 'Azevedo', 'min': 14, 'color': const Color(0xFFD21034), 'text': Colors.white},
    {'route': '11M', 'dest': 'Coimbrões', 'min': 21, 'color': const Color(0xFF006A4E), 'text': Colors.white},
  ];

  // Estado dos Combustíveis (DGEG)
  int _gasFuelIndex = 0;
  final List<String> _gasFuels = ['gasolina', 'gasoleo', 'gpl'];

  @override
  void initState() {
    super.initState();
    _dateTime = DateTime.now();

    // 1. Rotação contínua e suave para o disco de música
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    _rotationController.repeat();

    // 2. Animação de pulsação suave
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseController.repeat(reverse: true);

    // 3. Equalizador de música com picos de frequência simulados
    _eqController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _eqController.repeat(reverse: true);

    // 4. Relógio em tempo real com precisão de segundos
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _dateTime = DateTime.now();
        });
      }
    });

    // 5. Transição de notícias automática a cada 5 segundos
    _newsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _newsIndex = (_newsIndex + 1) % _newsHeadlines.length;
        });
      }
    });

    // 6. Flutuação de sensores IoT para simular dados dinâmicos reais
    _iotTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _roomTemp = 21.2 + (DateTime.now().millisecond % 7) * 0.1;
          _humidity = 45 + (DateTime.now().millisecond % 8);
          if (DateTime.now().second % 15 == 0) {
            _lightOn = !_lightOn;
          }
        });
      }
    });

    // 7. Decrementar minutos de autocarros periodicamente a cada 10s
    _busTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          for (var arrival in _busArrivals) {
            int m = arrival['min'] as int;
            if (m > 0) {
              arrival['min'] = m - 1;
            } else {
              // Reset para manter simulação infinita
              arrival['min'] = (arrival['route'] == '9M')
                  ? 8
                  : (arrival['route'] == '207' ? 12 : (arrival['route'] == '400' ? 19 : 28));
            }
          }
        });
      }
    });

    // 8. Rotação automática de combustíveis a cada 6s
    _gasTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (mounted) {
        setState(() {
          _gasFuelIndex = (_gasFuelIndex + 1) % _gasFuels.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _eqController.dispose();
    _clockTimer?.cancel();
    _newsTimer?.cancel();
    _iotTimer?.cancel();
    _busTimer?.cancel();
    _gasTimer?.cancel();
    super.dispose();
  }

  Widget _buildSimulatorContent({
    required bool isEphemeris,
    required bool isF1,
    required bool isWeather,
    required bool isClock,
    required bool isCalendar,
    required bool isNews,
    required bool isSpotify,
    required bool isPhotoSlideshow,
    required bool isMusic,
    required bool isFinance,
    required bool isSports,
    required bool isIot,
    required bool isUltrasonic,
    required bool isGestorPaginas,
    required bool isBusCPT,
    required bool isGasPrices,
  }) {
    if (isEphemeris) {
      return _buildEphemerisPreview();
    } else if (isF1) {
      return _buildF1Preview();
    } else if (isWeather) {
      return _buildWeatherPreview();
    } else if (isClock) {
      return _buildClockPreview();
    } else if (isCalendar) {
      return _buildCalendarPreview();
    } else if (isNews) {
      return _buildNewsPreview();
    } else if (isSpotify) {
      return _buildSpotifyPreview();
    } else if (isPhotoSlideshow) {
      return _buildPhotoSlideshowPreview();
    } else if (isUltrasonic) {
      return _buildUltrasonicPreview();
    } else if (isGestorPaginas) {
      return _buildGestorPaginasPreview();
    } else if (isMusic) {
      return _buildMusicPreview();
    } else if (isFinance) {
      return _buildFinancePreview();
    } else if (isSports) {
      return _buildSportsPreview();
    } else if (isIot) {
      return _buildIotPreview();
    } else if (isBusCPT) {
      return _buildBusCPTPreview();
    } else if (isGasPrices) {
      return _buildGasPricesPreview();
    } else {
      return _buildGenericPreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final idLower = widget.module.id.toLowerCase();
    final nameLower = widget.module.name.toLowerCase();
    final descLower = widget.module.description.toLowerCase();

    // ── Módulos nossos com simuladores dedicados ───────────────────────────
    final isSpotify = idLower.contains('spotifynowplaying') || idLower.contains('mmm-spotifynowplaying');
    final isPhotoSlideshow = idLower.contains('photoslideshow') || idLower.contains('mmm-photoslideshow');
    final isUltrasonic = idLower.contains('ultrasonic') || idLower.contains('mmm-ultrasonic');
    final isGestorPaginas = idLower.contains('gestorpaginas') || idLower.contains('mmm-gestorpaginas');
    final isBolsaTicker = idLower.contains('bolsaticker') || idLower.contains('mmm-bolsaticker');
    final isGoogleCalendar = idLower.contains('googlecalendar') || idLower.contains('mmm-googlecalendar');
    final isBusCPT = idLower.contains('buscpt') || idLower.contains('mmm-buscpt');
    final isGasPrices = idLower.contains('gasprices') || idLower.contains('mmm-gasprices');

    // ── Deteção por categoria / keywords ──────────────────────────────────
    final isEphemeris = idLower.contains('onthisday') || nameLower.contains('onthisday') || descLower.contains('history') || (descLower.contains('day') && descLower.contains('this')) || nameLower.contains('ephemeris') || nameLower.contains('efemeride') || descLower.contains('efeméride');
    final isF1 = idLower.contains('f1') || idLower.contains('formula') || nameLower.contains('f1') || nameLower.contains('formula');
    final isWeather = widget.module.category == 'Meteorologia' || idLower.contains('weather') || nameLower.contains('weather') || descLower.contains('clima') || descLower.contains('forecast');
    final isClock = widget.module.category == 'Calendário' && (idLower.contains('clock') || nameLower.contains('clock') || idLower.contains('time') || nameLower.contains('time'));
    // GoogleCalendar usa o simulador dedicado, não o genérico de calendário
    final isCalendar = !isGoogleCalendar && widget.module.category == 'Calendário' && (idLower.contains('calendar') || nameLower.contains('calendar') || idLower.contains('agenda'));
    final isNews = widget.module.category == 'Notícias' || idLower.contains('news') || nameLower.contains('news') || idLower.contains('rss') || nameLower.contains('rss');
    // Spotify e PhotoSlideshow usam simuladores dedicados; outros multimédia usam o genérico de música
    final isMusic = !isSpotify && !isPhotoSlideshow && (widget.module.category == 'Multimédia' || idLower.contains('music') || nameLower.contains('music'));
    // BolsaTicker usa simulador dedicado; outros de bolsa usam o genérico
    final isFinance = !isBolsaTicker && (widget.module.category == 'Bolsa' || idLower.contains('stock') || nameLower.contains('stock') || idLower.contains('finance') || nameLower.contains('finance') || descLower.contains('crypto') || descLower.contains('bitcoin') || descLower.contains('bolsa'));
    final isSports = widget.module.category == 'Desporto' || idLower.contains('sport') || nameLower.contains('sport') || descLower.contains('soccer') || descLower.contains('football') || nameLower.contains('football');
    // Ultrasónico e GestorPaginas usam simuladores dedicados; outros IoT usam genérico
    final isIot = !isUltrasonic && !isGestorPaginas && (widget.module.category == 'Casa Inteligente' || idLower.contains('iot') || nameLower.contains('smart'));

    final hasSpecificSimulator = isEphemeris || isF1 || isWeather || isClock ||
        isCalendar || isNews || isSpotify || isPhotoSlideshow || isMusic ||
        isFinance || isBolsaTicker || isSports || isIot ||
        isUltrasonic || isGestorPaginas || isGoogleCalendar || isBusCPT || isGasPrices;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F0F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF222222), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF161616),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tv_rounded, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Como fica no Magic Mirror',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      hasSpecificSimulator ? 'SIMULADOR' : 'IMAGEM OFICIAL',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white60,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Descrição do widget ────────────────────────────────────────────
            if (widget.module.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: Text(
                  widget.module.description,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.55,
                  ),
                ),
              ),

            // ── OPÇÃO A: tem simulador → mostra só a animação ─────────────────
            if (hasSpecificSimulator) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFF282828), height: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'SIMULADOR INTERATIVO',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.2),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFF282828), height: 1)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: _buildSimulatorContent(
                  isEphemeris: isEphemeris,
                  isF1: isF1,
                  isWeather: isWeather,
                  isClock: isClock,
                  isCalendar: isCalendar || isGoogleCalendar,
                  isNews: isNews,
                  isSpotify: isSpotify,
                  isPhotoSlideshow: isPhotoSlideshow,
                  isMusic: isMusic,
                  isFinance: isFinance || isBolsaTicker,
                  isSports: isSports,
                  isIot: isIot,
                  isUltrasonic: isUltrasonic,
                  isGestorPaginas: isGestorPaginas,
                  isBusCPT: isBusCPT,
                  isGasPrices: isGasPrices,
                ),
              ),
            ],

            // ── OPÇÃO B: sem simulador → mostra só a imagem do catálogo ──────
            if (!hasSpecificSimulator) ...[
              const SizedBox(height: 14),
              if (widget.module.imageUrl != null && !_imageLoadFailed)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 320),
                    width: double.infinity,
                    color: Colors.black,
                    child: Image.network(
                      widget.module.imageUrl!,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 180,
                          color: const Color(0xFF111111),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white38),
                                    backgroundColor: Colors.white12,
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'A carregar imagem do catálogo...',
                                  style: TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _imageLoadFailed = true);
                        });
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
              // Se não há imagem disponível, mostra o simulador genérico
              if (widget.module.imageUrl == null || _imageLoadFailed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: _buildGenericPreview(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // 🏁 1. Simulador Formula 1
  Widget _buildF1Preview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '🏁 F1 - Classificação de Pilotos',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulseController.value * 0.6 + 0.4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                        SizedBox(width: 4),
                        Text(
                          'EM DIRETO',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          ],
        ),
        const SizedBox(height: 14),
        _f1Row(1, 'Max Verstappen', 'Red Bull Racing', '110 pts', isFirst: true),
        _f1Row(2, 'Sergio Perez', 'Red Bull Racing', '89 pts'),
        _f1Row(3, 'Charles Leclerc', 'Ferrari', '78 pts'),
        _f1Row(4, 'Carlos Sainz', 'Ferrari', '69 pts'),
      ],
    );
  }

  Widget _f1Row(int pos, String name, String team, String points, {bool isFirst = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isFirst ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isFirst ? Border.all(color: Colors.white12) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              pos == 1 ? '🥇' : pos == 2 ? '🥈' : pos == 3 ? '🥉' : '$pos',
              style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(team, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          ),
          Text(points, style: TextStyle(color: isFirst ? AppTheme.primary : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // 🌧️ 2. Simulador Meteorologia/Clima
  Widget _buildWeatherPreview() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lisboa, Portugal',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Parcialmente Nublado',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.08),
                  child: const Icon(Icons.wb_cloudy_outlined, color: Colors.blueAccent, size: 40),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '22°C',
              style: TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w200),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Máx: 24°C  Mín: 15°C',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Humidade: 62%  Vento: 14 km/h',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 16),
        const Divider(color: Color(0xFF222222), height: 1),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _weatherDay('Amanhã', '23°C', Icons.wb_sunny_outlined, Colors.amber),
            _weatherDay('Sexta', '21°C', Icons.cloud_outlined, Colors.grey),
            _weatherDay('Sábado', '19°C', Icons.umbrella_outlined, Colors.blue),
            _weatherDay('Domingo', '22°C', Icons.wb_cloudy_outlined, Colors.blueAccent),
          ],
        )
      ],
    );
  }

  Widget _weatherDay(String day, String temp, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(day, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 6),
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(temp, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ⏰ 3. Simulador Relógio Live
  Widget _buildClockPreview() {
    final hh = _dateTime.hour.toString().padLeft(2, '0');
    final mm = _dateTime.minute.toString().padLeft(2, '0');
    final ss = _dateTime.second.toString().padLeft(2, '0');

    final weekdays = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'];
    final months = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];

    final weekday = weekdays[_dateTime.weekday - 1];
    final day = _dateTime.day;
    final month = months[_dateTime.month - 1];
    final year = _dateTime.year;

    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$hh:$mm',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 54,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  shadows: [
                    Shadow(color: AppTheme.primary, blurRadius: 15),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                ss,
                style: TextStyle(
                  color: AppTheme.primary.withValues(alpha: 0.8),
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$weekday, $day de $month de $year',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Icon(
                      Icons.alarm,
                      color: AppTheme.primary.withValues(alpha: _pulseController.value * 0.7 + 0.3),
                      size: 14,
                    );
                  },
                ),
                const SizedBox(width: 8),
                const Text(
                  'Alarme Próximo: 07:30 (Ativo)',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 📅 4. Simulador Calendário/Agenda
  Widget _buildCalendarPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📅 Eventos da Agenda',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _calendarRow('09:30', 'Reunião de Equipa MagicMirror', 'Sala Virtual 2', Colors.blue),
        _calendarRow('12:00', 'Almoço Técnico', 'Restaurante Central', Colors.orange),
        _calendarRow('15:00', 'Revisão de Protótipo', 'Auditório Principal', Colors.green),
      ],
    );
  }

  Widget _calendarRow(String time, String title, String location, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Text(time, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(location, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 📰 5. Simulador Notícias Auto-Carousel
  Widget _buildNewsPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '📰 Feed de Notícias',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'PÚBLICO',
                style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 52,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<int>(_newsIndex),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(color: AppTheme.primary, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(
                      _newsHeadlines[_newsIndex],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_newsHeadlines.length, (index) {
            final isCurrent = index == _newsIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: isCurrent ? 14 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: isCurrent ? AppTheme.primary : const Color(0xFF333333),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // 🎵 6. Simulador Leitor de Música (genérico, ex: vinyl players)
  Widget _buildMusicPreview() {
    return Column(
      children: [
        Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                RotationTransition(
                  turns: _rotationController,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF333333), width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 8, spreadRadius: 1),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF222222), width: 1),
                        ),
                        child: CustomPaint(
                          painter: _VinylPainter(),
                          child: Center(
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Colors.purple, Colors.blue],
                                ),
                              ),
                              child: const Icon(Icons.music_note, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lua (Ao Vivo)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Rui Veloso • Guitarra Portuguesa',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 0.42,
                            backgroundColor: Color(0xFF222222),
                            color: AppTheme.primary,
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '01:32 / 03:41',
                        style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.shuffle, color: Colors.white30, size: 16),
              const Icon(Icons.skip_previous, color: Colors.white70, size: 18),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pause, color: Colors.white, size: 16),
              ),
              const Icon(Icons.skip_next, color: Colors.white70, size: 18),
              const Icon(Icons.repeat, color: Colors.white30, size: 16),
              const SizedBox(width: 10),
              Row(
                children: List.generate(4, (index) {
                  return AnimatedBuilder(
                    animation: _eqController,
                    builder: (context, child) {
                      final baseHeight = [16.0, 10.0, 20.0, 12.0][index];
                      final minHeight = [4.0, 3.0, 6.0, 3.0][index];
                      final height = minHeight + (_eqController.value * (baseHeight - minHeight));
                      return Container(
                        width: 3,
                        height: height,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 🎧 Simulador Spotify Now Playing (MMM-SpotifyNowPlaying)
  Widget _buildSpotifyPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Spotify
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.queue_music, color: Color(0xFF1DB954), size: 18),
            ),
            const SizedBox(width: 8),
            const Text('Spotify — A Tocar Agora',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
            const Spacer(),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Opacity(
                opacity: _pulseController.value * 0.5 + 0.5,
                child: const Icon(Icons.graphic_eq, color: Color(0xFF1DB954), size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Card da música
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1DB954).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              // Capa do álbum (simulada)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: RotationTransition(
                  turns: _rotationController,
                  child: const Center(
                    child: Icon(Icons.album, color: Color(0xFF1DB954), size: 30),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Há muito tempo que não te via',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    const Text('David Fonseca',
                        style: TextStyle(color: Color(0xFF1DB954), fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    const Text('Norte Sul Nascente Poente',
                        style: TextStyle(color: Colors.white38, fontSize: 10)),
                    const SizedBox(height: 10),
                    // Barra de progresso
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: const LinearProgressIndicator(
                        value: 0.38,
                        backgroundColor: Color(0xFF333333),
                        color: Color(0xFF1DB954),
                        minHeight: 3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1:22', style: TextStyle(color: Colors.white38, fontSize: 9)),
                        Text('3:38', style: TextStyle(color: Colors.white38, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Fila a seguir
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Row(
            children: [
              const Icon(Icons.queue_music_outlined, color: Colors.white30, size: 14),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('A seguir: Flor da Cidade — Madredeus',
                    style: TextStyle(color: Colors.white38, fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 🖼️ Simulador Galeria de Fotos (MMM-PhotoSlideshow)
  Widget _buildPhotoSlideshowPreview() {
    final photos = [
      {'emoji': '🌅', 'label': 'Por do Sol — Cascais', 'color': const Color(0xFFFF6B35)},
      {'emoji': '🏖️', 'label': 'Praia da Comporta', 'color': const Color(0xFF4ECDC4)},
      {'emoji': '🏛️', 'label': 'Palácio da Pena — Sintra', 'color': const Color(0xFF6C5CE7)},
    ];
    final photoIdx = (_dateTime.second ~/ 4) % photos.length;
    final photo = photos[photoIdx];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.photo_library_outlined, color: Colors.white54, size: 14),
            const SizedBox(width: 6),
            const Text('Galeria Pessoal — Slideshow',
                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${photoIdx + 1} / ${photos.length}',
                style: const TextStyle(color: Colors.white30, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Container(
            key: ValueKey(photoIdx),
            height: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: (photo['color'] as Color).withValues(alpha: 0.18),
              border: Border.all(color: (photo['color'] as Color).withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(photo['emoji'] as String, style: const TextStyle(fontSize: 44)),
                  const SizedBox(height: 8),
                  Text(photo['label'] as String,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Indicadores (pontos)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(photos.length, (i) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: i == photoIdx ? 16 : 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == photoIdx
                    ? (photos[photoIdx]['color'] as Color)
                    : const Color(0xFF333333),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text('Troca automaticamente a cada 10 segundos',
              style: TextStyle(color: Colors.white24, fontSize: 9)),
        ),
      ],
    );
  }

  // 📡 Simulador Sensor Ultrassónico (MMM-Ultrasonic)
  Widget _buildUltrasonicPreview() {
    final distancia = 45 + (_dateTime.second % 30);
    final deteta = distancia < 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📡 Sensor Ultrassónico HC-SR04',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        // Anel de deteção animado
        Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80 + (_pulseController.value * 20),
                    height: 80 + (_pulseController.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (deteta ? Colors.green : Colors.orange)
                            .withValues(alpha: (1 - _pulseController.value) * 0.5),
                        width: 2,
                      ),
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (deteta ? Colors.green : Colors.orange)
                          .withValues(alpha: 0.15),
                      border: Border.all(
                        color: deteta ? Colors.green : Colors.orange,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      deteta ? Icons.person : Icons.person_off_outlined,
                      color: deteta ? Colors.green : Colors.orange,
                      size: 28,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Distância medida:',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  Text('$distancia cm',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estado:',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: deteta ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        deteta ? 'Presença Detetada' : 'Sem Presença',
                        style: TextStyle(
                          color: deteta ? Colors.green : Colors.orange,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ecrã:',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  Text(
                    deteta ? '✅ A Ligar...' : '💤 Poupança de Energia',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 📄 Simulador Gestor de Páginas (MMM-GestorPaginas)
  Widget _buildGestorPaginasPreview() {
    final pageIdx = (_dateTime.second ~/ 5) % 3;
    final pages = [
      {'icon': Icons.wb_sunny_outlined, 'label': 'Página 1 — Tempo & Relógio', 'color': Colors.amber},
      {'icon': Icons.newspaper_outlined, 'label': 'Página 2 — Notícias & Agenda', 'color': AppTheme.primary},
      {'icon': Icons.queue_music_outlined, 'label': 'Página 3 — Spotify & Fotos', 'color': const Color(0xFF1DB954)},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📄 Gestor de Páginas do Espelho',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        // Ecrã simulado do espelho
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Center(
              key: ValueKey(pageIdx),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    pages[pageIdx]['icon'] as IconData,
                    color: (pages[pageIdx]['color'] as Color).withValues(alpha: 0.8),
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pages[pageIdx]['label'] as String,
                    style: TextStyle(
                      color: (pages[pageIdx]['color'] as Color),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Botões físicos simulados
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _pageBtn(Icons.arrow_back_ios_rounded, 'Anterior'),
            const SizedBox(width: 12),
            ...List.generate(3, (i) => Container(
              width: 8, height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == pageIdx ? AppTheme.primary : const Color(0xFF333333),
              ),
            )),
            const SizedBox(width: 12),
            _pageBtn(Icons.arrow_forward_ios_rounded, 'Próxima'),
          ],
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text('Navega com botões físicos ligados ao GPIO do Pi',
              style: TextStyle(color: Colors.white24, fontSize: 9)),
        ),
      ],
    );
  }

  Widget _pageBtn(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 11),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        ],
      ),
    );
  }

  // 📈 7. Simulador Finanças e Bolsa
  Widget _buildFinancePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📈 Ações e Criptomoedas', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: _stockItem('BTC/USD', '\$67,430', '+3.4%', Colors.green)),
            const SizedBox(width: 8),
            Expanded(child: _stockItem('AAPL', '\$189.84', '+1.2%', Colors.green)),
            const SizedBox(width: 8),
            Expanded(child: _stockItem('GOOGL', '\$173.50', '-0.8%', Colors.red)),
          ],
        )
      ],
    );
  }

  Widget _stockItem(String symbol, String price, String change, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(symbol, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(price, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(color == Colors.green ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: color, size: 14),
              Text(change, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // ⚽ 8. Simulador Desporto / Futebol Live
  Widget _buildSportsPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '🏆 Futebol Internacional',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulseController.value * 0.6 + 0.4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      '84\' MIN',
                      style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.white, size: 24),
                    SizedBox(height: 6),
                    Text(
                      'Real Madrid',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '2 - 1',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const Expanded(
                child: Column(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 24),
                    SizedBox(height: 6),
                    Text(
                      'Barcelona',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'La Liga Santander • El Clásico',
            style: TextStyle(color: Colors.white30, fontSize: 10),
          ),
        )
      ],
    );
  }

  // 🏠 9. Simulador Sensores IoT Live
  Widget _buildIotPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🏠 Sensores & Domótica (Live)',
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _iotTile(
                'Temperatura',
                '${_roomTemp.toStringAsFixed(1)}°C',
                Icons.thermostat,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _iotTile(
                'Iluminação',
                _lightOn ? 'Ligada (80%)' : 'Desligada',
                Icons.lightbulb_outline,
                _lightOn ? Colors.amber : Colors.white30,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _iotTile(
                'Humidade',
                '$_humidity%',
                Icons.water_drop,
                Colors.blue,
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _iotTile(String name, String status, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 4),
          Text(status, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // 📦 10. Simulador Genérico (Qualquer outro módulo)
  Widget _buildGenericPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nome do módulo com ícone
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.module.icon, color: Colors.white60, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.module.name,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Estado ativo (ponto verde animado)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.success.withValues(alpha: 0.6),
                          blurRadius: 4 + (_pulseController.value * 6),
                          spreadRadius: _pulseController.value * 2,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Módulo ativo e pronto a emparelhar',
                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Rodapé com autor e estrelas
        Row(
          children: [
            const Icon(Icons.person_outline, color: Colors.white38, size: 13),
            const SizedBox(width: 4),
            Text('Autor: ${widget.module.author ?? 'Comunidade'}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
            const Spacer(),
            const Icon(Icons.star_outline, color: Colors.white38, size: 13),
            const SizedBox(width: 4),
            Text('${widget.module.stars} estrelas', style: const TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ],
    );
  }

  // 🚌 12. Simulador de Autocarros em Tempo Real (STCP)
  Widget _buildBusCPTPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.directions_bus_filled_outlined, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text(
                  'Batalha',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 6),
                Text(
                  '(BTLH6)',
                  style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulseController.value * 0.7 + 0.3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.fiber_manual_record, color: Colors.red, size: 6),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.only(left: 28),
          child: Text(
            'Chegadas STCP em Tempo Real',
            style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _busArrivals.length,
            separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              final arrival = _busArrivals[index];
              final minutes = arrival['min'] as int;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    // Badge da Carreira
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: arrival['color'] as Color,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ],
                      ),
                      constraints: const BoxConstraints(minWidth: 42),
                      child: Center(
                        child: Text(
                          arrival['route'] as String,
                          style: TextStyle(
                            color: arrival['text'] as Color,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Destino
                    Expanded(
                      child: Text(
                        arrival['dest'] as String,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Tempo Restante
                    if (minutes == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                        ),
                        child: const Text(
                          'A CHEGAR',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          '$minutes min',
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ⛽ 13. Simulador de Preços de Combustíveis (DGEG)
  Widget _buildGasPricesPreview() {
    final activeFuel = _gasFuels[_gasFuelIndex];

    // Listas locais de dados para Porto reais obtidos da DGEG
    final Map<String, List<Map<String, dynamic>>> data = {
      'gasolina': [
        {'nome': 'PETROPRIX Pedroso', 'loc': 'Vila Nova de Gaia', 'preco': 1.859, 'marca': 'PETROPRIX'},
        {'nome': 'PETROPRIX Santo Tirso', 'loc': 'Santo Tirso', 'preco': 1.869, 'marca': 'PETROPRIX'},
        {'nome': 'PLENERGY - Trofa I', 'loc': 'Trofa', 'preco': 1.869, 'marca': 'PLENERGY'},
        {'nome': 'PETROPRIX Matosinhos', 'loc': 'Matosinhos', 'preco': 1.879, 'marca': 'PETROPRIX'},
        {'nome': 'PETROPRIX Paços de Ferreira', 'loc': 'Paços de Ferreira', 'preco': 1.879, 'marca': 'PETROPRIX'},
      ],
      'gasoleo': [
        {'nome': 'PETROPRIX Pedroso', 'loc': 'Vila Nova de Gaia', 'preco': 1.809, 'marca': 'PETROPRIX'},
        {'nome': 'REDE ENERGIA Águas Santas', 'loc': 'Maia', 'preco': 1.820, 'marca': 'REDE ENERGIA'},
        {'nome': 'E. LECLERC Lousada', 'loc': 'Lousada', 'preco': 1.847, 'marca': 'LECLERC'},
        {'nome': 'Efice Energy Marco de Canaveses', 'loc': 'Marco de Canaveses', 'preco': 1.849, 'marca': 'Genérico'},
        {'nome': 'INTERMARCHÉ de Lousada', 'loc': 'Lousada', 'preco': 1.849, 'marca': 'INTERMARCHÉ'},
      ],
      'gpl': [
        {'nome': 'GALP Matosinhos', 'loc': 'Matosinhos', 'preco': 0.989, 'marca': 'GALP'},
        {'nome': 'REPSOL Gaia', 'loc': 'Vila Nova de Gaia', 'preco': 0.999, 'marca': 'REPSOL'},
        {'nome': 'PRIO Porto', 'loc': 'Porto', 'preco': 1.019, 'marca': 'PRIO'},
        {'nome': 'CEPSA Porto', 'loc': 'Porto', 'preco': 1.029, 'marca': 'CEPSA'},
        {'nome': 'GALP Porto', 'loc': 'Porto', 'preco': 1.049, 'marca': 'GALP'},
      ],
    };

    final list = data[activeFuel]!;
    final minPrice = list.first['preco'] as double;
    final maxPrice = list.last['preco'] as double;

    // Cores consoante o combustível ativo
    Color activeColor;
    String fuelTitle;
    IconData fuelIcon = Icons.local_gas_station_rounded;
    if (activeFuel == 'gasolina') {
      activeColor = const Color(0xFF10B981); // Emerald Green
      fuelTitle = 'Gasolina 95 Simples';
    } else if (activeFuel == 'gasoleo') {
      activeColor = const Color(0xFFFBBF24); // Gold/Amber
      fuelTitle = 'Gasóleo Simples';
    } else {
      activeColor = const Color(0xFF3B82F6); // Electric Blue
      fuelTitle = 'GPL Automóvel';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs Interativas
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_gasFuels.length, (index) {
            final f = _gasFuels[index];
            final isActive = index == _gasFuelIndex;
            String label = f == 'gasolina' ? 'Gasolina' : (f == 'gasoleo' ? 'Gasóleo' : 'GPL');
            
            Color tabColor;
            if (f == 'gasolina') {
              tabColor = const Color(0xFF10B981);
            } else if (f == 'gasoleo') tabColor = const Color(0xFFFBBF24);
            else tabColor = const Color(0xFF3B82F6);

            return InkWell(
              onTap: () {
                setState(() {
                  _gasFuelIndex = index;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? tabColor.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? tabColor.withValues(alpha: 0.4) : Colors.white10,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? tabColor : Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 18),
        // Cabeçalho da Lista Ativa
        Row(
          children: [
            Icon(fuelIcon, color: activeColor, size: 18),
            const SizedBox(width: 8),
            Text(
              fuelTitle,
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            const Text(
              'OFICIAL DGEG',
              style: TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Cards dos Postos
        Column(
          children: List.generate(list.length, (index) {
            final station = list[index];
            final price = station['preco'] as double;
            final isFirst = index == 0;

            // Fator de comparação para a barra de progresso horizontal
            double progressFactor = 1.0;
            if (maxPrice > minPrice) {
              progressFactor = (price - minPrice) / (maxPrice - minPrice);
              progressFactor = 1.0 - progressFactor; // Inverter para que o mais barato tenha 100% da barra preenchida
            }

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isFirst ? Colors.white.withValues(alpha: 0.02) : const Color(0xFF161616),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isFirst ? activeColor.withValues(alpha: 0.25) : const Color(0xFF262626),
                ),
              ),
              child: Row(
                children: [
                  // Medalha / Pos
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    child: Text(
                      isFirst ? '🥇' : '${index + 1}',
                      style: TextStyle(
                        color: isFirst ? Colors.white : Colors.white38,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Nome e Municipio
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station['nome'] as String,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              station['loc'] as String,
                              style: const TextStyle(color: Colors.white38, fontSize: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Barra horizontal de comparação
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Container(
                            height: 2,
                            width: 100,
                            color: Colors.white10,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: progressFactor.clamp(0.1, 1.0),
                                child: Container(
                                  color: activeColor.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Badge de Preço
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: activeColor.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '${price.toStringAsFixed(3)} €',
                      style: TextStyle(
                        color: activeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        // Dots Carousel Indicator (Animado a acompanhar index ativo)
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_gasFuels.length, (index) {
            final isActive = index == _gasFuelIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 12 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: isActive ? Colors.white70 : Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // 📜 11. Simulador de Efemérides (OnThisDay / History) - Réplica do Layout Francês do Catálogo
  Widget _buildEphemerisPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ÉPHÉMÉRIDE DU 18 MARS',
          style: TextStyle(
            color: Color(0xFF888888),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 48,
          height: 3,
          color: const Color(0xFF555555),
        ),
        const SizedBox(height: 1),
        const Divider(color: Color(0xFF222222), height: 1, thickness: 1),
        const SizedBox(height: 20),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
            children: [
              TextSpan(
                text: '235 : ',
                style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
              ),
              TextSpan(
                text: "à Mogontiacum (Mayence), des soldats mécontents des pourparlers avec les germains proclament Maximin le Thrace empereur et assassinent Sévère Alexandre et sa mère Julia Mamaea, précipitant l'Empire romain dans un demi-siècle d'anarchie militaire.",
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('235', style: TextStyle(color: Color(0xFF29B6F6), fontWeight: FontWeight.w800, fontSize: 13)),
            Text('1184', style: TextStyle(color: Color(0xFF444444), fontWeight: FontWeight.bold, fontSize: 13)),
            Text('1871', style: TextStyle(color: Color(0xFF444444), fontWeight: FontWeight.bold, fontSize: 13)),
            Text('1921', style: TextStyle(color: Color(0xFF444444), fontWeight: FontWeight.bold, fontSize: 13)),
            Text('1921', style: TextStyle(color: Color(0xFF444444), fontWeight: FontWeight.bold, fontSize: 13)),
            Text('1962', style: TextStyle(color: Color(0xFF444444), fontWeight: FontWeight.bold, fontSize: 13)),
            Text('1990', style: TextStyle(color: Color(0xFF444444), fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ],
    );
  }
}

// Painter para criar ranhuras circulares realistas simulando um disco Vinyl de música
class _VinylPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1C1C1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width * 0.4, paint);
    canvas.drawCircle(center, size.width * 0.35, paint);
    canvas.drawCircle(center, size.width * 0.3, paint);
    canvas.drawCircle(center, size.width * 0.25, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}