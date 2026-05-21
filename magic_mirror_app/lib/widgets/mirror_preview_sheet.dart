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
      decoration: const BoxDecoration(
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasRealImage ? 'Captura de Ecrã Real' : 'Simulador de Widget (Tempo Real)',
                        style: const TextStyle(
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
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppTheme.textSecondary),
                  label: const Text(
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
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _eqController.dispose();
    _clockTimer?.cancel();
    _newsTimer?.cancel();
    _iotTimer?.cancel();
    super.dispose();
  }

  Widget _buildSimulatorContent({
    required bool isEphemeris,
    required bool isF1,
    required bool isWeather,
    required bool isClock,
    required bool isCalendar,
    required bool isNews,
    required bool isMusic,
    required bool isFinance,
    required bool isSports,
    required bool isIot,
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
    } else if (isMusic) {
      return _buildMusicPreview();
    } else if (isFinance) {
      return _buildFinancePreview();
    } else if (isSports) {
      return _buildSportsPreview();
    } else if (isIot) {
      return _buildIotPreview();
    } else {
      return _buildGenericPreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final idLower = widget.module.id.toLowerCase();
    final nameLower = widget.module.name.toLowerCase();
    final descLower = widget.module.description.toLowerCase();

    final isEphemeris = idLower.contains('onthisday') || nameLower.contains('onthisday') || descLower.contains('history') || (descLower.contains('day') && descLower.contains('this')) || nameLower.contains('ephemeris') || nameLower.contains('efemeride') || descLower.contains('efeméride');
    final isF1 = idLower.contains('f1') || idLower.contains('formula') || nameLower.contains('f1') || nameLower.contains('formula');
    final isWeather = widget.module.category == 'Meteorologia' || idLower.contains('weather') || nameLower.contains('weather') || descLower.contains('clima') || descLower.contains('forecast');
    final isClock = widget.module.category == 'Calendário' && (idLower.contains('clock') || nameLower.contains('clock') || idLower.contains('time') || nameLower.contains('time'));
    final isCalendar = widget.module.category == 'Calendário' && (idLower.contains('calendar') || nameLower.contains('calendar') || idLower.contains('agenda'));
    final isNews = widget.module.category == 'Notícias' || idLower.contains('news') || nameLower.contains('news') || idLower.contains('rss') || nameLower.contains('rss');
    final isMusic = widget.module.category == 'Multimédia' || idLower.contains('music') || nameLower.contains('music') || idLower.contains('spotify') || nameLower.contains('spotify');
    final isFinance = widget.module.category == 'Bolsa' || idLower.contains('stock') || nameLower.contains('stock') || idLower.contains('finance') || nameLower.contains('finance') || descLower.contains('crypto') || descLower.contains('bitcoin') || descLower.contains('bolsa') || nameLower.contains('crypto') || nameLower.contains('bitcoin');
    final isSports = widget.module.category == 'Desporto' || idLower.contains('sport') || nameLower.contains('sport') || descLower.contains('soccer') || descLower.contains('football') || descLower.contains('placar') || nameLower.contains('sport') || nameLower.contains('football');
    final isIot = widget.module.category == 'Casa Inteligente' || idLower.contains('sensor') || nameLower.contains('sensor') || idLower.contains('iot') || nameLower.contains('iot') || idLower.contains('smart') || nameLower.contains('smart');

    // Se tem simulador específico, mostra só a animação.
    // Se é genérico (sem simulador), mostra só a imagem do catálogo.
    final hasSpecificSimulator = isEphemeris || isF1 || isWeather || isClock ||
        isCalendar || isNews || isMusic || isFinance || isSports || isIot;

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
                  isCalendar: isCalendar,
                  isNews: isNews,
                  isMusic: isMusic,
                  isFinance: isFinance,
                  isSports: isSports,
                  isIot: isIot,
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

  // 🎵 6. Simulador Leitor de Música / Spotify
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
                    'Antigravity Coding',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Google DeepMind • Advanced Agent',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: const LinearProgressIndicator(
                            value: 0.55,
                            backgroundColor: Color(0xFF222222),
                            color: AppTheme.primary,
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '01:45 / 03:20',
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
