import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mirror_status.dart';
import '../models/widget_model.dart';
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

  Future<MirrorStatus> getStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/status'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return MirrorStatus.fromJson(json.decode(response.body));
      }
    } catch (_) {}
    return MirrorStatus.offline;
  }

  // ─── Widgets / Modules ─────────────────────────────────────────────────────

  /// Busca módulos instalados no Mirror via MMM-Remote-Control.
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
    return demoWidgets;
  }

  /// Busca o catálogo público de módulos em magicmirror.builders.
  /// Não requer ligação ao Raspberry Pi.
  Future<List<WidgetModel>> getCatalogueModules() async {
    const catalogueUrl =
        'https://mmm-rest.david-van-laere.be/api/module';
    try {
      final response = await http
          .get(Uri.parse(catalogueUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final modules = data
            .map((e) => WidgetModel.fromCatalogueJson(e as Map<String, dynamic>))
            .toList();
        // Ordenar por popularidade (estrelas) descendente
        modules.sort((a, b) => b.stars.compareTo(a.stars));
        return modules;
      }
    } catch (_) {}
    return demoWidgets;
  }

  Future<bool> installModule(String moduleId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/modules/install'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'id': moduleId}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeModule(String moduleId) async {
    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/api/modules/$moduleId'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Layout ────────────────────────────────────────────────────────────────

  Future<bool> saveLayout(Map<String, String> positions) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/layout'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'positions': positions}),
          )
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
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
    try {
      final response = await http
          .post(Uri.parse('$_baseUrl/api/mirror/restart'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
