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
        return MirrorStatus.fromJson(json.decode(response.body));
      }
    } catch (_) {}

    // Fallback SSH
    final sshOk = await SshService().testConnection();
    if (sshOk) {
      return MirrorStatus(
        isOnline: true,
        wifiStrong: true,
        isPowered: true,
        isSynced: false,
        activeWidgets: 0,
        savedPresets: 0,
      );
    }

    return MirrorStatus.offline;
  }

  // ─── Widgets / Modules ─────────────────────────────────────────────────────

  /// Módulos instalados no Pi (via HTTP ou SSH fallback).
  Future<List<WidgetModel>> getModules() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/modules'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => WidgetModel.fromJson(e)).toList();
      }
    } catch (_) {}

    final sshModules = await SshService().fetchRealModules();
    if (sshModules.isNotEmpty) {
      return sshModules.map((m) => WidgetModel.fromJson(m)).toList();
    }

    return demoWidgets;
  }

  /// Catálogo público de módulos (não requer ligação ao Pi).
  Future<List<WidgetModel>> getCatalogueModules() async {
    const catalogueUrl = 'https://mmm-rest.david-van-laere.be/api/module';
    try {
      final response = await http
          .get(Uri.parse(catalogueUrl))
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
    return SshService().updateMagicMirrorConfig(pages);
  }

  /// Carrega o layout actual do Pi.
  Future<Map<int, Map<String, String>>> loadLayout() async {
    return SshService().fetchLayoutFromConfig();
  }

  // ─── Presets ───────────────────────────────────────────────────────────────

  Future<List<PresetModel>> getPresets() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/presets'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => PresetModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return demoPresets;
  }

  Future<bool> applyPreset(String presetId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/presets/apply'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'id': presetId}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
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
