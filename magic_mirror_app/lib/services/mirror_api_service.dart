import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mirror_status.dart';
import '../models/widget_model.dart';
import 'ssh_service.dart';
import '../models/preset_model.dart';

class MirrorApiService {
  static const String _prefKeyIp = 'mirror_ip';
  static const String _prefKeyPort = 'mirror_port';
  static const String _defaultPort = '8080';

  String _baseUrl = '';

  static final MirrorApiService _instance = MirrorApiService._internal();
  factory MirrorApiService() => _instance;
  MirrorApiService._internal();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString(_prefKeyIp) ?? '192.168.1.100';
    final port = prefs.getString(_prefKeyPort) ?? _defaultPort;
    _baseUrl = 'http://$ip:$port';
  }

  Future<void> saveConfig(String ip, String port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyIp, ip);
    await prefs.setString(_prefKeyPort, port);
    _baseUrl = 'http://$ip:$port';
  }

  Future<String> getSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyIp) ?? '192.168.1.100';
  }

  Future<String> getSavedPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyPort) ?? _defaultPort;
  }

  // ─── Status ────────────────────────────────────────────────────────────────

  /// Tenta contactar o Pi via HTTP (MMM-Remote-Control) para obter o status.
  /// Fallback: tenta SSH. Se ambos falharem, devolve offline.
  Future<MirrorStatus> getStatus() async {
    // Tenta HTTP (MMM-Remote-Control)
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/status'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        int activeCount = data['activeWidgets'] as int? ?? 0;
        if (activeCount == 0) {
          try {
            final layout = await loadLayout();
            final uniqueWidgets = <String>{};
            for (final pageLayout in layout.values) {
              for (final val in pageLayout.values) {
                if (val.isNotEmpty) {
                  uniqueWidgets.addAll(val.split(','));
                }
              }
            }
            activeCount = uniqueWidgets.length;
          } catch (_) {}
        }
        
        int presetsCount = data['savedPresets'] as int? ?? 0;
        if (presetsCount == 0) {
          try {
            final presets = await getPresets();
            presetsCount = presets.length;
          } catch (_) {}
        }

        return MirrorStatus(
          isOnline: true,
          wifiStrong: data['wifi'] as bool? ?? true,
          isPowered: data['powered'] as bool? ?? true,
          isSynced: data['synced'] as bool? ?? true,
          activeWidgets: activeCount,
          savedPresets: presetsCount,
        );
      }
    } catch (_) {}

    // Fallback SSH
    final sshOk = await SshService().testConnection();
    if (sshOk) {
      int activeWidgetsCount = 0;
      try {
        final layout = await SshService().fetchLayoutFromConfig();
        final uniqueWidgets = <String>{};
        for (final pageLayout in layout.values) {
          for (final val in pageLayout.values) {
            if (val.isNotEmpty) {
              uniqueWidgets.addAll(val.split(','));
            }
          }
        }
        activeWidgetsCount = uniqueWidgets.length;
      } catch (_) {}

      int presetsCount = 0;
      try {
        final presets = await getPresets();
        presetsCount = presets.length;
      } catch (_) {}

      return MirrorStatus(
        isOnline: true,
        wifiStrong: true,
        isPowered: true,
        isSynced: true,
        activeWidgets: activeWidgetsCount,
        savedPresets: presetsCount,
      );
    }

    return MirrorStatus.offline;
  }

  List<WidgetModel> _deduplicateModules(List<WidgetModel> modules) {
    final Map<String, int> counts = {};
    final List<WidgetModel> result = [];
    
    for (final w in modules) {
      final id = w.id;
      
      // Aplicar a deduplicação APENAS ao módulo "weather"
      if (id == 'weather') {
        final count = counts[id] ?? 0;
        counts[id] = count + 1;
        
        if (count == 0) {
          result.add(WidgetModel(
            id: id,
            name: 'Weather (Tempo Atual)',
            description: w.description,
            category: w.category,
            icon: w.icon,
            author: w.author,
            repoUrl: w.repoUrl,
            stars: w.stars,
            isInstalled: w.isInstalled,
            position: w.position,
          ));
        } else {
          final instanceName = count == 1 ? 'Weather (Previsão 7 Dias)' : 'Weather (Instância ${count + 1})';
          result.add(WidgetModel(
            id: '$id#$count',
            name: instanceName,
            description: w.description,
            category: w.category,
            icon: w.icon,
            author: w.author,
            repoUrl: w.repoUrl,
            stars: w.stars,
            isInstalled: w.isInstalled,
            position: w.position,
          ));
        }
      } else {
        // Outros módulos mantêm-se inalterados
        result.add(w);
      }
    }
    return result;
  }

  Map<int, Map<String, String>> deduplicateLayout(Map<int, Map<String, String>> layout) {
    final Map<String, int> counts = {};
    final Map<int, Map<String, String>> result = {};
    
    for (int page = 1; page <= 3; page++) {
      final pageMap = layout[page] ?? {};
      final newPageMap = <String, String>{};
      
      for (final entry in pageMap.entries) {
        final pos = entry.key;
        final widgets = entry.value.split(',');
        final newWidgets = <String>[];
        
        for (final widgetId in widgets) {
          if (widgetId.isEmpty) continue;
          
          final cleanId = widgetId.split('#')[0];
          
          // Aplicar deduplicação APENAS ao "weather"
          if (cleanId == 'weather') {
            final count = counts[cleanId] ?? 0;
            counts[cleanId] = count + 1;
            
            if (count == 0) {
              newWidgets.add(cleanId);
            } else {
              newWidgets.add('$cleanId#$count');
            }
          } else {
            // Outros módulos usam o ID limpo normal
            newWidgets.add(cleanId);
          }
        }
        newPageMap[pos] = newWidgets.join(',');
      }
      result[page] = newPageMap;
    }
    return result;
  }

  /// Módulos instalados no Pi (via HTTP ou SSH fallback).
  Future<List<WidgetModel>> getModules() async {
    List<WidgetModel> rawModules = [];
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/modules'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        rawModules = data.map((e) => WidgetModel.fromJson(e)).toList();
      }
    } catch (_) {}

    if (rawModules.isEmpty) {
      final sshModules = await SshService().fetchRealModules();
      if (sshModules.isNotEmpty) {
        rawModules = sshModules.map((m) => WidgetModel.fromJson(m)).toList();
      }
    }

    if (rawModules.isEmpty) {
      rawModules = demoWidgets;
    }

    return _deduplicateModules(rawModules);
  }

  /// Catálogo público de módulos (não requer ligação ao Pi).
  Future<List<WidgetModel>> getCatalogueModules() async {
    const catalogueUrl = 'https://modules.magicmirror.builders/data/modules.json';
    const fallbackUrl = 'https://mmm-rest.david-van-laere.be/api/module';
    
    try {
      final response = await http
          .get(Uri.parse(catalogueUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(response.body);
        final List<dynamic> data = body['modules'] as List<dynamic>;
        final modules = data
            .map((e) => WidgetModel.fromCatalogueJson(e as Map<String, dynamic>))
            .toList();
        modules.sort((a, b) => b.stars.compareTo(a.stars));
        return modules;
      }
    } catch (_) {}

    try {
      final response = await http
          .get(Uri.parse(fallbackUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final modules = data
            .map((e) => WidgetModel.fromCatalogueJson(e as Map<String, dynamic>))
            .toList();
        modules.sort((a, b) => b.stars.compareTo(a.stars));
        return modules;
      }
    } catch (_) {}

    return demoWidgets;
  }

  // ─── Install / Remove / Update via SSH ─────────────────────────────────────

  /// Instala um módulo via SSH (git clone). Requer repoUrl.
  Future<bool> installModule(String moduleId, {String? repoUrl}) async {
    final url = repoUrl ?? 'https://github.com/MagicMirrorOrg/$moduleId';
    return SshService().installModule(url, moduleId);
  }

  /// Remove um módulo via SSH.
  Future<bool> removeModule(String moduleId) async {
    return SshService().removeModule(moduleId);
  }

  /// Atualiza um módulo via SSH (git pull).
  Future<bool> updateModule(String moduleId) async {
    return SshService().updateModule(moduleId);
  }

  // ─── Layout ────────────────────────────────────────────────────────────────

  /// Guarda o layout via SSH (atualiza config.js + reinicia).
  Future<bool> saveLayout(Map<int, Map<String, String>> pages) async {
    final cleanPages = <int, Map<String, String>>{};
    
    for (final entry in pages.entries) {
      final pageNum = entry.key;
      final cleanPageMap = <String, String>{};
      
      for (final posEntry in entry.value.entries) {
        final pos = posEntry.key;
        final widgets = posEntry.value.split(',');
        final cleanWidgets = widgets.map((id) => id.split('#')[0]).toList();
        cleanPageMap[pos] = cleanWidgets.join(',');
      }
      cleanPages[pageNum] = cleanPageMap;
    }
    
    return SshService().updateMagicMirrorConfig(cleanPages);
  }

  /// Carrega o layout actual do Pi.
  Future<Map<int, Map<String, String>>> loadLayout() async {
    final rawLayout = await SshService().fetchLayoutFromConfig();
    return deduplicateLayout(rawLayout);
  }

  // ─── Presets ───────────────────────────────────────────────────────────────

  Future<List<PresetModel>> getPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('saved_presets');
      if (savedStr != null && savedStr.isNotEmpty) {
        final List<dynamic> data = json.decode(savedStr);
        return data.map((e) => PresetModel.fromJson(e)).toList();
      }
    } catch (_) {}

    // Sem presets locais. Tentamos descarregar o backup guardado no Pi.
    final piPresets = await _loadPresetsFromPi();
    if (piPresets != null && piPresets.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_presets', json.encode(piPresets.map((p) => p.toJson()).toList()));
      } catch (_) {}
      return piPresets;
    }

    // Inicializar os presets padrão se não existirem localmente nem no Pi
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_presets', json.encode(defaultPresets.map((p) => p.toJson()).toList()));
    } catch (_) {}

    return defaultPresets;
  }

  Future<bool> applyPreset(String presetId) async {
    final presets = await getPresets();
    PresetModel? preset;
    try {
      preset = presets.firstWhere((p) => p.id == presetId);
    } catch (_) {}

    if (preset != null && preset.layout != null && preset.layout!.isNotEmpty) {
      final success = await saveLayout(preset.layout!);
      if (success) {
        for (final p in presets) {
          p.isActive = (p.id == presetId);
        }
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_presets', json.encode(presets.map((p) => p.toJson()).toList()));
          await _savePresetsToPi(presets);
        } catch (_) {}
        return true;
      }
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/presets/apply'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'id': presetId}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        for (final p in presets) {
          p.isActive = (p.id == presetId);
        }
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_presets', json.encode(presets.map((p) => p.toJson()).toList()));
          await _savePresetsToPi(presets);
        } catch (_) {}
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> savePreset(PresetModel preset) async {
    final presets = await getPresets();
    
    // Se o preset a ser guardado está ativo, desativamos os outros todos
    if (preset.isActive) {
      for (final p in presets) {
        p.isActive = (p.id == preset.id);
      }
    }
    
    final index = presets.indexWhere((p) => p.id == preset.id);
    if (index != -1) {
      presets[index] = preset;
    } else {
      presets.add(preset);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_presets', json.encode(presets.map((p) => p.toJson()).toList()));
      // Envia backup para o Pi
      await _savePresetsToPi(presets);
    } catch (_) {}
  }

  Future<void> deletePreset(String presetId) async {
    final presets = await getPresets();
    presets.removeWhere((p) => p.id == presetId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_presets', json.encode(presets.map((p) => p.toJson()).toList()));
      // Envia backup para o Pi
      await _savePresetsToPi(presets);
    } catch (_) {}
  }

  // ─── Sincronização SSH dos Presets no Pi ───────────────────────────────────

  Future<void> _savePresetsToPi(List<PresetModel> presets) async {
    try {
      final presetsJson = json.encode(presets.map((p) => p.toJson()).toList());
      final base64Content = base64Encode(utf8.encode(presetsJson));
      final cmd = 'echo "$base64Content" | base64 -d > ~/MagicMirror/presets.json';
      await SshService().executeCommand(cmd);
    } catch (_) {}
  }

  Future<List<PresetModel>?> _loadPresetsFromPi() async {
    try {
      final result = await SshService().executeCommand('cat ~/MagicMirror/presets.json 2>/dev/null');
      if (result != null && result.trim().isNotEmpty) {
        final List<dynamic> data = json.decode(result.trim());
        return data.map((e) => PresetModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return null;
  }


  // ─── Mirror Control ────────────────────────────────────────────────────────

  Future<bool> restartMirror() async {
    // Tenta HTTP primeiro (MMM-Remote-Control)
    try {
      final response = await http
          .post(Uri.parse('$_baseUrl/api/mirror/restart'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return true;
    } catch (_) {}
    // Fallback SSH
    return SshService().restartMagicMirror();
  }
}
