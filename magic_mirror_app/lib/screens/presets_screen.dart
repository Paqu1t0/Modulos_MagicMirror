import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../models/preset_model.dart';
import '../services/mirror_api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'layout_screen.dart';


class PresetsScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final ValueNotifier<int>? activeTabNotifier;

  const PresetsScreen({
    super.key,
    required this.onNavigate,
    this.activeTabNotifier,
  });

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

class _PresetsScreenState extends State<PresetsScreen> {
  List<PresetModel> _presets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.activeTabNotifier?.addListener(_handleTabChange);
    _loadPresets();
  }

  @override
  void dispose() {
    widget.activeTabNotifier?.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    if (widget.activeTabNotifier?.value == 3 && mounted) {
      _loadPresets();
    }
  }


  Future<void> _loadPresets() async {
    setState(() => _loading = true);
    await _resetDefaultPresetsIfStale();
    final presets = await MirrorApiService().getPresets();
    if (mounted) setState(() { _presets = presets; _loading = false; });
  }

  /// Remove layouts desatualizados dos presets padrão (morning/afternoon/night)
  /// apenas uma vez, sem afetar alterações futuras feitas pelo utilizador.
  Future<void> _resetDefaultPresetsIfStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrated = prefs.getBool('presets_migrated_v3') ?? false;
      if (migrated) return;

      final savedStr = prefs.getString('saved_presets');
      if (savedStr != null) {
        final List<dynamic> data = json.decode(savedStr);
        const defaultIds = {'morning', 'afternoon', 'night'};
        
        final migratedPresets = data.map((item) {
          final id = (item as Map)['id'] as String? ?? '';
          if (defaultIds.contains(id)) {
            return <String, dynamic>{
              ...Map<String, dynamic>.from(item),
              'layout': null,
              'widgetCount': 0,
            };
          }
          return item; // Preserva os criados pelo utilizador
        }).toList();

        await prefs.setString('saved_presets', json.encode(migratedPresets));
      }
      await prefs.setBool('presets_migrated_v3', true);
    } catch (_) {}
  }


  PresetModel? get _activePreset {
    try {
      return _presets.firstWhere((p) => p.isActive);
    } catch (_) {
      return null;
    }
  }

  Future<void> _applyPreset(PresetModel preset) async {
    // Se o preset não tem layout configurado, mostrar diálogo de aviso
    if (preset.layout == null || preset.layout!.isEmpty ||
        preset.layout!.values.every((p) => p.isEmpty)) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Preset sem layout', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit_note, color: AppTheme.primary, size: 48),
              const SizedBox(height: 16),
              Text(
                'O preset "${preset.name}" ainda não tem um layout configurado.\n\n'
                'Toca no preset para abrir o editor de layout e adicionar os teus módulos.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _editPresetLayout(preset);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Configurar Layout', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _loading = true);
    final success = await MirrorApiService().applyPreset(preset.id);
    if (!mounted) return;
    setState(() => _loading = false);
    
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erro ao ativar preset via SSH.'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _showCreatePresetDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedIcon = 'sunny';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Criar Novo Preset', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nome', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'ex: Fim de Semana',
                        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Descrição', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      style: TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'ex: Fotos e música para relaxar',
                        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Escolher Ícone', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildIconOption(setStateDialog, 'sunny', Icons.wb_sunny, selectedIcon, (val) => selectedIcon = val),
                        _buildIconOption(setStateDialog, 'cloudy', Icons.wb_cloudy, selectedIcon, (val) => selectedIcon = val),
                        _buildIconOption(setStateDialog, 'night', Icons.nightlight_round, selectedIcon, (val) => selectedIcon = val),
                        _buildIconOption(setStateDialog, 'home', Icons.home, selectedIcon, (val) => selectedIcon = val),
                        _buildIconOption(setStateDialog, 'music', Icons.music_note, selectedIcon, (val) => selectedIcon = val),
                        _buildIconOption(setStateDialog, 'photo', Icons.photo, selectedIcon, (val) => selectedIcon = val),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Criar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && nameController.text.trim().isNotEmpty && mounted) {
      setState(() => _loading = true);

      final newPreset = PresetModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        description: descController.text.trim(),
        widgetCount: 0,
        iconName: selectedIcon,
        layout: {1: {}, 2: {}, 3: {}},
        isActive: false,
      );

      await MirrorApiService().savePreset(newPreset);
      await _loadPresets();

      // Abrir editor de layout imediatamente após criar
      if (mounted) {
        await _editPresetLayout(newPreset);
      }
    }
  }

  Widget _buildIconOption(StateSetter setStateDialog, String iconNameOption, IconData iconData, String currentSelected, Function(String) onSelect) {
    final isSelected = currentSelected == iconNameOption;
    return GestureDetector(
      onTap: () {
        setStateDialog(() {
          onSelect(iconNameOption);
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border, width: isSelected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(iconData, color: isSelected ? AppTheme.primary : AppTheme.textMuted, size: 18),
      ),
    );
  }

  Future<void> _editPresetLayout(PresetModel preset) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => LayoutScreen(
          onNavigate: widget.onNavigate,
          presetToEdit: preset,
        ),
      ),
    );
    if (result == true) {
      await _loadPresets();
    }
  }

  void _showPresetOptionsDialog(PresetModel preset) {
    final isDefault = preset.id == 'morning' || preset.id == 'afternoon' || preset.id == 'night';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            preset.name,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preset.description,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${preset.widgetCount} widgets configurados',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Opções do Preset:',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              
              // Option 1: Overwrite with Live Layout
              InkWell(
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => _loading = true);
                  final currentLayout = await MirrorApiService().loadLayout();
                  if (!mounted) return;
                  if (currentLayout.isNotEmpty) {
                    final unique = <String>{};
                    for (final page in currentLayout.values) {
                      for (final val in page.values) {
                        if (val.isNotEmpty) {
                          unique.addAll(val.split(','));
                        }
                      }
                    }
                    final updatedPreset = PresetModel(
                      id: preset.id,
                      name: preset.name,
                      description: preset.description,
                      widgetCount: unique.length,
                      iconName: preset.iconName,
                      layout: currentLayout,
                      isActive: preset.isActive,
                    );
                    await MirrorApiService().savePreset(updatedPreset);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Preset "${preset.name}" sobregravado com o layout live!'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Não foi possível obter o layout do espelho.'),
                        backgroundColor: AppTheme.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                  await _loadPresets();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.copy_outlined, color: AppTheme.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sobregravar com o layout live',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Guarda o layout do espelho neste preset',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              if (!isDefault) ...[
                const SizedBox(height: 12),
                // Option 2: Delete Preset
                InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _loading = true);
                    await MirrorApiService().deletePreset(preset.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Preset "${preset.name}" eliminado!'),
                        backgroundColor: AppTheme.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                    await _loadPresets();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: AppTheme.error.withValues(alpha: 0.05),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Eliminar Preset',
                            style: TextStyle(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Fechar', style: TextStyle(color: AppTheme.textMuted)),
            ),
          ],
        );
      },
    );
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
                            children: [
                              Text('Presets', style: AppTheme.headingLarge),
                              SizedBox(height: 4),
                              Text('Guarde e alterne entre layouts', style: AppTheme.bodyMedium),
                            ],
                          ),
                          GestureDetector(
                            onTap: _showCreatePresetDialog,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.add, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Active Preset card
                      if (_activePreset != null) ...[
                        Text('Preset Ativo', style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        )),
                        const SizedBox(height: 10),
                        _ActivePresetCard(
                          preset: _activePreset!,
                          onTap: () => _editPresetLayout(_activePreset!),
                          onLongPress: () => _showPresetOptionsDialog(_activePreset!),
                        ),
                        const SizedBox(height: 28),
                      ],

                      // All Presets
                      Text('Todos os Presets', style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      )),
                      const SizedBox(height: 10),
                      ..._presets.map((p) => _PresetListItem(
                            preset: p,
                            onSwitch: p.isActive ? null : () => _applyPreset(p),
                            onTap: () => _editPresetLayout(p),
                            onLongPress: () => _showPresetOptionsDialog(p),
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
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ActivePresetCard({
    required this.preset,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
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
                    'Ativo',
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
              '${preset.widgetCount} widgets configurados',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Preset List Item ─────────────────────────────────────────────────────────

class _PresetListItem extends StatelessWidget {
  final PresetModel preset;
  final VoidCallback? onSwitch;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _PresetListItem({
    required this.preset,
    this.onSwitch,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
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
                      Text(preset.name, style: TextStyle(
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
                    side: BorderSide(color: AppTheme.border),
                    foregroundColor: AppTheme.textPrimary,
                  ),
                  child: const Text(
                    'Ativar este preset',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}