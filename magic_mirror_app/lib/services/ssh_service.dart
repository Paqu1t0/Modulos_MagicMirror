import 'dart:convert';
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
    final socket = await SSHSocket.connect(_ip, 22, timeout: const Duration(seconds: 5));
    return SSHClient(
      socket,
      username: _user,
      onPasswordRequest: () => _pass,
    );
  }

  /// Executa um comando no Raspberry Pi e devolve o output (stdout).
  Future<String?> executeCommand(String command) async {
    try {
      final client = await _connect();
      final result = await client.run(command);
      client.close();
      return utf8.decode(result);
    } catch (e) {
      debugPrint('SSH Execute Error ($command): $e');
      return null;
    }
  }

  /// Reinicia fisicamente o Raspberry Pi.
  Future<bool> rebootPi() async {
    final result = await executeCommand('sudo reboot');
    return result != null;
  }

  /// Reinicia apenas o processo do MagicMirror (via pm2).
  Future<bool> restartMagicMirror() async {
    final result = await executeCommand('pm2 restart MagicMirror');
    return result != null;
  }

  // ─── Módulos ───────────────────────────────────────────────────────────────

  /// Instala um módulo via git clone na pasta de módulos do MagicMirror.
  /// [repoUrl] — URL do repositório GitHub, ex: https://github.com/user/MMM-Foo
  /// [moduleName] — nome da pasta, ex: MMM-Foo
  Future<bool> installModule(String repoUrl, String moduleName) async {
    final dir = '\$HOME/MagicMirror/modules/$moduleName';
    // Se já existir, não faz nada
    final check = await executeCommand('[ -d "$dir" ] && echo exists || echo notfound');
    if (check != null && check.trim() == 'exists') return true;

    final result = await executeCommand(
      'git clone --depth=1 "$repoUrl" "$dir" 2>&1',
    );
    if (result == null) return false;

    // Instalar dependências npm se existir package.json
    final npmResult = await executeCommand(
      '[ -f "$dir/package.json" ] && cd "$dir" && npm install --production 2>&1 || echo "no-npm"',
    );
    debugPrint('npm install: $npmResult');
    return true;
  }

  /// Remove um módulo da pasta de módulos do MagicMirror.
  Future<bool> removeModule(String moduleName) async {
    final dir = '\$HOME/MagicMirror/modules/$moduleName';
    final result = await executeCommand('rm -rf "$dir" 2>&1 && echo OK');
    return result != null && result.contains('OK');
  }

  /// Atualiza um módulo via git pull.
  Future<bool> updateModule(String moduleName) async {
    final dir = '\$HOME/MagicMirror/modules/$moduleName';
    final result = await executeCommand(
      'cd "$dir" && git pull 2>&1 && echo GIT_DONE',
    );
    if (result == null || !result.contains('GIT_DONE')) return false;

    // Re-instalar dependências se necessário
    await executeCommand(
      '[ -f "$dir/package.json" ] && cd "$dir" && npm install --production 2>&1 || true',
    );
    return true;
  }

  /// Devolve a lista dos nomes das pastas em ~/MagicMirror/modules (módulos instalados).
  Future<List<String>> listInstalledModuleNames() async {
    final result = await executeCommand(
      r"ls -1 $HOME/MagicMirror/modules 2>/dev/null | grep -v '^default$'",
    );
    if (result == null || result.trim().isEmpty) return [];
    return result.trim().split('\n').where((s) => s.isNotEmpty).toList();
  }

  // ─── Layout ────────────────────────────────────────────────────────────────

  /// Lê o config.js e devolve o layout actual agrupado por página.
  /// Retorna Map(page, Map(position, moduleName)).
  /// Se o módulo não tiver classes "pagina_X", é colocado na página 1.
  Future<Map<int, Map<String, String>>> fetchLayoutFromConfig() async {
    const script = r"""
const path = require('path');
const configPath = path.resolve(process.env.HOME || '/home/pi', 'MagicMirror/config/config.js');
try {
  const config = require(configPath);
  const result = { 1: {}, 2: {}, 3: {} };
  for (const m of config.modules) {
    const classes = m.classes || '';
    const pageMatch = classes.match(/pagina_([123])/);
    const page = pageMatch ? parseInt(pageMatch[1]) : 1;
    const pos = m.position || '';
    if (pos) {
      const posKey = pos.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
      result[page][posKey] = m.module;
    }
  }
  console.log(JSON.stringify({ data: result }));
} catch(e) {
  console.log(JSON.stringify({ error: e.toString() }));
}
""";

    final escaped = _escapeForNodeE(script);
    final result = await executeCommand('node -e "$escaped"');
    if (result != null && result.isNotEmpty) {
      try {
        final decoded = json.decode(result.trim());
        if (decoded['data'] != null) {
          final raw = decoded['data'] as Map<String, dynamic>;
          final layout = <int, Map<String, String>>{};
          raw.forEach((pageStr, positions) {
            final page = int.tryParse(pageStr) ?? 1;
            final posMap = <String, String>{};
            (positions as Map<String, dynamic>).forEach((pos, mod) {
              posMap[pos] = mod.toString();
            });
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
  Future<bool> updateMagicMirrorConfig(Map<int, Map<String, String>> pages) async {
    // Combinamos raw strings com interpolação para evitar escapes desnecessários
    final scriptPart1 = r"""
const fs = require('fs');
const path = require('path');
const configPath = path.resolve(process.env.HOME || '/home/pi', 'MagicMirror/config/config.js');
if (!fs.existsSync(configPath)) { console.log('Config not found'); process.exit(1); }
let configContent = fs.readFileSync(configPath, 'utf8');
const pagesData = """;
    final scriptPart2 = r""";
configContent = configContent.replace(/classes:\s*["']pagina_[0-9]+["']\s*,?/g, '');
for (const [pageStr, layout] of Object.entries(pagesData)) {
    for (const [position, moduleName] of Object.entries(layout)) {
        const regex = new RegExp('(module:\\s*["\']' + moduleName + '["\']\\s*,)');
        if (configContent.match(regex)) {
            const posFormatted = position.toLowerCase().replace(' ', '_');
            configContent = configContent.replace(regex, '$1\n    classes: "pagina_' + pageStr + '",\n    position: "' + posFormatted + '",');
        }
    }
}
fs.writeFileSync(configPath, configContent, 'utf8');
console.log('Config updated');
""";
    final script = scriptPart1 + json.encode(pages) + scriptPart2;

    final escaped = _escapeForNodeE(script);
    final result = await executeCommand('node -e "$escaped"');

    if (result != null && result.contains('Config updated')) {
      return await restartMagicMirror();
    }
    return false;
  }

  /// Busca os módulos diretamente do config.js no Pi usando SSH.
  Future<List<dynamic>> fetchRealModules() async {
    const script = r"""
const path = require('path');
const configPath = path.resolve(process.env.HOME || '/home/pi', 'MagicMirror/config/config.js');
try {
  const config = require(configPath);
  const modules = config.modules.map(m => ({
    id: m.module,
    name: m.module.replace('MMM-', ''),
    position: m.position || '',
    installed: true,
    classes: m.classes || ''
  }));
  console.log(JSON.stringify({data: modules}));
} catch(e) {
  console.log(JSON.stringify({error: e.toString()}));
}
""";

    final escaped = _escapeForNodeE(script);
    final result = await executeCommand('node -e "$escaped"');
    if (result != null && result.isNotEmpty) {
      try {
        final decoded = json.decode(result.trim());
        if (decoded['data'] != null) {
          return decoded['data'] as List<dynamic>;
        }
      } catch (e) {
        debugPrint('Failed to parse SSH modules: $e');
      }
    }
    return [];
  }

  /// Escapa um script JS para ser passado com `node -e "..."`.
  String _escapeForNodeE(String script) {
    return script
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');
  }
}
