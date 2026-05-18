import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/widget_model.dart';

/// Mostra uma pré-visualização de um módulo no ecrã do Magic Mirror.
/// O utilizador pode escolher em que posição quer ver o módulo.
class MirrorPreviewSheet extends StatefulWidget {
  final WidgetModel module;

  const MirrorPreviewSheet({super.key, required this.module});

  @override
  State<MirrorPreviewSheet> createState() => _MirrorPreviewSheetState();
}

class _MirrorPreviewSheetState extends State<MirrorPreviewSheet> {
  String _selectedPosition = 'Top Left';

  static const List<String> _positions = [
    'Top Left', 'Top Center', 'Top Right',
    'Middle Left', 'Center', 'Middle Right',
    'Bottom Left', 'Bottom Center', 'Bottom Right',
  ];

  @override
  void initState() {
    super.initState();
    // Iniciar na posição actual do módulo se disponível
    if (widget.module.position != null &&
        _positions.contains(widget.module.position)) {
      _selectedPosition = widget.module.position!;
    }
  }

  int get _selectedIndex => _positions.indexOf(_selectedPosition);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Título
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.module.icon, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.module.name,
                          style: AppTheme.headingMedium),
                      Text('Pré-visualização no Magic Mirror',
                          style: AppTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── Ecrã do Magic Mirror ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _MirrorScreen(
              module: widget.module,
              selectedPosition: _selectedPosition,
              selectedIndex: _selectedIndex,
            ),
          ),
          const SizedBox(height: 16),

          // Label posição seleccionada
          Text(
            'Posição: $_selectedPosition',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),

          // ─── Selector de posição ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Escolher posição:', style: AppTheme.bodySmall),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.6,
                  ),
                  itemCount: _positions.length,
                  itemBuilder: (_, i) {
                    final isSelected = _positions[i] == _selectedPosition;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedPosition = _positions[i]),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.border,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _positions[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Ecrã do Mirror ───────────────────────────────────────────────────────────

class _MirrorScreen extends StatelessWidget {
  final WidgetModel module;
  final String selectedPosition;
  final int selectedIndex;

  const _MirrorScreen({
    required this.module,
    required this.selectedPosition,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF333333), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              // Fundo com grid subtil
              CustomPaint(
                size: Size.infinite,
                painter: _MirrorGridPainter(),
              ),

              // Grid 3x3 com módulo
              Padding(
                padding: const EdgeInsets.all(8),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: 9,
                  itemBuilder: (_, i) {
                    final isSelected = i == selectedIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.6)
                              : const Color(0xFF222222),
                          width: isSelected ? 1.5 : 0.5,
                        ),
                      ),
                      child: isSelected
                          ? _ModuleWidget(module: module)
                          : null,
                    );
                  },
                ),
              ),

              // Label do ecrã (canto inferior)
              Positioned(
                bottom: 6, right: 8,
                child: Text(
                  'Magic Mirror',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.white.withValues(alpha: 0.2),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Conteúdo do módulo no ecrã ──────────────────────────────────────────────

class _ModuleWidget extends StatelessWidget {
  final WidgetModel module;
  const _ModuleWidget({required this.module});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(module.icon, color: Colors.white, size: 18),
        const SizedBox(height: 4),
        Text(
          module.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        // Conteúdo de exemplo baseado na categoria
        ..._sampleContent(module),
      ],
    );
  }

  List<Widget> _sampleContent(WidgetModel m) {
    switch (m.category) {
      case 'Utilities':
        return [
          const Text('14:32', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 12, fontWeight: FontWeight.w700)),
          const Text('Segunda', style: TextStyle(color: Colors.white54, fontSize: 6)),
        ];
      case 'Lifestyle':
        return [
          const Icon(Icons.wb_sunny, color: Color(0xFFFBBF24), size: 12),
          const Text('22°C', style: TextStyle(color: Colors.white70, fontSize: 8)),
        ];
      case 'News':
        return [
          Container(width: 40, height: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(vertical: 2)),
          const Text('Notícias', style: TextStyle(color: Colors.white38, fontSize: 6)),
        ];
      case 'Productivity':
        return [
          const Icon(Icons.event, color: Color(0xFF34D399), size: 10),
          const Text('3 eventos', style: TextStyle(color: Colors.white54, fontSize: 6)),
        ];
      case 'Entertainment':
        return [
          const Icon(Icons.play_circle_outline, color: Color(0xFF60A5FA), size: 10),
        ];
      default:
        return [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 30, height: 1.5,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ];
    }
  }
}

// ─── Pintor da grelha do Mirror ───────────────────────────────────────────────

class _MirrorGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 0.5;

    // Linhas horizontais subtis
    for (int i = 1; i < 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Linhas verticais subtis
    for (int i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
