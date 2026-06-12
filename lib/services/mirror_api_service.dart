import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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

  /// Módulos **configurados** no Pi (presentes no config.js ou via HTTP).
  /// Usado para a tab "No Mirror" — reflete o que está realmente a correr no espelho.
  /// NÃO inclui módulos que estão apenas na pasta mas não no config.js.
  Future<List<WidgetModel>> getModules({bool forceRefresh = false}) async {
    List<WidgetModel> rawModules = [];

    // 1. Tentar HTTP (MMM-Remote-Control)
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/modules'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        rawModules = data.map((e) => WidgetModel.fromJson(e)).toList();
      }
    } catch (_) {}

    // 2. Fallback SSH: lê o config.js (apenas módulos configurados)
    if (rawModules.isEmpty) {
      final sshRaw = await SshService().fetchRealModules(forceRefresh: forceRefresh);
      if (sshRaw.isNotEmpty) {
        rawModules = sshRaw.map((m) => WidgetModel.fromJson(m)).toList();
      }
    }

    // 3. Marcar todos como instalados (estão no config.js = configurados)
    for (final w in rawModules) {
      w.isInstalled = true;
    }

    if (rawModules.isEmpty) {
      rawModules = demoWidgets;
    }

    return _deduplicateModules(rawModules);
  }

  /// Todos os módulos instalados no Pi (configurados + pasta apenas).
  /// Usado para a tab "No Mirror" da Loja e para o LayoutScreen.
  Future<List<WidgetModel>> getAllInstalledModules({bool forceRefresh = false}) async {
    // Começa com os módulos configurados
    final configured = await getModules(forceRefresh: forceRefresh);
    final configuredIds = configured.map((w) => w.id).toSet();

    // Adiciona módulos que estão na pasta mas não no config.js
    final folderNames = await SshService().listInstalledModuleNames(forceRefresh: forceRefresh);
    final extra = <WidgetModel>[];

    // Carrega o catálogo em fallback para obter info ricas (descrição, categoria, etc.)
    final catalogue = await getCatalogueModules();
    final catMap = {for (var w in catalogue) w.id.toLowerCase(): w};

    for (final folderName in folderNames) {
      if (!configuredIds.contains(folderName)) {
        final displayName = folderName
            .replaceAll('MMM-', '')
            .replaceAll('-', ' ');
            
        final idLower = folderName.toLowerCase();
        final match = catMap[idLower] ?? catMap[idLower.replaceAll('mmm-', '')];

        extra.add(WidgetModel(
          id: folderName,
          name: match?.name ?? displayName,
          description: match?.description ?? 'Módulo instalado — disponível para configurar',
          category: match?.category ?? 'Geral',
          icon: match?.icon ?? Icons.extension,
          isInstalled: true,
          author: match?.author,
          repoUrl: match?.repoUrl,
          imageUrl: match?.imageUrl,
          isArchived: match?.isArchived ?? false,
          outdated: match?.outdated,
        ));
      }
    }

    return [...configured, ...extra];
  }


  /// Catálogo público de módulos (não requer ligação ao Pi).
  /// Os nossos módulos próprios são sempre injetados no início do catálogo.
  Future<List<WidgetModel>> getCatalogueModules() async {
    const catalogueUrl = 'https://modules.magicmirror.builders/data/modules.json';
    const fallbackUrl = 'https://mmm-rest.david-van-laere.be/api/module';

    // Módulos próprios — estão sempre presentes independentemente da ligação
    final ours = demoWidgets.where((w) => w.isOurs).toList();

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
        // Remove do catálogo público qualquer módulo com o mesmo ID que os nossos
        // (garante que o nosso GoogleCalendar, etc., sempre aparece em vez do de terceiros)
        final ourIds = ours.map((o) => o.id.toLowerCase()).toSet();
        final filteredModules = modules.where((m) => !ourIds.contains(m.id.toLowerCase())).toList();
        return [...ours, ...filteredModules];
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
        final ourIds = ours.map((o) => o.id.toLowerCase()).toSet();
        final filteredModules = modules.where((m) => !ourIds.contains(m.id.toLowerCase())).toList();
        return [...ours, ...filteredModules];
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

  /// Remove um módulo via SSH e limpa-o de todos os presets locais.
  Future<bool> removeModule(String moduleId) async {
    final success = await SshService().removeModule(moduleId);
    if (success) {
      // Limpar este módulo de todos os layouts dos presets guardados
      try {
        final presets = await getPresets();
        bool changedAny = false;
        
        for (int i = 0; i < presets.length; i++) {
          final preset = presets[i];
          if (preset.layout == null) continue;
          
          bool presetChanged = false;
          final newLayout = Map<int, Map<String, String>>.from(preset.layout!);
          final unique = <String>{};
          
          for (final page in newLayout.keys.toList()) {
            final pageMap = Map<String, String>.from(newLayout[page] ?? {});
            for (final pos in pageMap.keys.toList()) {
              final widgets = pageMap[pos]!.split(',');
              final initialLength = widgets.length;
              
              widgets.removeWhere((id) => id.split('#')[0] == moduleId);
              
              if (widgets.length != initialLength) {
                presetChanged = true;
                if (widgets.isEmpty) {
                  pageMap.remove(pos);
                } else {
                  pageMap[pos] = widgets.join(',');
                }
              }
              
              if (widgets.isNotEmpty) {
                unique.addAll(widgets);
              }
            }
            newLayout[page] = pageMap;
          }
          
          if (presetChanged) {
            presets[i] = preset.copyWith(layout: newLayout, widgetCount: unique.length);
            changedAny = true;
          }
        }
        
        if (changedAny) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('saved_presets', json.encode(presets.map((p) => p.toJson()).toList()));
          await _savePresetsToPi(presets);
        }
      } catch (e) {
        debugPrint('Erro a limpar o módulo dos presets: $e');
      }
    }
    return success;
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
    
    final configs = await getAllModuleConfigs();
    return SshService().updateMagicMirrorConfig(cleanPages, moduleConfigs: configs);
  }

  /// Carrega o layout actual do Pi.
  Future<Map<int, Map<String, String>>> loadLayout({bool forceRefresh = false}) async {
    final rawLayout = await SshService().fetchLayoutFromConfig(forceRefresh: forceRefresh);
    return deduplicateLayout(rawLayout);
  }

  // ─── Module Advanced Configurations ────────────────────────────────────────

  Future<String?> getModuleConfig(String moduleId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('config_$moduleId');
    } catch (_) {}
    return null;
  }

  Future<bool> saveModuleConfig(String moduleId, String jsonConfig) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('config_$moduleId', jsonConfig);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> getAllModuleConfigs() async {
    final Map<String, String> configs = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('config_')) {
          final moduleId = key.substring('config_'.length);
          final configStr = prefs.getString(key);
          if (configStr != null && configStr.isNotEmpty) {
            configs[moduleId] = configStr;
          }
        }
      }
    } catch (_) {}
    return configs;
  }

  Future<Map<String, dynamic>?> getModuleDefaults(String moduleId) async {
    return SshService().fetchModuleDefaults(moduleId);
  }

  Future<String?> getModuleReadme(String moduleId) async {
    return SshService().fetchModuleReadme(moduleId);
  }

  Future<Map<String, dynamic>?> getCurrentModuleConfig(String moduleId) async {
    return SshService().fetchCurrentModuleConfig(moduleId);
  }

  Future<bool> uploadModuleFile(String moduleId, String fileName, Uint8List bytes, {String? subfolder}) async {
    return SshService().uploadFile(moduleId, fileName, bytes, subfolder: subfolder);
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

  Future<bool> changePage(String acao) async {
    debugPrint('changePage: Iniciar alteração de página com ação: $acao');
    
    // 1. MMM-Remote-Control API (porta 8080) — funciona sem necessidade de atualizar o Pi
    try {
      final url = '$_baseUrl/api/notification/BOTAO_PRESSIONADO';
      debugPrint('changePage: A tentar MMM-Remote-Control via HTTP: $url');
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'acao': acao
            }),
          )
          .timeout(const Duration(seconds: 5));
      debugPrint('changePage: Resposta MMM-Remote-Control: status=${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('changePage: Sucesso via MMM-Remote-Control');
        return true;
      }
    } catch (e) {
      debugPrint('changePage: Erro no MMM-Remote-Control: $e');
    }

    final localPayload = jsonEncode({'acao': acao});

    // 2. Servidor HTTP do node_helper (porta 8765) — requer node_helper atualizado no Pi
    try {
      final ip = await getSavedIp();
      final url = 'http://$ip:8765/pagina';
      debugPrint('changePage: A tentar HTTP no node_helper: $url');
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: localPayload,
          )
          .timeout(const Duration(seconds: 5));
      debugPrint('changePage: Resposta node_helper HTTP: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 200) {
        debugPrint('changePage: Sucesso via node_helper HTTP');
        return true;
      }
    } catch (e) {
      debugPrint('changePage: Erro no node_helper HTTP: $e');
    }

    // 3. SSH: envia o curl directamente no Pi (funciona sempre que haja SSH)
    try {
      debugPrint('changePage: A tentar via SSH curl...');
      final cmd =
          "curl -s -X POST http://127.0.0.1:8765/pagina "
          "-H 'Content-Type: application/json' "
          "-d '$localPayload'";
      debugPrint('changePage: SSH comando: $cmd');
      final result = await SshService().executeCommand(cmd);
      debugPrint('changePage: Resposta SSH: $result');
      if (result != null && result.contains('"ok":true')) {
        debugPrint('changePage: Sucesso via SSH');
        return true;
      }
    } catch (e) {
      debugPrint('changePage: Erro no SSH curl: $e');
    }

    debugPrint('changePage: Todos os métodos para mudar de página falharam.');
    return false;
  }
}
