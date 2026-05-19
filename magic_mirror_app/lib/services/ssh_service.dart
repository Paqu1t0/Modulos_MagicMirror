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

  static bool isTesting = false;

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
    if (isTesting) {
      throw Exception('SSH socket connections disabled in automated testing environment.');
    }
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
      // Encontra o node dinamicamente no Pi e lê o script do stdin
      final session = await client.execute(
        'if command -v node >/dev/null 2>&1; then node -; '
        'elif [ -s "\$HOME/.nvm/nvm.sh" ]; then . "\$HOME/.nvm/nvm.sh" && node -; '
        'elif [ -s "/usr/local/bin/node" ]; then /usr/local/bin/node -; '
        'elif [ -s "/usr/bin/node" ]; then /usr/bin/node -; '
        'else bash -l -c "node -"; fi'
      );
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

  Future<bool> setMonitorPower(bool turnOn) async {
    final cmd = turnOn
        ? 'export DISPLAY=:0 && (xset dpms force on || vcgencmd display_power 1 || wlr-randr --output HDMI-A-1 --on)'
        : 'export DISPLAY=:0 && (xset dpms force off || vcgencmd display_power 0 || wlr-randr --output HDMI-A-1 --off)';
    final result = await executeCommand(cmd);
    return result != null;
  }

  Future<bool> updatePowerCronSchedule({
    required bool enabled,
    required String offHour,
    required String offMinute,
    required String onHour,
    required String onMinute,
  }) async {
    try {
      final currentCron = await executeCommand('crontab -l 2>/dev/null || echo ""');
      String cronContent = currentCron ?? '';

      final startTag = '# MAGIC_MIRROR_POWER_START';
      final endTag = '# MAGIC_MIRROR_POWER_END';

      final String newBlock;
      if (enabled) {
        final offCronCmd = '$offMinute $offHour * * * export DISPLAY=:0 && (xset dpms force off || vcgencmd display_power 0 || wlr-randr --output HDMI-A-1 --off)';
        final onCronCmd = '$onMinute $onHour * * * export DISPLAY=:0 && (xset dpms force on || vcgencmd display_power 1 || wlr-randr --output HDMI-A-1 --on)';
        newBlock = '$startTag\n$offCronCmd\n$onCronCmd\n$endTag';
      } else {
        newBlock = '';
      }

      if (cronContent.contains(startTag) && cronContent.contains(endTag)) {
        final startIndex = cronContent.indexOf(startTag);
        final endIndex = cronContent.indexOf(endTag) + endTag.length;
        
        final before = cronContent.substring(0, startIndex);
        final after = cronContent.substring(endIndex);
        
        cronContent = '${before.trimRight()}\n\n$newBlock\n\n${after.trimLeft()}';
      } else {
        cronContent = '${cronContent.trimRight()}\n\n$newBlock\n';
      }

      cronContent = '${cronContent.trim()}\n';

      if (cronContent.trim().isEmpty) {
        await executeCommand('crontab -r 2>/dev/null || true');
        return true;
      }

      final encodedContent = base64Encode(utf8.encode(cronContent));
      final updateCmd = 'echo "$encodedContent" | base64 -d | crontab -';
      final result = await executeCommand(updateCmd);
      return result != null;
    } catch (e) {
      debugPrint('updatePowerCronSchedule Error: $e');
      return false;
    }
  }

  Future<bool> saveUltrasonicConfig({
    required double distanceLimit,
    required int activeSeconds,
  }) async {
    final configMap = {
      'DISTANCIA_LIMITE': distanceLimit,
      'TEMPO_PARA_DESLIGAR': activeSeconds,
    };
    final configJson = json.encode(configMap);
    
    final path = '\$HOME/MagicMirror/modules/MMM-Ultrasonic/config.json';
    final base64Content = base64Encode(utf8.encode(configJson));
    final cmd = 'echo "$base64Content" | base64 -d > $path && echo "WRITE_OK"';
    
    final result = await executeCommand(cmd);
    if (result == null || !result.contains('WRITE_OK')) {
      return false;
    }
    
    return await restartMagicMirror();
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
    
    // Se for módulo do sistema (sempre visível), coloca-o em todas as páginas
    const isAlwaysVisible = m.module === 'MMM-GestorPaginas' || m.module === 'MMM-Ultrasonic' || classes.includes('sempre_visivel');
    
    if (isAlwaysVisible) {
      const pos = m.position || '';
      if (pos) {
        const posKey = pos.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
        for (const p of ['1', '2', '3']) {
          if (result[p][posKey]) {
            result[p][posKey] = result[p][posKey] + ',' + m.module;
          } else {
            result[p][posKey] = m.module;
          }
        }
      }
      continue;
    }
    
    // Verifica se temos posições específicas para cada página
    const pgPosRe = /pagina_([123])_pos_([a-z_]+)/g;
    let match;
    let foundSpecific = false;
    while ((match = pgPosRe.exec(classes)) !== null) {
      const page = match[1];
      const pos = match[2];
      const posKey = pos.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
      if (result[page][posKey]) {
        result[page][posKey] = result[page][posKey] + ',' + m.module;
      } else {
        result[page][posKey] = m.module;
      }
      foundSpecific = true;
    }
    
    if (foundSpecific) continue;
    
    // Fallback: faz o parse das tags simples de página
    const pages = [];
    const pgRe = /pagina_([123])/g;
    let pgMatch;
    while ((pgMatch = pgRe.exec(classes)) !== null) {
      pages.push(pgMatch[1]);
    }
    if (pages.length === 0 && m.position) {
      pages.push('1');
    }
    const pos = m.position || '';
    if (pos) {
      const posKey = pos.split('_').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');
      for (const p of pages) {
        if (result[p][posKey]) {
          result[p][posKey] = result[p][posKey] + ',' + m.module;
        } else {
          result[p][posKey] = m.module;
        }
      }
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

    final jsScript = r"""
const fs = require('fs');
const path = require('path');
const home = process.env.HOME || '/home/pi';
const configPath = path.join(home, 'MagicMirror/config/config.js');

if (!fs.existsSync(configPath)) {
  console.log(JSON.stringify({ ok: false, error: 'config not found' }));
  process.exit(1);
}

let content = fs.readFileSync(configPath, 'utf8');
const pages = __PAGES_JSON__;

function findEnclosingObjectBounds(str, matchIndex) {
  let openBraceIndex = -1;
  let balance = 0;
  for (let i = matchIndex; i >= 0; i--) {
    if (str[i] === '}') {
      balance++;
    } else if (str[i] === '{') {
      if (balance === 0) {
        openBraceIndex = i;
        break;
      }
      balance--;
    }
  }
  if (openBraceIndex === -1) return null;

  balance = 1;
  let closeBraceIndex = -1;
  for (let i = openBraceIndex + 1; i < str.length; i++) {
    if (str[i] === '"' || str[i] === "'" || str[i] === '`') {
      const quote = str[i];
      i++;
      while (i < str.length && str[i] !== quote) {
        if (str[i] === '\\') i++;
        i++;
      }
      continue;
    }
    if (str[i] === '{') {
      balance++;
    } else if (str[i] === '}') {
      balance--;
      if (balance === 0) {
        closeBraceIndex = i;
        break;
      }
    }
  }
  return { start: openBraceIndex, end: closeBraceIndex };
}

// Parse blocks
const blocks = [];
const regex = /module\s*:\s*["']([^"']+)["']/g;
let match;
while ((match = regex.exec(content)) !== null) {
  const bounds = findEnclosingObjectBounds(content, match.index);
  if (bounds) {
    const objectStr = content.substring(bounds.start, bounds.end + 1);
    const isManaged = /classes\s*:\s*["'][^"']*pagina_[0-9]+[^"']*["']/.test(objectStr);
    blocks.push({
      name: match[1],
      start: bounds.start,
      end: bounds.end,
      isManaged: isManaged,
      newPlacements: [],
      newPosition: null,
      updated: false
    });
  }
}

// Find matching blocks for each module name
const blocksByName = {};
for (const block of blocks) {
  if (!blocksByName[block.name]) {
    blocksByName[block.name] = [];
  }
  blocksByName[block.name].push(block);
}

// Process each page and assign placements to matching physical blocks sequentially
for (const [pageNum, layout] of Object.entries(pages)) {
  const pageCounter = {};
  for (const [position, moduleNamesStr] of Object.entries(layout)) {
    const pos = position.toLowerCase().replace(/ /g, '_');
    const moduleNames = moduleNamesStr.split(',');
    for (const moduleName of moduleNames) {
      if (!pageCounter[moduleName]) {
        pageCounter[moduleName] = 0;
      }
      const blockIndex = pageCounter[moduleName];
      pageCounter[moduleName]++;

      const matchingBlocks = blocksByName[moduleName] || [];
      if (blockIndex < matchingBlocks.length) {
        const block = matchingBlocks[blockIndex];
        block.newPlacements.push({
          page: pageNum,
          pos: pos
        });
        if (!block.newPosition) {
          block.newPosition = pos;
        }
        block.updated = true;
      }
    }
  }
}

// For blocks not updated: if they were managed, remove their position and page class
for (const block of blocks) {
  if (!block.updated) {
    if (block.isManaged) {
      block.newPlacements = [];
      block.newPosition = null;
      block.updated = true;
    }
  }
}

// Sort back to front
blocks.sort((a, b) => b.start - a.start);

// Apply replacements
for (const block of blocks) {
  if (!block.updated) continue;
  
  let objectStr = content.substring(block.start, block.end + 1);
  
  // Remove existing position and classes
  objectStr = objectStr.replace(/,\s*position\s*:\s*["'].*?["']/g, '');
  objectStr = objectStr.replace(/position\s*:\s*["'].*?["']\s*,?/g, '');
  objectStr = objectStr.replace(/,\s*classes\s*:\s*["'].*?["']/g, '');
  objectStr = objectStr.replace(/classes\s*:\s*["'].*?["']\s*,?/g, '');
  
  if (block.newPosition && block.newPlacements && block.newPlacements.length > 0) {
    const classList = [];
    for (const pl of block.newPlacements) {
      classList.push(`pagina_${pl.page}`);
      classList.push(`pagina_${pl.page}_pos_${pl.pos}`);
    }
    const classStr = classList.join(' ');
    const newProps = `\n    position: "${block.newPosition}",\n    classes: "${classStr}",`;
    objectStr = objectStr.substring(0, 1) + newProps + objectStr.substring(1);
  }
  
  content = content.substring(0, block.start) + objectStr + content.substring(block.end + 1);
}

fs.writeFileSync(configPath, content, 'utf8');
console.log(JSON.stringify({ ok: true }));
""".replaceFirst('__PAGES_JSON__', pagesJson);

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
    final dir = '\$HOME/MagicMirror/modules/$moduleName';
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
    final dir = '\$HOME/MagicMirror/modules/$moduleName';
    final result = await executeCommand('rm -rf "$dir" && echo RM_OK');
    return result != null && result.contains('RM_OK');
  }

  Future<bool> updateModule(String moduleName) async {
    final dir = '\$HOME/MagicMirror/modules/$moduleName';
    final result =
        await executeCommand('cd "$dir" && git pull 2>&1 && echo GIT_DONE');
    if (result == null || !result.contains('GIT_DONE')) return false;
    await executeCommand(
        '[ -f "$dir/package.json" ] && cd "$dir" && npm install --production 2>&1 || true');
    return true;
  }
}
