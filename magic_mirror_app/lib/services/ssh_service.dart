import 'dart:convert';
import 'dart:typed_data';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SshService {
  static const String _prefKeyIp = 'mirror_ip';
  static const String _prefKeyUser = 'ssh_user';
  static const String _prefKeyPass = 'ssh_pass';

  String _ip = '192.168.1.100';
  String _user = 'pi';
  String _pass = 'raspberry';

  static final SshService _instance = SshService._internal();
  factory SshService() => _instance;
  SshService._internal();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _ip = prefs.getString(_prefKeyIp) ?? '192.168.1.100';
    _user = prefs.getString(_prefKeyUser) ?? 'pi';
    _pass = prefs.getString(_prefKeyPass) ?? '';
  }

  Future<void> saveConfig(String ip, String user, String pass) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyIp, ip);
    await prefs.setString(_prefKeyUser, user);
    await prefs.setString(_prefKeyPass, pass);
    _ip = ip;
    _user = user;
    _pass = pass;
  }

  Future<String> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyUser) ?? 'pi';
  }

  Future<String> getSavedPass() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKeyPass) ?? '';
  }

  Future<bool> testConnection() async {
    try {
      final client = await _connect();
      client.close();
      return true;
    } catch (e) {
      debugPrint('SSH Test Error: $e');
      return false;
    }
  }

  Future<SSHClient> _connect() async {
    final socket = await SSHSocket.connect(_ip, 22,
        timeout: const Duration(seconds: 8));
    return SSHClient(
      socket,
      username: _user,
      onPasswordRequest: () => _pass,
    );
  }

  /// Executa um comando simples e devolve stdout.
  Future<String?> executeCommand(String command) async {
    try {
      final client = await _connect();
      final result = await client.run(command);
      client.close();
      return utf8.decode(result);
    } catch (e) {
      debugPrint('SSH Execute Error: $e');
      return null;
    }
  }

  /// Corre um script Node.js enviando-o via stdin (node -)
  /// Evita todos os problemas de escaping de shell.
  Future<String?> _runNodeScript(String jsCode) async {
    try {
      final client = await _connect();
      // 'node -' lê o script do stdin — sem escaping de shell necessário
      final session = await client.execute('node -');
      session.stdin.add(Uint8List.fromList(utf8.encode(jsCode)));
      await session.stdin.close();

      final chunks = <int>[];
      await for (final chunk in session.stdout) {
        chunks.addAll(chunk);
      }
      client.close();
      final output = utf8.decode(chunks);
      debugPrint('Node script output: $output');
      return output.isNotEmpty ? output : null;
    } catch (e) {
      debugPrint('_runNodeScript error: $e');
      return null;
    }
  }

  // ─── Controlo ──────────────────────────────────────────────────────────────

  Future<bool> rebootPi() async {
    final result = await executeCommand('sudo reboot');
    return result != null;
  }

  Future<bool> restartMagicMirror() async {
    // Tenta pm2 primeiro, depois systemctl, depois npm start
    for (final cmd in [
      'pm2 restart MagicMirror',
      'systemctl restart magicmirror 2>/dev/null',
    ]) {
      final result = await executeCommand(cmd);
      if (result != null) return true;
    }
    return false;
  }

  // ─── Módulos instalados ────────────────────────────────────────────────────

  /// Lista os nomes das pastas em ~/MagicMirror/modules.
  /// Esta abordagem funciona sempre — não precisa de node.
  Future<List<String>> listInstalledModuleNames() async {
    final result = await executeCommand(
      r"ls -1 $HOME/MagicMirror/modules 2>/dev/null | grep -vE '^(default|node_modules|\..*)'",
    );
    if (result == null || result.trim().isEmpty) return [];
    return result.trim().split('\n').where((s) => s.isNotEmpty).toList();
  }

  /// Busca módulos instalados do Pi.
  /// Tenta 3 abordagens por ordem de confiança:
  ///   1. Node.js via stdin (dados completos com posição)
  ///   2. ls da pasta de módulos (só nomes, sem posição)
  Future<List<dynamic>> fetchRealModules() async {
    // ── Tentativa 1: Node.js via stdin ──────────────────────────────────────
    const jsScript = r"""
const path = require('path');
const fs = require('fs');
const home = process.env.HOME || '/home/pi';
const configPath = path.join(home, 'MagicMirror/config/config.js');
try {
  // Limpar cache para forçar releitura
  delete require.cache[require.resolve(configPath)];
  const config = require(configPath);
  const modules = (config.modules || []).map(m => ({
    id: m.module,
    name: m.module.replace(/^MMM-/, ''),
    description: '',
    position: m.position || '',
    installed: true,
    classes: m.classes || ''
  }));
  console.log(JSON.stringify({ ok: true, data: modules }));
} catch(e) {
  // Fallback: listar pastas
  const modDir = path.join(home, 'MagicMirror/modules');
  try {
    const dirs = fs.readdirSync(modDir).filter(d => d !== 'default' && !d.startsWith('.'));
    const modules = dirs.map(d => ({
      id: d,
      name: d.replace(/^MMM-/, ''),
      description: '',
      position: '',
      installed: true,
      classes: ''
    }));
    console.log(JSON.stringify({ ok: true, data: modules }));
  } catch(e2) {
    console.log(JSON.stringify({ ok: false, error: e2.toString() }));
  }
}
""";
    final nodeResult = await _runNodeScript(jsScript);
    if (nodeResult != null && nodeResult.isNotEmpty) {
      try {
        final decoded = json.decode(nodeResult.trim());
        if (decoded['ok'] == true && decoded['data'] != null) {
          return decoded['data'] as List<dynamic>;
        }
      } catch (e) {
        debugPrint('fetchRealModules node parse error: $e');
      }
    }

    // ── Tentativa 2: ls simples (sem node) ──────────────────────────────────
    debugPrint('fetchRealModules: node falhou, a usar ls');
    final names = await listInstalledModuleNames();
    if (names.isNotEmpty) {
      return names
          .map((n) => {
                'id': n,
                'name': n.replaceAll('MMM-', '').replaceAll('-', ' '),
                'description': '',
                'position': '',
                'installed': true,
                'classes': '',
              })
          .toList();
    }

    return [];
  }

  // ─── Layout ────────────────────────────────────────────────────────────────

  /// Lê o config.js e devolve o layout actual agrupado por página.
  Future<Map<int, Map<String, String>>> fetchLayoutFromConfig() async {
    const jsScript = r"""
const path = require('path');
const home = process.env.HOME || '/home/pi';
const configPath = path.join(home, 'MagicMirror/config/config.js');
try {
  delete require.cache[require.resolve(configPath)];
  const config = require(configPath);
  const result = { '1': {}, '2': {}, '3': {} };
  for (const m of (config.modules || [])) {
    const classes = m.classes || '';
    const pageMatch = classes.match(/pagina_([123])/);
    const page = pageMatch ? pageMatch[1] : '1';
    const pos = m.position || '';
    if (pos) {
      const posKey = pos.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
      result[page][posKey] = m.module;
    }
  }
  console.log(JSON.stringify({ ok: true, data: result }));
} catch(e) {
  console.log(JSON.stringify({ ok: false, error: e.toString() }));
}
""";
    final result = await _runNodeScript(jsScript);
    if (result != null && result.isNotEmpty) {
      try {
        final decoded = json.decode(result.trim());
        if (decoded['ok'] == true && decoded['data'] != null) {
          final raw = decoded['data'] as Map<String, dynamic>;
          final layout = <int, Map<String, String>>{};
          raw.forEach((pageStr, positions) {
            final page = int.tryParse(pageStr) ?? 1;
            final posMap = <String, String>{};
            (positions as Map<String, dynamic>)
                .forEach((pos, mod) => posMap[pos] = mod.toString());
            layout[page] = posMap;
          });
          return layout;
        }
      } catch (e) {
        debugPrint('fetchLayoutFromConfig parse error: $e');
      }
    }
    return {};
  }

  /// Atualiza o config.js para atribuir as classes de página aos módulos.
  Future<bool> updateMagicMirrorConfig(
      Map<int, Map<String, String>> pages) async {
    final pagesJson = json.encode(
        pages.map((k, v) => MapEntry(k.toString(), v)));

    final jsScript = """
const fs = require('fs');
const path = require('path');
const home = process.env.HOME || '/home/pi';
const configPath = path.join(home, 'MagicMirror/config/config.js');
if (!fs.existsSync(configPath)) {
  console.log(JSON.stringify({ ok: false, error: 'config not found' }));
  process.exit(1);
}
let content = fs.readFileSync(configPath, 'utf8');
const pages = $pagesJson;

// Remover classes pagina_X existentes
content = content.replace(/,?\\s*classes:\\s*["']pagina_[0-9]+["']/g, '');

for (const [pageNum, layout] of Object.entries(pages)) {
  for (const [position, moduleName] of Object.entries(layout)) {
    const posFormatted = position.toLowerCase().replace(/ /g, '_');
    // Procura a entrada do módulo e adiciona/substitui position e classes
    const modRe = new RegExp('(module:\\\\s*["\\'']' + moduleName.replace(/[.*+?^\${}()|[\\]\\\\]/g, '\\\\\$&') + '["\\'']\\\\s*,)', 'g');
    content = content.replace(modRe, '\$1\\n    position: "' + posFormatted + '",\\n    classes: "pagina_' + pageNum + '",');
  }
}

fs.writeFileSync(configPath, content, 'utf8');
console.log(JSON.stringify({ ok: true }));
""";
    final result = await _runNodeScript(jsScript);
    if (result != null) {
      try {
        final decoded = json.decode(result.trim());
        if (decoded['ok'] == true) return await restartMagicMirror();
      } catch (_) {}
    }
    return false;
  }

  // ─── Instalar / Remover / Atualizar ────────────────────────────────────────

  Future<bool> installModule(String repoUrl, String moduleName) async {
    final dir = r'$HOME' + '/MagicMirror/modules/$moduleName';
    final check =
        await executeCommand('[ -d "$dir" ] && echo exists || echo notfound');
    if (check != null && check.trim() == 'exists') return true;

    final clone = await executeCommand(
        'git clone --depth=1 "$repoUrl" "$dir" 2>&1 && echo GIT_OK');
    if (clone == null || !clone.contains('GIT_OK')) return false;

    await executeCommand(
        '[ -f "$dir/package.json" ] && cd "$dir" && npm install --production 2>&1 || true');
    return true;
  }

  Future<bool> removeModule(String moduleName) async {
    final dir = r'$HOME' + '/MagicMirror/modules/$moduleName';
    final result = await executeCommand('rm -rf "$dir" && echo RM_OK');
    return result != null && result.contains('RM_OK');
  }

  Future<bool> updateModule(String moduleName) async {
    final dir = r'$HOME' + '/MagicMirror/modules/$moduleName';
    final result =
        await executeCommand('cd "$dir" && git pull 2>&1 && echo GIT_DONE');
    if (result == null || !result.contains('GIT_DONE')) return false;
    await executeCommand(
        '[ -f "$dir/package.json" ] && cd "$dir" && npm install --production 2>&1 || true');
    return true;
  }
}
