import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/widget_model.dart';
import '../services/mirror_api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/widget_detail_dialog.dart';

class StoreScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const StoreScreen({super.key, required this.onNavigate});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> with SingleTickerProviderStateMixin {
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
    final widgets = await MirrorApiService().getModules();
    if (mounted) {
      setState(() {
        _installed = widgets.where((w) => w.isInstalled).toList();
        _filteredInstalled = _installed;
        _loadingInstalled = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadCatalogue(), _loadInstalled()]);
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filteredCatalogue = _catalogue
          .where((w) => w.name.toLowerCase().contains(q) || w.description.toLowerCase().contains(q))
          .toList();
      _filteredInstalled = _installed
          .where((w) => w.name.toLowerCase().contains(q))
          .toList();
    });
  }

  void _openCatalogueDetail(WidgetModel w) async {
    await showDialog(
      context: context,
      builder: (_) => WidgetDetailDialog(
        widget: w,
        mode: WidgetDialogMode.install,
        onActionDone: () {
          setState(() => w.isInstalled = true);
          _loadInstalled();
        },
      ),
    );
  }

  void _openInstalledDetail(WidgetModel w) async {
    await showDialog(
      context: context,
      builder: (_) => WidgetDetailDialog(
        widget: w,
        mode: WidgetDialogMode.manage,
        onActionDone: () => _loadInstalled(),
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
            // Header
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
                          Text('Widget Store', style: AppTheme.headingLarge),
                          SizedBox(height: 4),
                          Text('Instala e gere os teus módulos', style: AppTheme.bodyMedium),
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
                  // Search
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
                        prefixIcon: Icon(Icons.search, color: AppTheme.textMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
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
                            const Icon(Icons.store_outlined, size: 16),
                            const SizedBox(width: 6),
                            Text('Catálogo (${_catalogue.length})'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16),
                            const SizedBox(width: 6),
                            Text('Instalados (${_installed.length})'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ─── Catálogo ───────────────────────────────────────────
                  _loadingCatalogue
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredCatalogue.isEmpty
                          ? _EmptyState(message: 'Nenhum módulo encontrado.')
                          : RefreshIndicator(
                              onRefresh: _loadCatalogue,
                              color: AppTheme.primary,
                              child: GridView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 0.82,
                                ),
                                itemCount: _filteredCatalogue.length,
                                itemBuilder: (_, i) => _CatalogueCard(
                                  widget: _filteredCatalogue[i],
                                  onTap: () => _openCatalogueDetail(_filteredCatalogue[i]),
                                ),
                              ),
                            ),

                  // ─── Instalados ─────────────────────────────────────────
                  _loadingInstalled
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredInstalled.isEmpty
                          ? _EmptyState(message: 'Nenhum módulo instalado.\nVai ao Catálogo para instalar.')
                          : RefreshIndicator(
                              onRefresh: _loadInstalled,
                              color: AppTheme.primary,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                                itemCount: _filteredInstalled.length,
                                itemBuilder: (_, i) => _InstalledCard(
                                  widget: _filteredInstalled[i],
                                  onTap: () => _openInstalledDetail(_filteredInstalled[i]),
                                ),
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
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.widgets_outlined, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: AppTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

// ─── Catalogue Card ───────────────────────────────────────────────────────────

class _CatalogueCard extends StatelessWidget {
  final WidgetModel widget;
  final VoidCallback onTap;

  const _CatalogueCard({required this.widget, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.iconBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(widget.icon, color: AppTheme.primary, size: 22),
                ),
                const Spacer(),
                if (widget.isInstalled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Instalado', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.success,
                    )),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(widget.name, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary,
            ), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Expanded(
              child: Text(widget.description, style: AppTheme.bodySmall,
                  maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star, size: 12, color: AppTheme.warning),
                const SizedBox(width: 4),
                Text('${widget.stars}', style: AppTheme.bodySmall),
                const Spacer(),
                Icon(widget.isInstalled ? Icons.check : Icons.download_outlined,
                    size: 16, color: widget.isInstalled ? AppTheme.success : AppTheme.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Installed Card ───────────────────────────────────────────────────────────

class _InstalledCard extends StatelessWidget {
  final WidgetModel widget;
  final VoidCallback onTap;

  const _InstalledCard({required this.widget, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration,
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppTheme.iconBg, borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(widget.icon, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary,
                  )),
                  const SizedBox(height: 2),
                  Text(widget.category, style: AppTheme.bodySmall),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Gerir', style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary,
              )),
            ),
          ],
        ),
      ),
    );
  }
}
