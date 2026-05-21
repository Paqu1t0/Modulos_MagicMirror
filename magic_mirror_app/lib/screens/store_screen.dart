import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/widget_model.dart';
import '../services/mirror_api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/widget_detail_dialog.dart';
import '../widgets/mirror_preview_sheet.dart';

class _CategoryChipStyle {
  final Color bg;
  final Color text;
  final Color border;
  final IconData icon;

  const _CategoryChipStyle({
    required this.bg,
    required this.text,
    required this.border,
    required this.icon,
  });
}

final Map<String, _CategoryChipStyle> _categoryStyles = {
  'Todos': const _CategoryChipStyle(
    bg: Color(0xFF2C2C2E),
    text: Colors.white,
    border: Color(0xFF3A3A3C),
    icon: Icons.all_inclusive_rounded,
  ),
  'Calendário': const _CategoryChipStyle(
    bg: Color(0xFFE1F5FE),
    text: Color(0xFF0277BD),
    border: Color(0xFFB3E5FC),
    icon: Icons.calendar_today_rounded,
  ),
  'Multimédia': const _CategoryChipStyle(
    bg: Color(0xFFE0F7FA),
    text: Color(0xFF00838F),
    border: Color(0xFFB2EBF2),
    icon: Icons.play_circle_fill_rounded,
  ),
  'Deteção de Movimento': const _CategoryChipStyle(
    bg: Color(0xFFFCE4EC),
    text: Color(0xFFC2185B),
    border: Color(0xFFF8BBD0),
    icon: Icons.directions_run_rounded,
  ),
  'Notícias': const _CategoryChipStyle(
    bg: Color(0xFFECEFF1),
    text: Color(0xFF37474F),
    border: Color(0xFFCFD8DC),
    icon: Icons.newspaper_rounded,
  ),
  'Transportes Públicos': const _CategoryChipStyle(
    bg: Color(0xFFFFF8E1),
    text: Color(0xFFFF8F00),
    border: Color(0xFFFFECB3),
    icon: Icons.directions_bus_rounded,
  ),
  'Casa Inteligente': const _CategoryChipStyle(
    bg: Color(0xFFFFF3E0),
    text: Color(0xFFEF6C00),
    border: Color(0xFFFFE0B2),
    icon: Icons.lightbulb_rounded,
  ),
  'Desporto': const _CategoryChipStyle(
    bg: Color(0xFFEDE7F6),
    text: Color(0xFF4527A0),
    border: Color(0xFFD1C4E9),
    icon: Icons.sports_basketball_rounded,
  ),
  'Bolsa': const _CategoryChipStyle(
    bg: Color(0xFFF5F5F5),
    text: Color(0xFF424242),
    border: Color(0xFFE0E0E0),
    icon: Icons.show_chart_rounded,
  ),
  'Leitura de Voz': const _CategoryChipStyle(
    bg: Color(0xFFF9FBE7),
    text: Color(0xFF827717),
    border: Color(0xFFE6EE9C),
    icon: Icons.record_voice_over_rounded,
  ),
  'Trânsito': const _CategoryChipStyle(
    bg: Color(0xFFE8F5E9),
    text: Color(0xFF2E7D32),
    border: Color(0xFFC8E6C9),
    icon: Icons.traffic_rounded,
  ),
  'Controlo de Voz': const _CategoryChipStyle(
    bg: Color(0xFFE3F2FD),
    text: Color(0xFF1565C0),
    border: Color(0xFFBBDEFB),
    icon: Icons.mic_rounded,
  ),
  'Meteorologia': const _CategoryChipStyle(
    bg: Color(0xFFFFEBEE),
    text: Color(0xFFC62828),
    border: Color(0xFFFFCDD2),
    icon: Icons.wb_sunny_rounded,
  ),
  'Geral': const _CategoryChipStyle(
    bg: Color(0xFF2C2C2E),
    text: Colors.white70,
    border: Color(0xFF3A3A3C),
    icon: Icons.grid_view_rounded,
  ),
};

class StoreScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const StoreScreen({super.key, required this.onNavigate});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<WidgetModel> _catalogue = [];
  List<WidgetModel> _installed = [];
  List<WidgetModel> _filteredCatalogue = [];
  List<WidgetModel> _filteredInstalled = [];

  final _searchController = TextEditingController();
  bool _loadingCatalogue = true;
  bool _loadingInstalled = true;

  String _selectedCategory = 'Todos';
  final List<String> _categories = [
    'Todos',
    'Calendário',
    'Meteorologia',
    'Notícias',
    'Multimédia',
    'Casa Inteligente',
    'Transportes Públicos',
    'Trânsito',
    'Desporto',
    'Bolsa',
    'Deteção de Movimento',
    'Controlo de Voz',
    'Leitura de Voz',
    'Geral',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(_onSearch);
    _loadCatalogue();
    _loadInstalled();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogue() async {
    setState(() => _loadingCatalogue = true);
    final widgets = await MirrorApiService().getCatalogueModules();
    if (mounted) {
      setState(() {
        _catalogue = widgets;
        _loadingCatalogue = false;
      });
      _onSearch();
    }
  }

  Future<void> _loadInstalled() async {
    setState(() => _loadingInstalled = true);
    final widgets = await MirrorApiService().getModules();
    if (mounted) {
      setState(() {
        _installed = widgets.where((w) => w.isInstalled).toList();
        _loadingInstalled = false;
      });
      _onSearch();
    }
  }

  Future<void> _refreshAll() =>
      Future.wait([_loadCatalogue(), _loadInstalled()]);

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredCatalogue = _catalogue
          .where((w) =>
              (w.name.toLowerCase().contains(q) ||
                  w.description.toLowerCase().contains(q)) &&
              (_selectedCategory == 'Todos' || w.category == _selectedCategory))
          .toList();
      _filteredInstalled = _installed
          .where((w) =>
              w.name.toLowerCase().contains(q) &&
              (_selectedCategory == 'Todos' || w.category == _selectedCategory))
          .toList();
    });
  }

  void _openPreview(WidgetModel w) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          child: MirrorPreviewSheet(module: w),
        ),
      ),
    );
  }

  void _openDetail(WidgetModel w, WidgetDialogMode mode) {
    showDialog(
      context: context,
      builder: (_) => WidgetDetailDialog(
        widget: w,
        mode: mode,
        onActionDone: () {
          if (mode == WidgetDialogMode.install) {
            setState(() => w.isInstalled = true);
          }
          _loadInstalled();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ─────────────────────────────────────────────────────
            Container(
              color: AppTheme.cardBg,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Biblioteca de Módulos',
                              style: AppTheme.headingLarge),
                          SizedBox(height: 4),
                          Text('Explora, instala e gere os teus módulos',
                              style: AppTheme.bodyMedium),
                        ],
                      ),
                      IconButton(
                        onPressed: _refreshAll,
                        icon: const Icon(Icons.refresh, color: AppTheme.primary),
                        tooltip: 'Atualizar',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Pesquisa
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Pesquisar módulos...',
                        prefixIcon:
                            Icon(Icons.search, color: AppTheme.textMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                        hintStyle:
                            TextStyle(color: AppTheme.textMuted, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Chips de Categoria
                  SizedBox(
                    height: 38,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = cat == _selectedCategory;
                        final style = _categoryStyles[cat] ?? _categoryStyles['Todos']!;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = cat;
                            });
                            _onSearch();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? style.bg
                                  : style.bg.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? style.border
                                    : style.border.withValues(alpha: 0.3),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: style.bg.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    style.icon,
                                    size: 14,
                                    color: isSelected
                                        ? style.text
                                        : style.text.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? style.text
                                          : style.text.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Tabs
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textMuted,
                    indicatorColor: AppTheme.primary,
                    indicatorWeight: 3,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.library_books_outlined, size: 16),
                            const SizedBox(width: 6),
                            Text('Disponíveis (${_filteredCatalogue.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16),
                            const SizedBox(width: 6),
                            Text('No Mirror (${_filteredInstalled.length})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Tab Content ─────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Módulos Disponíveis (catálogo público) ─────────────────
                  _loadingCatalogue
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredCatalogue.isEmpty
                          ? _EmptyState(
                              icon: Icons.library_books_outlined,
                              message: 'Nenhum módulo encontrado.\nVerifica a ligação à internet.',
                            )
                          : RefreshIndicator(
                              onRefresh: _loadCatalogue,
                              color: AppTheme.primary,
                              child: GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    20, 16, 20, 24),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 0.82,
                                ),
                                itemCount: _filteredCatalogue.length,
                                itemBuilder: (_, i) {
                                  final m = _filteredCatalogue[i];
                                  return _CatalogueCard(
                                    module: m,
                                    onPreview: () => _openPreview(m),
                                    onInstall: () => _openDetail(
                                        m, WidgetDialogMode.install),
                                  );
                                },
                              ),
                            ),

                  // ── Módulos no Mirror (instalados no Pi) ───────────────────
                  _loadingInstalled
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('A ler módulos do Raspberry Pi...',
                                  style: AppTheme.bodyMedium),
                            ],
                          ),
                        )
                      : _filteredInstalled.isEmpty
                          ? _EmptyState(
                              icon: Icons.developer_board_off_outlined,
                              message:
                                  'Não foi possível ler os módulos do Pi.\n\nVerifica:\n• IP/credenciais SSH nas Definições\n• Se o Pi está ligado e acessível',
                            )
                          : RefreshIndicator(
                              onRefresh: _loadInstalled,
                              color: AppTheme.primary,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 16, 20, 24),
                                itemCount: _filteredInstalled.length,
                                itemBuilder: (_, i) {
                                  final m = _filteredInstalled[i];
                                  return _InstalledCard(
                                    module: m,
                                    onPreview: () => _openPreview(m),
                                    onManage: () => _openDetail(
                                        m, WidgetDialogMode.manage),
                                  );
                                },
                              ),
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MirrorBottomNavBar(
        currentIndex: 1,
        onTap: widget.onNavigate,
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center, style: AppTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

// ─── Catalogue Card ───────────────────────────────────────────────────────────

class _CatalogueCard extends StatelessWidget {
  final WidgetModel module;
  final VoidCallback onPreview;
  final VoidCallback onInstall;

  const _CatalogueCard({
    required this.module,
    required this.onPreview,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tap para preview
          Expanded(
            child: GestureDetector(
              onTap: onPreview,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.iconBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(module.icon,
                              color: AppTheme.primary, size: 20),
                        ),
                        const Spacer(),
                        if (module.isInstalled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Instalado',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.success,
                                )),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(module.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Expanded(
                      child: Text(module.description,
                          style: AppTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (module.stars > 0)
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 11, color: AppTheme.warning),
                          const SizedBox(width: 3),
                          Text('${module.stars}',
                              style: AppTheme.bodySmall),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Botões
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Row(
              children: [
                // Preview
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPreview,
                    icon: const Icon(Icons.visibility_outlined, size: 14),
                    label: const Text('Ver',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: const BorderSide(color: AppTheme.border),
                      foregroundColor: AppTheme.textSecondary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Instalar
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: module.isInstalled ? null : onInstall,
                    icon: Icon(
                      module.isInstalled ? Icons.check : Icons.download,
                      size: 14,
                    ),
                    label: Text(
                      module.isInstalled ? 'Inst.' : 'Instalar',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Installed Card ───────────────────────────────────────────────────────────

class _InstalledCard extends StatelessWidget {
  final WidgetModel module;
  final VoidCallback onPreview;
  final VoidCallback onManage;

  const _InstalledCard({
    required this.module,
    required this.onPreview,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(module.icon, color: AppTheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(module.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    )),
                if (module.position != null && module.position!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.place_outlined,
                          size: 11, color: AppTheme.textMuted),
                      const SizedBox(width: 3),
                      Text(module.position!, style: AppTheme.bodySmall),
                    ],
                  )
                else
                  Text(module.category, style: AppTheme.bodySmall),
              ],
            ),
          ),
          // Botão preview
          GestureDetector(
            onTap: onPreview,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppTheme.iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.visibility_outlined,
                  color: AppTheme.primary, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          // Botão gerir
          GestureDetector(
            onTap: onManage,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Gerir',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}
