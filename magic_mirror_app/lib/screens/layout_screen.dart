import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/widget_model.dart';
import '../models/preset_model.dart';
import '../services/mirror_api_service.dart';
import '../widgets/bottom_nav_bar.dart';


class LayoutScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final PresetModel? presetToEdit;
  final ValueNotifier<int>? activeTabNotifier;

  const LayoutScreen({
    super.key,
    required this.onNavigate,
    this.presetToEdit,
    this.activeTabNotifier,
  });

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
    widget.activeTabNotifier?.addListener(_handleTabChange);
    _loadAll();
  }

  @override
  void dispose() {
    widget.activeTabNotifier?.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    // Se navegamos para a aba de Layout (índice 2)
    if (widget.activeTabNotifier?.value == 2 && mounted && widget.presetToEdit == null) {
      _loadAll();
    }
  }


  void _propagateAlwaysVisibleModules({bool fromLoading = false}) {
    // 1. Determinar qual a página de referência para a posição do Gestor
    int referencePage = fromLoading ? 1 : _currentPage;
    
    // Se a página de referência não tem o gestor mas outra tem (no carregamento), procuramos
    if (fromLoading) {
      bool found = false;
      for (int p = 1; p <= 3; p++) {
        for (final val in (_layouts[p] ?? {}).values) {
          if (val.split(',').contains('MMM-GestorPaginas')) {
            referencePage = p;
            found = true;
            break;
          }
        }
        if (found) break;
      }
    }

    // 2. Achar a posição do 'MMM-GestorPaginas' na página de referência
    String? targetPosition;
    final refLayout = _layouts[referencePage] ?? {};
    for (final entry in refLayout.entries) {
      if (entry.value.split(',').contains('MMM-GestorPaginas')) {
        targetPosition = entry.key;
        break;
      }
    }

    // 3. Limpar o 'MMM-GestorPaginas' de todas as posições em todas as páginas
    for (int p = 1; p <= 3; p++) {
      final pageLayout = _layouts[p];
      if (pageLayout == null) continue;
      
      final keys = List<String>.from(pageLayout.keys);
      for (final key in keys) {
        final val = pageLayout[key] ?? '';
        final widgets = val.split(',')..remove('MMM-GestorPaginas');
        widgets.removeWhere((id) => id.isEmpty);
        
        if (widgets.isEmpty) {
          pageLayout.remove(key);
        } else {
          pageLayout[key] = widgets.join(',');
        }
      }
    }

    // 4. Se ele deve estar numa posição, adicioná-lo nessa posição em todas as 3 páginas
    if (targetPosition != null) {
      for (int p = 1; p <= 3; p++) {
        _layouts[p] ??= {};
        final pageLayout = _layouts[p]!;
        final val = pageLayout[targetPosition] ?? '';
        final widgets = val.isEmpty ? <String>[] : val.split(',');
        
        if (!widgets.contains('MMM-GestorPaginas')) {
          widgets.add('MMM-GestorPaginas');
          if (widgets.length > 2) {
            widgets.removeAt(0); // Garante no máximo 2 widgets por slot
          }
          pageLayout[targetPosition] = widgets.join(',');
        }
      }
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loadingWidgets = true);

    if (widget.presetToEdit != null) {
      // Modo editar preset — carrega módulos e usa layout do preset
      final modules = await MirrorApiService().getAllInstalledModules();
      if (mounted) {
        setState(() {
          _installedWidgets = modules.where((w) => w.isInstalled).toList();
          final presetLayout = widget.presetToEdit!.layout;
          if (presetLayout != null && presetLayout.isNotEmpty) {
            _layouts = MirrorApiService().deduplicateLayout(presetLayout);
          } else {
            _layouts = {1: {}, 2: {}, 3: {}};
          }
          _propagateAlwaysVisibleModules(fromLoading: true);
          _loadingWidgets = false;
        });
      }
      return;
    }

    // Modo layout principal — carrega módulos e verifica preset ativo
    final results = await Future.wait([
      MirrorApiService().getAllInstalledModules(),
      MirrorApiService().getPresets(),
      MirrorApiService().loadLayout(),
    ]);

    final modules = results[0] as List<WidgetModel>;
    final presets = results[1] as List<PresetModel>;
    final liveLayout = results[2] as Map<int, Map<String, String>>;

    if (mounted) {
      setState(() {
        _installedWidgets = modules.where((w) => w.isInstalled).toList();

        // Verificar se há preset ativo com layout configurado
        PresetModel? activePreset;
        try {
          activePreset = presets.firstWhere(
            (p) => p.isActive && p.layout != null && p.layout!.isNotEmpty &&
                   p.layout!.values.any((page) => page.isNotEmpty),
          );
        } catch (_) {
          activePreset = null;
        }

        if (activePreset != null) {
          // Usar o layout do preset ativo
          _layouts = MirrorApiService().deduplicateLayout(activePreset.layout!);
        } else if (liveLayout.isNotEmpty) {
          // Layout real do Pi (sem preset ativo ou preset sem layout)
          _layouts = {
            1: Map<String, String>.from(liveLayout[1] ?? {}),
            2: Map<String, String>.from(liveLayout[2] ?? {}),
            3: Map<String, String>.from(liveLayout[3] ?? {}),
          };
        } else {
          // Fallback demo se não conseguir ler do Pi
          _layouts = {
            1: {'Top Left': 'clock', 'Top Right': 'weather', 'Bottom Center': 'news'},
            2: {'Center': 'calendar'},
            3: {'Bottom Right': 'photos'},
          };
        }
        _propagateAlwaysVisibleModules(fromLoading: true);
        _loadingWidgets = false;
      });
    }
  }

  int get _currentPage => _tabController.index + 1;

  List<WidgetModel> _widgetsAt(String position) {
    final val = _layouts[_currentPage]?[position];
    if (val == null || val.isEmpty) return [];

    final ids = val.split(',');
    final list = <WidgetModel>[];
    final available = _installedWidgets.isEmpty ? demoWidgets : _installedWidgets;
    for (final id in ids) {
      try {
        final w = available.firstWhere((w) => w.id == id);
        list.add(WidgetModel(
          id: w.id,
          name: w.name,
          description: w.description,
          category: w.category,
          icon: w.icon,
          position: position,
        ));
      } catch (_) {
        try {
          final w = demoWidgets.firstWhere((w) => w.id == id);
          list.add(WidgetModel(
            id: w.id,
            name: w.name,
            description: w.description,
            category: w.category,
            icon: w.icon,
            position: position,
          ));
        } catch (_) {
          list.add(WidgetModel(
            id: id,
            name: id,
            description: '',
            category: 'General',
            icon: Icons.extension,
            position: position,
          ));
        }
      }
    }
    return list;
  }

  List<WidgetModel> get _activeWidgetsForCurrentPage {
    final result = <WidgetModel>[];
    final pageLayout = _layouts[_currentPage] ?? {};
    for (final entry in pageLayout.entries) {
      final list = _widgetsAt(entry.key);
      result.addAll(list);
    }
    return result;
  }

  // Abre picker para escolher um widget a colocar num slot vazio
  Future<void> _pickWidgetForSlot(String position, {bool append = false}) async {
    final available = _installedWidgets.isEmpty ? demoWidgets : _installedWidgets;
    final activeIds = _activeWidgetsForCurrentPage.map((w) => w.id).toList();

    final chosen = await showModalBottomSheet<WidgetModel>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _WidgetPickerSheet(
        position: position,
        widgets: available,
        activeWidgetIds: activeIds,
      ),
    );

    if (chosen != null && mounted) {
      setState(() {
        final currentVal = _layouts[_currentPage]?[position] ?? '';
        final currentIds = currentVal.isEmpty ? <String>[] : currentVal.split(',');

        if (append) {
          // Permite duplicados (como colocar dois do mesmo tipo "weather" no mesmo slot)
          currentIds.add(chosen.id);
        } else {
          currentIds.clear();
          currentIds.add(chosen.id);
        }

        // Garante no máximo 2 widgets
        if (currentIds.length > 2) {
          currentIds.removeAt(0);
        }

        _layouts[_currentPage] ??= {};
        _layouts[_currentPage]![position] = currentIds.join(',');
        _propagateAlwaysVisibleModules();
      });
    }
  }

  // Opções ao tocar numa célula ocupada
  void _onOccupiedCellTap(String position, List<WidgetModel> widgets) {
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Slot: $position',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
              ),
              const Divider(),
              if (widgets.length < 2)
                ListTile(
                  leading: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                  title: const Text('Adicionar segundo widget neste slot'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickWidgetForSlot(position, append: true);
                  },
                ),
              ...widgets.map((w) => ListTile(
                    leading: Icon(w.icon, color: AppTheme.primary),
                    title: Text('Remover ${w.name}'),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        final ids = _layouts[_currentPage]?[position]?.split(',') ?? [];
                        ids.remove(w.id);
                        if (ids.isEmpty) {
                          _layouts[_currentPage]?.remove(position);
                        } else {
                          _layouts[_currentPage]![position] = ids.join(',');
                        }
                        _propagateAlwaysVisibleModules();
                      });
                    },
                  )),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.error),
                title: const Text('Limpar Slot Completo', style: TextStyle(color: AppTheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _layouts[_currentPage]?.remove(position);
                    _propagateAlwaysVisibleModules();
                  });
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
    
    if (widget.presetToEdit != null) {
      final unique = <String>{};
      for (final page in _layouts.values) {
        for (final val in page.values) {
          if (val.isNotEmpty) {
            unique.addAll(val.split(','));
          }
        }
      }
      
      final updated = PresetModel(
        id: widget.presetToEdit!.id,
        name: widget.presetToEdit!.name,
        description: widget.presetToEdit!.description,
        widgetCount: unique.length,
        iconName: widget.presetToEdit!.iconName,
        layout: Map<int, Map<String, String>>.from(_layouts),
        isActive: widget.presetToEdit!.isActive,
      );
      
      await MirrorApiService().savePreset(updated);
      
      // Se for o preset selecionado (ativo), altera também o layout no espelho!
      bool syncSuccess = true;
      if (updated.isActive) {
        syncSuccess = await MirrorApiService().saveLayout(_layouts);
      }
      
      if (mounted) setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updated.isActive && !syncSuccess
                ? 'Preset "${widget.presetToEdit!.name}" guardado, mas falhou a sincronizar com o espelho.'
                : 'Preset "${widget.presetToEdit!.name}" guardado com sucesso!'
            ),
            backgroundColor: updated.isActive && !syncSuccess ? AppTheme.warning : AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } else {
      final success = await MirrorApiService().saveLayout(_layouts);
      
      // Se houver um preset ativo, atualizá-lo para refletir o novo layout real
      if (success) {
        try {
          final presets = await MirrorApiService().getPresets();
          final activeIndex = presets.indexWhere((p) => p.isActive);
          if (activeIndex != -1) {
            final activePreset = presets[activeIndex];
            
            final unique = <String>{};
            for (final page in _layouts.values) {
              for (final val in page.values) {
                if (val.isNotEmpty) {
                  unique.addAll(val.split(','));
                }
              }
            }
            
            final updatedPreset = activePreset.copyWith(
              layout: Map<int, Map<String, String>>.from(_layouts),
              widgetCount: unique.length,
            );
            
            await MirrorApiService().savePreset(updatedPreset);
          }
        } catch (e) {
          debugPrint('Falha ao atualizar o preset ativo: $e');
        }
      }

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
  }

  Future<void> _saveAsPreset() async {
    setState(() => _saving = true);
    final presets = await MirrorApiService().getPresets();
    if (mounted) setState(() => _saving = false);

    if (!mounted) return;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                alignment: Alignment.center,
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Guardar como Preset',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add_box_outlined, color: AppTheme.primary),
                title: const Text('Criar Novo Preset'),
                subtitle: const Text('Cria um preset personalizado com este layout'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCreatePresetFromLayoutDialog();
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Text(
                  'Ou sobregravar um preset existente:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: presets.length,
                  itemBuilder: (context, index) {
                    final preset = presets[index];
                    return ListTile(
                      leading: Icon(preset.icon, color: AppTheme.primary),
                      title: Text(preset.name),
                      subtitle: Text(preset.description),
                      onTap: () {
                        Navigator.pop(ctx);
                        _overwritePresetWithCurrentLayout(preset);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _overwritePresetWithCurrentLayout(PresetModel preset) async {
    setState(() => _saving = true);

    final unique = <String>{};
    for (final page in _layouts.values) {
      for (final val in page.values) {
        if (val.isNotEmpty) {
          unique.addAll(val.split(','));
        }
      }
    }

    final updated = PresetModel(
      id: preset.id,
      name: preset.name,
      description: preset.description,
      widgetCount: unique.length,
      iconName: preset.iconName,
      layout: Map<int, Map<String, String>>.from(_layouts),
      isActive: preset.isActive,
    );

    await MirrorApiService().savePreset(updated);
    
    // Se for o preset selecionado (ativo), altera também o layout no espelho!
    bool syncSuccess = true;
    if (updated.isActive) {
      syncSuccess = await MirrorApiService().saveLayout(_layouts);
    }

    if (mounted) setState(() => _saving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isActive && !syncSuccess
              ? 'Preset "${preset.name}" atualizado, mas falhou a sincronizar com o espelho.'
              : 'Preset "${preset.name}" atualizado com o layout atual!'
          ),
          backgroundColor: updated.isActive && !syncSuccess ? AppTheme.warning : AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _showCreatePresetFromLayoutDialog() async {
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
              title: const Text('Criar Preset do Layout', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nome', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'ex: Fim de Semana',
                        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Descrição', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'ex: Fotos e música para relaxar',
                        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                        filled: true,
                        fillColor: AppTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Escolher Ícone', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildIconOptionForLayout(setStateDialog, 'sunny', Icons.wb_sunny, selectedIcon, (val) => selectedIcon = val),
                        _buildIconOptionForLayout(setStateDialog, 'cloudy', Icons.wb_cloudy, selectedIcon, (val) => selectedIcon = val),
                        _buildIconOptionForLayout(setStateDialog, 'night', Icons.nightlight_round, selectedIcon, (val) => selectedIcon = val),
                        _buildIconOptionForLayout(setStateDialog, 'home', Icons.home, selectedIcon, (val) => selectedIcon = val),
                        _buildIconOptionForLayout(setStateDialog, 'music', Icons.music_note, selectedIcon, (val) => selectedIcon = val),
                        _buildIconOptionForLayout(setStateDialog, 'photo', Icons.photo, selectedIcon, (val) => selectedIcon = val),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
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
      setState(() => _saving = true);

      final unique = <String>{};
      for (final page in _layouts.values) {
        for (final val in page.values) {
          if (val.isNotEmpty) {
            unique.addAll(val.split(','));
          }
        }
      }

      final newPreset = PresetModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: nameController.text.trim(),
        description: descController.text.trim(),
        widgetCount: unique.length,
        iconName: selectedIcon,
        layout: Map<int, Map<String, String>>.from(_layouts),
        isActive: true, // Já é criado e selecionado (ativo) automaticamente
      );

      await MirrorApiService().savePreset(newPreset);
      // Sincroniza logo o novo layout com o Magic Mirror via SSH
      final syncSuccess = await MirrorApiService().saveLayout(_layouts);
      
      if (mounted) setState(() => _saving = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              syncSuccess
                ? 'Preset "${newPreset.name}" criado, ativado e enviado para o espelho!'
                : 'Preset "${newPreset.name}" criado localmente, mas falhou ao enviar para o espelho.'
            ),
            backgroundColor: syncSuccess ? AppTheme.success : AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'Ver Presets',
              textColor: Colors.white,
              onPressed: () {
                // Navegar para o tab de Presets (index 3)
                widget.onNavigate(3);
              },
            ),
          ),
        );
      }
    }
  }

  Widget _buildIconOptionForLayout(StateSetter setStateDialog, String iconNameOption, IconData iconData, String currentSelected, Function(String) onSelect) {
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
                      if (widget.presetToEdit != null) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                          onPressed: () => Navigator.of(context).pop(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.presetToEdit != null ? 'Editar Preset' : 'Layout Editor',
                              style: AppTheme.headingLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.presetToEdit != null
                                  ? 'Preset: ${widget.presetToEdit!.name}'
                                  : 'Toca num slot para adicionar um widget',
                              style: AppTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (widget.presetToEdit == null)
                            IconButton(
                              onPressed: _loadAll,
                              icon: const Icon(Icons.refresh, color: AppTheme.textMuted),
                              tooltip: 'Recarregar do Pi',
                            ),
                          if (widget.presetToEdit == null)
                            IconButton(
                              onPressed: _saveAsPreset,
                              icon: const Icon(Icons.bookmark_add_outlined, color: AppTheme.primary),
                              tooltip: 'Guardar como Preset',
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
                              tooltip: widget.presetToEdit != null ? 'Guardar Preset' : 'Guardar layouts',
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
      bottomNavigationBar: widget.presetToEdit != null
          ? null
          : MirrorBottomNavBar(
              currentIndex: 2,
              onTap: widget.onNavigate,
            ),
    );
  }

  Widget _buildGridCell(String position, double heightFactor) {
    final list = _widgetsAt(position);
    final cell = SizedBox(
      height: 70 * heightFactor,
      child: _LayoutCell(
        position: position,
        widgets: list,
        onTap: list.isNotEmpty
            ? () => _onOccupiedCellTap(position, list)
            : () => _pickWidgetForSlot(position),
      ),
    );

    final dragTarget = DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != position,
      onAcceptWithDetails: (details) {
        final sourcePosition = details.data;
        setState(() {
          final sourceWidgetId = _layouts[_currentPage]?[sourcePosition];
          final targetWidgetId = _layouts[_currentPage]?[position];

          if (sourceWidgetId != null) {
            if (targetWidgetId != null) {
              _layouts[_currentPage]![sourcePosition] = targetWidgetId;
              _layouts[_currentPage]![position] = sourceWidgetId;
            } else {
              _layouts[_currentPage]!.remove(sourcePosition);
              _layouts[_currentPage]![position] = sourceWidgetId;
            }
          }
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: cell,
        );
      },
    );

    if (list.isNotEmpty) {
      return Draggable<String>(
        data: position,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 120,
            height: 70 * heightFactor,
            child: Opacity(
              opacity: 0.8,
              child: _LayoutCell(
                position: position,
                widgets: list,
              ),
            ),
          ),
        ),
        childWhenDragging: SizedBox(
          height: 70 * heightFactor,
          child: Opacity(
            opacity: 0.3,
            child: _LayoutCell(
              position: position,
              widgets: list,
            ),
          ),
        ),
        child: dragTarget,
      );
    }

    return dragTarget;
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

          // Custom MagicMirror Grid layout
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.cardDecoration,
            child: Column(
              children: [
                _buildGridCell('Top Bar', 0.8),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildGridCell('Top Left', 1.0)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildGridCell('Top Center', 1.0)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildGridCell('Top Right', 1.0)),
                  ],
                ),
                const SizedBox(height: 10),
                _buildGridCell('Upper Third', 0.8),
                const SizedBox(height: 10),
                _buildGridCell('Middle Center', 0.8),
                const SizedBox(height: 10),
                _buildGridCell('Lower Third', 0.8),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildGridCell('Bottom Left', 1.0)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildGridCell('Bottom Center', 1.0)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildGridCell('Bottom Right', 1.0)),
                  ],
                ),
                const SizedBox(height: 10),
                _buildGridCell('Bottom Bar', 0.8),
              ],
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
                  onRemove: () => setState(() {
                    final pos = w.position;
                    if (pos != null) {
                      final ids = _layouts[_currentPage]?[pos]?.split(',') ?? [];
                      ids.remove(w.id);
                      if (ids.isEmpty) {
                        _layouts[_currentPage]?.remove(pos);
                      } else {
                        _layouts[_currentPage]![pos] = ids.join(',');
                      }
                    }
                  }),
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
  final List<WidgetModel> widgets;
  final VoidCallback? onTap;

  const _LayoutCell({required this.position, required this.widgets, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOccupied = widgets.isNotEmpty;
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
              ? (widgets.length == 1
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widgets[0].icon, color: AppTheme.primary, size: 18),
                        const SizedBox(height: 4),
                        Text(
                          widgets[0].name,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(widgets[0].icon, color: AppTheme.primary, size: 12),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widgets[0].name,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                  textAlign: TextAlign.left,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(widgets[1].icon, color: AppTheme.primary, size: 12),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widgets[1].name,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                  textAlign: TextAlign.left,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, color: AppTheme.textMuted, size: 18),
                    const SizedBox(height: 2),
                    Text(
                      position,
                      style: AppTheme.bodySmall.copyWith(fontSize: 10),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
  final List<String> activeWidgetIds;

  const _WidgetPickerSheet({
    required this.position,
    required this.widgets,
    required this.activeWidgetIds,
  });

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

    // 1. Contar quantas vezes cada ID já foi adicionado na página
    final activeCounts = <String, int>{};
    for (final id in widget.activeWidgetIds) {
      activeCounts[id] = (activeCounts[id] ?? 0) + 1;
    }

    // 2. Pré-calcular se cada elemento na lista filtered já deve aparecer como "ativo"
    final seenCounts = <String, int>{};
    final isUsedList = <bool>[];
    for (final w in filtered) {
      final id = w.id;
      final seen = seenCounts[id] ?? 0;
      seenCounts[id] = seen + 1;
      
      final totalActive = activeCounts[id] ?? 0;
      isUsedList.add(seen < totalActive);
    }

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
              Text('Adicionar a "${widget.position}"', style: AppTheme.headingMedium),
              const SizedBox(height: 12),
              // Search
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: TextField(
                  autofocus: false,
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
              final isActive = isUsedList[i];

              return Opacity(
                opacity: isActive ? 0.4 : 1.0,
                child: ListTile(
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
                  subtitle: Text(
                    isActive ? 'Já adicionado nesta página' : w.category,
                    style: TextStyle(
                      color: isActive ? AppTheme.error : AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  trailing: isActive
                      ? const Icon(Icons.check_circle, color: AppTheme.success)
                      : const Icon(Icons.add_circle_outline, color: AppTheme.primary),
                  onTap: isActive ? null : () => Navigator.pop(context, w),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
