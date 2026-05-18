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

class _StoreScreenState extends State<StoreScreen> {
  List<WidgetModel> _allWidgets = [];
  List<WidgetModel> _filtered = [];
  final _searchController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWidgets();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWidgets() async {
    setState(() => _loading = true);
    final widgets = await MirrorApiService().getModules();
    if (mounted) {
      setState(() {
        _allWidgets = widgets;
        _filtered = widgets;
        _loading = false;
      });
    }
  }

  void _onSearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _allWidgets
          .where((w) => w.name.toLowerCase().contains(q) || w.description.toLowerCase().contains(q))
          .toList();
    });
  }

  void _openDetail(WidgetModel w) async {
    final installed = await showDialog<bool>(
      context: context,
      builder: (_) => WidgetDetailDialog(
        widget: w,
        onInstalled: () {
          setState(() => w.isInstalled = true);
        },
      ),
    );
    if (installed == true && mounted) {
      setState(() => w.isInstalled = true);
    }
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Widget Store', style: AppTheme.headingLarge),
                  const SizedBox(height: 4),
                  const Text('Discover new widgets for your mirror', style: AppTheme.bodyMedium),
                  const SizedBox(height: 20),
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
                        hintText: 'Search widgets...',
                        prefixIcon: Icon(Icons.search, color: AppTheme.textMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            // Grid
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadWidgets,
                      color: AppTheme.primary,
                      child: GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _WidgetStoreCard(
                          widget: _filtered[i],
                          onTap: () => _openDetail(_filtered[i]),
                        ),
                      ),
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

// ─── Widget Store Card ───────────────────────────────────────────────────────

class _WidgetStoreCard extends StatelessWidget {
  final WidgetModel widget;
  final VoidCallback onTap;

  const _WidgetStoreCard({required this.widget, required this.onTap});

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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              widget.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                widget.description,
                style: AppTheme.bodySmall,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.isInstalled) ...[
              const SizedBox(height: 8),
              const Text('Installed', style: AppTheme.labelSuccess),
            ],
          ],
        ),
      ),
    );
  }
}
