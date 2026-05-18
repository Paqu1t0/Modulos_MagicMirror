import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/widget_model.dart';
import '../services/mirror_api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/widget_detail_dialog.dart';
import '../widgets/mirror_preview_sheet.dart';

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
        _filteredCatalogue = widgets;
        _loadingCatalogue = false;
      });
    }
  }

  Future<void> _loadInstalled() async {
    setState(() => _loadingInstalled = true);
    // getModules() já tenta HTTP -> SSH node -> SSH ls
    final widgets = await MirrorApiService().getModules();
    if (mounted) {
      setState(() {
        // Todos os módulos vindos do Pi têm isInstalled=true
        _installed = widgets.where((w) => w.isInstalled).toList();
        _filteredInstalled = _installed;
        _loadingInstalled = false;
      });
    }
  }

  Future<void> _refreshAll() =>
      Future.wait([_loadCatalogue(), _loadInstalled()]);

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredCatalogue = _catalogue
          .where((w) =>
              w.name.toLowerCase().contains(q) ||
              w.description.toLowerCase().contains(q))
          .toList();
      _filteredInstalled = _installed
          .where((w) => w.name.toLowerCase().contains(q))
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
                            Text('Disponíveis (${_catalogue.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16),
                            const SizedBox(width: 6),
                            Text('No Mirror (${_installed.length})'),
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
                          maxLines: 3,
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
