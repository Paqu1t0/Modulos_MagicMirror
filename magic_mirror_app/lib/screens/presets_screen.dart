import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/preset_model.dart';
import '../services/mirror_api_service.dart';
import '../widgets/bottom_nav_bar.dart';

class PresetsScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const PresetsScreen({super.key, required this.onNavigate});

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  List<PresetModel> _presets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  Future<void> _loadPresets() async {
    setState(() => _loading = true);
    final presets = await MirrorApiService().getPresets();
    if (mounted) setState(() { _presets = presets; _loading = false; });
  }

  PresetModel? get _activePreset {
    try {
      return _presets.firstWhere((p) => p.isActive);
    } catch (_) {
      return null;
    }
  }

  Future<void> _applyPreset(PresetModel preset) async {
    final success = await MirrorApiService().applyPreset(preset.id);
    if (!mounted) return;
    if (success) {
      setState(() {
        for (final p in _presets) {
          p.isActive = p.id == preset.id;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${preset.name} ativado!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      // Demo mode — just switch locally
      setState(() {
        for (final p in _presets) {
          p.isActive = p.id == preset.id;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadPresets,
                color: AppTheme.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Presets', style: AppTheme.headingLarge),
                              SizedBox(height: 4),
                              Text('Save and switch between layouts', style: AppTheme.bodyMedium),
                            ],
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Active Preset card
                      if (_activePreset != null) ...[
                        const Text('Active Preset', style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        )),
                        const SizedBox(height: 10),
                        _ActivePresetCard(preset: _activePreset!),
                        const SizedBox(height: 28),
                      ],

                      // All Presets
                      const Text('All Presets', style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      )),
                      const SizedBox(height: 10),
                      ..._presets.map((p) => _PresetListItem(
                            preset: p,
                            onSwitch: p.isActive ? null : () => _applyPreset(p),
                          )),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: MirrorBottomNavBar(
        currentIndex: 3,
        onTap: widget.onNavigate,
      ),
    );
  }
}

// ─── Active Preset Card ───────────────────────────────────────────────────────

class _ActivePresetCard extends StatelessWidget {
  final PresetModel preset;
  const _ActivePresetCard({required this.preset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.presetActiveGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(preset.icon, color: Colors.white, size: 22),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            preset.name,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            preset.description,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text(
            '${preset.widgetCount} widgets configured',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Preset List Item ─────────────────────────────────────────────────────────

class _PresetListItem extends StatelessWidget {
  final PresetModel preset;
  final VoidCallback? onSwitch;

  const _PresetListItem({required this.preset, this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: preset.isActive ? AppTheme.primaryLight : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: preset.isActive ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: preset.isActive ? AppTheme.primary.withValues(alpha: 0.15) : AppTheme.iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(preset.icon,
                    color: preset.isActive ? AppTheme.primary : AppTheme.textSecondary,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(preset.name, style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    )),
                    const SizedBox(height: 3),
                    Text(preset.description, style: AppTheme.bodySmall, maxLines: 2),
                    const SizedBox(height: 3),
                    Text('${preset.widgetCount} widgets', style: AppTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: AppTheme.textMuted, size: 20),
                onPressed: () {},
              ),
            ],
          ),
          if (!preset.isActive && onSwitch != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSwitch,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: AppTheme.border),
                  foregroundColor: AppTheme.textPrimary,
                ),
                child: const Text(
                  'Switch to this preset',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
