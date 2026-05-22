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
  'Módulos Próprios': const _CategoryChipStyle(
    bg: Color(0xFFFFF8E1),
    text: Color(0xFFB45309),
    border: Color(0xFFFDE68A),
    icon: Icons.workspace_premium_rounded,
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
  final ValueNotifier<int>? activeTabNotifier;

  const StoreScreen({
    super.key,
    required this.onNavigate,
    this.activeTabNotifier,
  });

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
    'Módulos Próprios',
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
    widget.activeTabNotifier?.addListener(_handleTabChange);
    _loadCatalogue();
    _loadInstalled();
  }

  @override
  void dispose() {
    widget.activeTabNotifier?.removeListener(_handleTabChange);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    // Se navegamos para a aba da Loja (índice 1)
    if (widget.activeTabNotifier?.value == 1 && mounted) {
      _refreshAll(forceRefresh: false);
    }
  }

  Future<void> _loadCatalogue({bool forceRefresh = false}) async {
    if (_catalogue.isEmpty) {
      setState(() => _loadingCatalogue = true);
    }
    final widgets = await MirrorApiService().getCatalogueModules();
    if (mounted) {
      setState(() {
        _catalogue = widgets;
        _loadingCatalogue = false;
      });
      _crossReferenceInstalledStatus();
      _onSearch();
    }
  }

  Future<void> _loadInstalled({bool forceRefresh = false}) async {
    if (_installed.isEmpty) {
      setState(() => _loadingInstalled = true);
    }
    final widgets = await MirrorApiService().getAllInstalledModules(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _installed = widgets.where((w) => w.isInstalled).toList();
        _loadingInstalled = false;
      });
      _crossReferenceInstalledStatus();
      _onSearch();
    }
  }

  Future<void> _refreshAll({bool forceRefresh = false}) =>
      Future.wait([_loadCatalogue(forceRefresh: forceRefresh), _loadInstalled(forceRefresh: forceRefresh)]);

  void _crossReferenceInstalledStatus() {
    if (_catalogue.isEmpty) return;
    
    // Mapeamento dos módulos do catálogo para fácil pesquisa
    final catalogueMap = {for (var w in _catalogue) w.id.toLowerCase(): w};
    
    // Conjunto de IDs instalados (case-insensitive + sem prefixo MMM-)
    final installedIds = _installed
        .map((w) => w.id.toLowerCase())
        .toSet();
    final installedNames = _installed
        .map((w) => w.id.toLowerCase().replaceAll('mmm-', ''))
        .toSet();
        
    setState(() {
      for (final w in _catalogue) {
        final idLower = w.id.toLowerCase();
        final nameLower = idLower.replaceAll('mmm-', '');
        w.isInstalled = installedIds.contains(idLower) ||
            installedNames.contains(nameLower);
      }
      
      // Copiar estado de arquivado/descontinuado para os módulos instalados
      for (final w in _installed) {
        final idLower = w.id.toLowerCase();
        final match = catalogueMap[idLower] ?? catalogueMap[idLower.replaceAll('mmm-', '')];
        if (match != null) {
          w.isArchived = match.isArchived;
          w.outdated = match.outdated;
        }
      }
    });
  }


  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredCatalogue = _catalogue
          .where((w) =>
              (w.name.toLowerCase().contains(q) ||
                  w.description.toLowerCase().contains(q)) &&
              (_selectedCategory == 'Todos' ||
               (_selectedCategory == 'Módulos Próprios' && w.isOurs) ||
               (_selectedCategory != 'Módulos Próprios' && w.category == _selectedCategory)) &&
              // Ocultar módulos arquivados ou marcados como abandonados/outdated na loja
              !w.isArchived && (w.outdated == null || w.outdated!.isEmpty))
          .toList();
      _filteredInstalled = _installed
          .where((w) =>
              w.name.toLowerCase().contains(q) &&
              (_selectedCategory == 'Todos' ||
               (_selectedCategory == 'Módulos Próprios' && w.isOurs) ||
               (_selectedCategory != 'Módulos Próprios' && w.category == _selectedCategory)))
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
            // Atualização imediata no catálogo (sem esperar SSH)
            setState(() {
              w.isInstalled = true;
              
              // Adicionar imediatamente aos instalados
              final installedWidget = WidgetModel(
                id: w.id,
                name: w.name,
                description: w.description,
                category: w.category,
                icon: w.icon,
                author: w.author,
                repoUrl: w.repoUrl,
                stars: w.stars,
                isInstalled: true,
                imageUrl: w.imageUrl,
                isArchived: w.isArchived,
                outdated: w.outdated,
              );
              if (!_installed.any((x) => x.id == installedWidget.id)) {
                _installed.add(installedWidget);
              }
            });
            _onSearch(); // Atualiza a lista filtrada no ecrã imediatamente
            
            // Muda para tab "No Mirror" imediatamente
            if (mounted) _tabController.animateTo(1);
            // Refresh completo de ambas as listas em background
            _refreshAll();
          } else {
            // Se foi removido, remover imediatamente da lista local
            setState(() {
              _installed.removeWhere((x) => x.id == w.id);
              w.isInstalled = false;
            });
            _onSearch(); // Atualiza a lista filtrada no ecrã imediatamente
            
            // Após remover/atualizar: refresh completo de ambas as listas
            _refreshAll();
          }
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
                      Column(
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
                        onPressed: () => _refreshAll(forceRefresh: true),
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
                      decoration: InputDecoration(
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.library_books_outlined, size: 15),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Disponíveis (${_filteredCatalogue.length})',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 15),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'No Mirror (${_filteredInstalled.length})',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Legenda
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text('Módulos com este estilo foram criados por nós',
                          style: AppTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
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

// ─── "Módulos Próprios" Badge ─────────────────────────────────────────────────────────

class _OursBadge extends StatelessWidget {
  final bool compact;
  const _OursBadge({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            size: compact ? 9 : 10,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Módulos Próprios',
                style: TextStyle(
                  fontSize: compact ? 8 : 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
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
      decoration: module.isOurs
          ? BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFDE68A),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            )
          : AppTheme.cardDecoration,
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
                            color: module.isOurs
                                ? const Color(0xFFFEF3C7)
                                : AppTheme.iconBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            module.icon,
                            color: module.isOurs
                                ? const Color(0xFFD97706)
                                : AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: module.isInstalled
                                ? Container(
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
                                  )
                                : const SizedBox(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(module.name,
                        style: TextStyle(
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
                    if (module.isOurs && module.author != null)
                      Row(
                        children: [
                          const Icon(Icons.people_outline_rounded,
                              size: 11, color: Color(0xFFD97706)),
                          const SizedBox(width: 3),
                          Text(module.author!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFD97706),
                              )),
                        ],
                      )
                    else if (module.stars > 0)
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
                  child: OutlinedButton(
                    onPressed: onPreview,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                      side: BorderSide(
                        color: module.isOurs
                            ? const Color(0xFFFDE68A)
                            : AppTheme.border,
                      ),
                      foregroundColor: module.isOurs
                          ? const Color(0xFFD97706)
                          : AppTheme.textSecondary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_outlined, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: const Text('Ver',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Instalar
                Expanded(
                  child: ElevatedButton(
                    onPressed: module.isInstalled ? null : onInstall,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                      backgroundColor: module.isOurs
                          ? const Color(0xFFD97706)
                          : null,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          module.isInstalled ? Icons.check : Icons.download,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              module.isInstalled ? 'Inst.' : 'Instalar',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
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
      decoration: module.isOurs
          ? BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFDE68A),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: module.isOurs
                  ? const Color(0xFFFEF3C7)
                  : AppTheme.iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              module.icon,
              color: module.isOurs
                  ? const Color(0xFFD97706)
                  : AppTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(module.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          )),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (module.position != null && module.position!.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.place_outlined,
                          size: 11, color: AppTheme.textMuted),
                      const SizedBox(width: 3),
                      Text(module.position!, style: AppTheme.bodySmall),
                    ],
                  )
                else
                  Text(module.category, style: AppTheme.bodySmall),
                if (module.isArchived || (module.outdated != null && module.outdated!.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 12, color: AppTheme.warning),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            module.outdated ?? 'Descontinuado/Arquivado',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.warning,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
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