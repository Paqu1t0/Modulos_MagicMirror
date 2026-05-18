import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/widget_model.dart';
import '../services/mirror_api_service.dart';
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

  // Page -> Position -> WidgetId (carregado do Pi ou fallback demo)
  Map<int, Map<String, String>> _layouts = {
    1: {},
    2: {},
    3: {},
  };

  List<WidgetModel> _installedWidgets = [];
  bool _loadingWidgets = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loadingWidgets = true);

    // Carregar widgets instalados e layout em paralelo
    final results = await Future.wait([
      MirrorApiService().getModules(),
      MirrorApiService().loadLayout(),
    ]);

    final modules = results[0] as List<WidgetModel>;
    final layout = results[1] as Map<int, Map<String, String>>;

    if (mounted) {
      setState(() {
        _installedWidgets = modules.where((w) => w.isInstalled).toList();

        if (layout.isNotEmpty) {
          // Layout real do Pi
          _layouts = {
            1: Map<String, String>.from(layout[1] ?? {}),
            2: Map<String, String>.from(layout[2] ?? {}),
            3: Map<String, String>.from(layout[3] ?? {}),
          };
        } else {
          // Fallback demo se não conseguir ler do Pi
          _layouts = {
            1: {'Top Left': 'clock', 'Top Right': 'weather', 'Bottom Center': 'news'},
            2: {'Center': 'calendar'},
            3: {'Bottom Right': 'photos'},
          };
        }
        _loadingWidgets = false;
      });
    }
  }

  int get _currentPage => _tabController.index + 1;

  WidgetModel? _widgetAt(String position) {
    final id = _layouts[_currentPage]?[position];
    if (id == null) return null;
    try {
      return _installedWidgets.firstWhere((w) => w.id == id);
    } catch (_) {
      try {
        return demoWidgets.firstWhere((w) => w.id == id);
      } catch (_) {
        return null;
      }
    }
  }

  List<WidgetModel> get _activeWidgetsForCurrentPage {
    final result = <WidgetModel>[];
    final pageLayout = _layouts[_currentPage] ?? {};
    for (final entry in pageLayout.entries) {
      final w = _widgetAt(entry.key);
      if (w != null) result.add(w..position = entry.key);
    }
    return result;
  }

  // Abre picker para escolher um widget a colocar num slot vazio
  Future<void> _pickWidgetForSlot(String position) async {
    final available = _installedWidgets.isEmpty ? demoWidgets : _installedWidgets;

    final chosen = await showModalBottomSheet<WidgetModel>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _WidgetPickerSheet(
        position: position,
        widgets: available,
      ),
    );

    if (chosen != null && mounted) {
      setState(() {
        _layouts[_currentPage] ??= {};
        _layouts[_currentPage]![position] = chosen.id;
      });
    }
  }

  // Opções ao tocar numa célula ocupada
  void _onOccupiedCellTap(String position, WidgetModel widget) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(widget.icon, color: AppTheme.primary),
                title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(position, style: AppTheme.bodySmall),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: AppTheme.primary),
                title: const Text('Trocar Widget'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickWidgetForSlot(position);
                },
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline, color: AppTheme.error),
                title: const Text('Remover do Slot', style: TextStyle(color: AppTheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _layouts[_currentPage]?.remove(position));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveLayout() async {
    setState(() => _saving = true);
    final success = await MirrorApiService().saveLayout(_layouts);
    if (mounted) setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Layouts guardados! Espelho a reiniciar...'
              : 'Erro ao atualizar as páginas via SSH.'),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Layout Editor', style: AppTheme.headingLarge),
                          SizedBox(height: 4),
                          Text('Toca num slot para adicionar um widget', style: AppTheme.bodyMedium),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _loadAll,
                            icon: const Icon(Icons.refresh, color: AppTheme.textMuted),
                            tooltip: 'Recarregar do Pi',
                          ),
                          if (_saving)
                            const SizedBox(
                              width: 24, height: 24,
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
              child: _loadingWidgets
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
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
          // Legend
          Row(
            children: [
              _LegendDot(color: AppTheme.primary.withValues(alpha: 0.15), label: 'Ocupado'),
              const SizedBox(width: 16),
              _LegendDot(color: AppTheme.border, label: 'Livre — toca para adicionar'),
            ],
          ),
          const SizedBox(height: 14),

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
                  onTap: w != null
                      ? () => _onOccupiedCellTap(pos, w)
                      : () => _pickWidgetForSlot(pos),
                );
              },
            ),
          ),
          const SizedBox(height: 28),

          // Active Widgets list
          Text('Widgets Ativos — Página $_currentPage', style: AppTheme.headingMedium),
          const SizedBox(height: 14),
          if (activeWidgets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.add_box_outlined, size: 48, color: AppTheme.textMuted),
                    const SizedBox(height: 12),
                    Text('Nenhum widget nesta página.', style: AppTheme.bodyMedium),
                    const SizedBox(height: 6),
                    Text('Toca num slot livre para adicionar.', style: AppTheme.bodySmall),
                  ],
                ),
              ),
            )
          else
            ...activeWidgets.map((w) => _ActiveWidgetRow(
                  widget: w,
                  onSwap: () => _pickWidgetForSlot(w.position ?? ''),
                  onRemove: () => setState(() => _layouts[_currentPage]?.remove(w.position)),
                )),
        ],
      ),
    );
  }
}

// ─── Legend Dot ───────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTheme.bodySmall),
      ],
    );
  }
}

// ─── Layout Cell ──────────────────────────────────────────────────────────────

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
          color: isOccupied
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOccupied
                ? AppTheme.primary.withValues(alpha: 0.4)
                : AppTheme.border,
            width: isOccupied ? 1.5 : 1,
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
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.touch_app, size: 12, color: AppTheme.textMuted),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, color: AppTheme.textMuted, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      position,
                      style: AppTheme.bodySmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Active Widget Row ────────────────────────────────────────────────────────

class _ActiveWidgetRow extends StatelessWidget {
  final WidgetModel widget;
  final VoidCallback onSwap;
  final VoidCallback onRemove;

  const _ActiveWidgetRow({required this.widget, required this.onSwap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
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
                  fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary,
                )),
                if (widget.position != null)
                  Text(widget.position!, style: AppTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: AppTheme.primary, size: 20),
            tooltip: 'Trocar',
            onPressed: onSwap,
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppTheme.error, size: 20),
            tooltip: 'Remover',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

// ─── Widget Picker Sheet ──────────────────────────────────────────────────────

class _WidgetPickerSheet extends StatefulWidget {
  final String position;
  final List<WidgetModel> widgets;

  const _WidgetPickerSheet({required this.position, required this.widgets});

  @override
  State<_WidgetPickerSheet> createState() => _WidgetPickerSheetState();
}

class _WidgetPickerSheetState extends State<_WidgetPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.widgets
        .where((w) => w.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adicionar a "${ widget.position}"', style: AppTheme.headingMedium),
              const SizedBox(height: 12),
              // Search
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar widget...',
                    prefixIcon: Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                    hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // List
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final w = filtered[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(w.icon, color: AppTheme.primary, size: 20),
                ),
                title: Text(w.name, style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppTheme.textPrimary,
                )),
                subtitle: Text(w.category, style: AppTheme.bodySmall),
                trailing: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                onTap: () => Navigator.pop(context, w),
              );
            },
          ),
        ),
      ],
    );
  }
}
