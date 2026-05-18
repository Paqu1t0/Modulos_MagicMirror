import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/widget_model.dart';
import '../services/mirror_api_service.dart';
import '../services/ssh_service.dart';
import '../widgets/bottom_nav_bar.dart';

const List<String> _gridPositions = [
  'Top Left',    'Top Center',    'Top Right',
  'Middle Left', 'Center',        'Middle Right',
  'Bottom Left', 'Bottom Center', 'Bottom Right',
];

class LayoutScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const LayoutScreen({super.key, required this.onNavigate});

  @override
  State<LayoutScreen> createState() => _LayoutScreenState();
}

class _LayoutScreenState extends State<LayoutScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Page -> Position -> WidgetId
  final Map<int, Map<String, String>> _layouts = {
    1: {
      'Top Left': 'clock',
      'Top Right': 'weather',
      'Bottom Center': 'news',
    },
    2: {
      'Center': 'calendar',
    },
    3: {
      'Bottom Right': 'photos',
    }
  };

  List<WidgetModel> _installedWidgets = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadWidgets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWidgets() async {
    final all = await MirrorApiService().getModules();
    if (mounted) {
      setState(() {
        _installedWidgets = all.where((w) => w.isInstalled).toList();
      });
    }
  }

  int get _currentPage => _tabController.index + 1;

  WidgetModel? _widgetAt(String position) {
    final pageLayout = _layouts[_currentPage] ?? {};
    final id = pageLayout[position];
    if (id == null) return null;
    try {
      return _installedWidgets.firstWhere((w) => w.id == id);
    } catch (_) {
      return demoWidgets.firstWhere(
        (w) => w.id == id,
        orElse: () => demoWidgets.first,
      );
    }
  }

  List<WidgetModel> get _activeWidgetsForCurrentPage {
    final result = <WidgetModel>[];
    final pageLayout = _layouts[_currentPage] ?? {};
    for (final entry in pageLayout.entries) {
      final w = _widgetAt(entry.key);
      if (w != null) {
        result.add(w..position = entry.key);
      }
    }
    return result;
  }

  Future<void> _saveLayout() async {
    setState(() => _saving = true);
    
    // Agora enviamos as 3 páginas para o SshService gerar o script
    final success = await SshService().updateMagicMirrorConfig(_layouts);
    
    if (mounted) setState(() => _saving = false);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Layouts guardados! Espelho a reiniciar...'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao atualizar as páginas via SSH.'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _clearPosition(String position) {
    setState(() {
      _layouts[_currentPage]?.remove(position);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header e TabBar
            Container(
              color: AppTheme.cardBg,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Layout Editor', style: AppTheme.headingLarge),
                          SizedBox(height: 4),
                          Text('Arrange widgets on your mirror', style: AppTheme.bodyMedium),
                        ],
                      ),
                      if (_saving)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                        )
                      else
                        IconButton(
                          onPressed: _saveLayout,
                          icon: const Icon(Icons.save_outlined, color: AppTheme.primary),
                          tooltip: 'Guardar layouts',
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textMuted,
                    indicatorColor: AppTheme.primary,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'Página 1'),
                      Tab(text: 'Página 2'),
                      Tab(text: 'Página 3'),
                    ],
                  ),
                ],
              ),
            ),
            
            // Conteúdo Tab
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // Evitar deslizar acidental nas grelhas
                children: [
                  _buildPageContent(),
                  _buildPageContent(),
                  _buildPageContent(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MirrorBottomNavBar(
        currentIndex: 2,
        onTap: widget.onNavigate,
      ),
    );
  }

  Widget _buildPageContent() {
    final activeWidgets = _activeWidgetsForCurrentPage;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3×3 Grid
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.cardDecoration,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.9,
              ),
              itemCount: _gridPositions.length,
              itemBuilder: (_, i) {
                final pos = _gridPositions[i];
                final w = _widgetAt(pos);
                return _LayoutCell(
                  position: pos,
                  widget: w,
                  onTap: w != null ? () => _clearPosition(pos) : null,
                );
              },
            ),
          ),
          const SizedBox(height: 28),

          // Active Widgets list
          Text('Widgets Ativos (Página $_currentPage)', style: AppTheme.headingMedium),
          const SizedBox(height: 14),
          if (activeWidgets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('Nenhum widget nesta página.', style: AppTheme.bodyMedium),
              ),
            )
          else
            ...activeWidgets.map((w) => _ActiveWidgetRow(
                  widget: w,
                  onRemove: () => _clearPosition(w.position ?? ''),
                )),
        ],
      ),
    );
  }
}

// ─── Layout Cell ─────────────────────────────────────────────────────────────

class _LayoutCell extends StatelessWidget {
  final String position;
  final WidgetModel? widget;
  final VoidCallback? onTap;

  const _LayoutCell({required this.position, this.widget, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOccupied = widget != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isOccupied ? AppTheme.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOccupied ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.border,
            width: isOccupied ? 1.5 : 1,
            style: isOccupied ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Center(
          child: isOccupied
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget!.icon, color: AppTheme.primary, size: 22),
                    const SizedBox(height: 6),
                    Text(
                      widget!.name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : Text(
                  position,
                  style: AppTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
        ),
      ),
    );
  }
}

// ─── Active Widget Row ────────────────────────────────────────────────────────

class _ActiveWidgetRow extends StatelessWidget {
  final WidgetModel widget;
  final VoidCallback onRemove;

  const _ActiveWidgetRow({required this.widget, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          const Icon(Icons.drag_indicator, color: AppTheme.textMuted, size: 20),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name, style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                )),
                if (widget.position != null)
                  Text(widget.position!, style: AppTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textMuted, size: 20),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
