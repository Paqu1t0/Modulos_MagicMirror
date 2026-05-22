import 'dart:convert';
import 'dart:io';
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

  /// Inicia uma shell interactiva
  Future<SSHSession?> startInteractiveShell() async {
    try {
      // Connect to the Pi
      final client = await _connect();
      // Wait for a shell
      final session = await client.shell();
      // It's the caller's responsibility to close the session/client.
      return session;
    } catch (e) {
      debugPrint('SSH Interactive Shell Error: $e');
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
    // wlr-randr via SSH requer XDG_RUNTIME_DIR e WAYLAND_DISPLAY explícitos.
    // wayland-0 é o valor correto no Raspberry Pi OS Bookworm (confirmado no sensor.py).
    // Tenta por ordem: wlr-randr (Wayland) → swaymsg → xset dpms (X11) → vcgencmd (legado)
    final String action = turnOn ? 'on' : 'off';
    final String dpmsAction = turnOn ? 'on' : 'off';
    final String xsetAction = turnOn ? 'force on' : 'force off';
    final String vcgAction = turnOn ? '1' : '0';

    final cmd = 'export XDG_RUNTIME_DIR=/run/user/1000; '
        'export WAYLAND_DISPLAY=wayland-0; '
        '(wlr-randr --output HDMI-A-1 --$action 2>/dev/null'
        ' || wlr-randr --output HDMI-1 --$action 2>/dev/null'
        ' || swaymsg "output * dpms $dpmsAction" 2>/dev/null'
        ' || (export DISPLAY=:0 && xset dpms $xsetAction) 2>/dev/null'
        ' || vcgencmd display_power $vcgAction 2>/dev/null'
        ')';

    // O ; echo CMD_SENT confirma que o SSH executou (independente do método que funcionou)
    final result = await executeCommand('$cmd ; echo CMD_SENT');
    return result != null && result.contains('CMD_SENT');
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
      // Cron corre sem ambiente Wayland — todas as vars têm de ser definidas inline
      final offCronCmd = '$offMinute $offHour * * * '
          'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 '
          'wlr-randr --output HDMI-A-1 --off 2>/dev/null || '
          'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 '
          'swaymsg "output * dpms off" 2>/dev/null || '
          'vcgencmd display_power 0 2>/dev/null';
      final onCronCmd = '$onMinute $onHour * * * '
          'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 '
          'wlr-randr --output HDMI-A-1 --on 2>/dev/null || '
          'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 '
          'swaymsg "output * dpms on" 2>/dev/null || '
          'vcgencmd display_power 1 2>/dev/null';
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
    // Escreve config.json na pasta do módulo no Pi.
    // O novo sensor.py relê este ficheiro automaticamente a cada ~10s.
    // Formato: { "DISTANCIA_LIMITE": 200.0, "TEMPO_PARA_DESLIGAR": 30 }
    final configMap = {
      'DISTANCIA_LIMITE': distanceLimit,
      'TEMPO_PARA_DESLIGAR': activeSeconds,
    };
    final configJson = json.encode(configMap);
    final base64Content = base64Encode(utf8.encode(configJson));

    // Path fixo — o módulo foi instalado pelo utilizador nesta localização
    const modulePath = r'$HOME/MagicMirror/modules/MMM-Ultrasonic';
    final writeCmd =
        'echo "$base64Content" | base64 -d > $modulePath/config.json && echo "WRITE_OK"';

    final writeResult = await executeCommand(writeCmd);
    if (writeResult == null || !writeResult.contains('WRITE_OK')) {
      debugPrint('saveUltrasonicConfig: falhou a escrever config.json');
      return false;
    }

    // Matar o processo sensor.py em execução para que o node_helper o reinicie
    // imediatamente com os novos valores (em vez de esperar os ~10s de reload automático).
    // pkill não falha se o processo não existir (-0 exit code ignorado).
    await executeCommand('pkill -f sensor.py 2>/dev/null || true');

    return true;
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
    const isAlwaysVisible = m.module === 'MMM-GestorPaginas' || classes.includes('sempre_visivel');
    
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
  /// Se um módulo não existe ainda no config.js, insere-o automaticamente.
  Future<bool> updateMagicMirrorConfig(
      Map<int, Map<String, String>> pages, {
      Map<String, String>? moduleConfigs,
  }) async {
    final pagesJson = json.encode(
        pages.map((k, v) => MapEntry(k.toString(), v)));
    
    // Converte de JSON strings back to raw maps to inject into node script
    final parsedConfigs = <String, dynamic>{};
    if (moduleConfigs != null) {
      moduleConfigs.forEach((key, val) {
        try {
          parsedConfigs[key] = json.decode(val);
        } catch (_) {}
      });
    }
    final configsJson = json.encode(parsedConfigs);

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
const configs = __CONFIGS_JSON__;

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

// Parse existing blocks
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

// Collect all unique module names that appear in the desired layout
const allLayoutModules = {};
for (const [pageNum, layout] of Object.entries(pages)) {
  for (const [position, moduleNamesStr] of Object.entries(layout)) {
    const pos = position.toLowerCase().replace(/ /g, '_');
    const moduleNames = moduleNamesStr.split(',');
    for (const moduleName of moduleNames) {
      if (!moduleName) continue;
      if (!allLayoutModules[moduleName]) {
        allLayoutModules[moduleName] = [];
      }
      allLayoutModules[moduleName].push({ page: pageNum, pos });
    }
  }
}

// Process each page and assign placements to matching physical blocks sequentially
for (const [pageNum, layout] of Object.entries(pages)) {
  const pageCounter = {};
  for (const [position, moduleNamesStr] of Object.entries(layout)) {
    const pos = position.toLowerCase().replace(/ /g, '_');
    const moduleNames = moduleNamesStr.split(',');
    for (const moduleName of moduleNames) {
      if (!moduleName) continue;
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
      // If blockIndex >= matchingBlocks.length, this module doesn't exist in config.js yet
      // We'll handle new inserts below
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

// Sort back to front for replacements
blocks.sort((a, b) => b.start - a.start);

// Apply replacements to existing blocks
for (const block of blocks) {
  if (!block.updated) continue;
  
  let objectStr = content.substring(block.start, block.end + 1);
  
  // Remove existing position and classes
  objectStr = objectStr.replace(/,\s*position\s*:\s*["'].*?["']/g, '');
  objectStr = objectStr.replace(/position\s*:\s*["'].*?["']\s*,?/g, '');
  objectStr = objectStr.replace(/,\s*classes\s*:\s*["'].*?["']/g, '');
  objectStr = objectStr.replace(/classes\s*:\s*["'].*?["']\s*,?/g, '');
  
  // Se existir uma configuração customizada para este módulo, remover o config antigo
  if (configs[block.name]) {
    const configMatch = /config\s*:\s*\{/.exec(objectStr);
    if (configMatch) {
      // configMatch.index + configMatch[0].length - 1 is the index of '{'
      const bounds = findEnclosingObjectBounds(objectStr, configMatch.index + configMatch[0].length - 1);
      if (bounds) {
        let startIdx = configMatch.index;
        let endIdx = bounds.end + 1;
        while(endIdx < objectStr.length && (objectStr[endIdx] === ' ' || objectStr[endIdx] === '\n' || objectStr[endIdx] === '\r')) endIdx++;
        if (objectStr[endIdx] === ',') endIdx++;
        objectStr = objectStr.substring(0, startIdx) + objectStr.substring(endIdx);
      }
    }
  }
  
  if (block.newPosition && block.newPlacements && block.newPlacements.length > 0) {
    const classList = [];
    for (const pl of block.newPlacements) {
      classList.push(`pagina_${pl.page}`);
      classList.push(`pagina_${pl.page}_pos_${pl.pos}`);
    }
    const classStr = classList.join(' ');
    
    let configProp = "";
    if (configs[block.name]) {
      const cfgStr = JSON.stringify(configs[block.name], null, 2).split('\n').map(l => '    ' + l).join('\n').trim();
      configProp = `\n    config: ${cfgStr},`;
    }
    
    const newProps = `\n    position: "${block.newPosition}",\n    classes: "${classStr}",${configProp}`;
    objectStr = objectStr.substring(0, 1) + newProps + objectStr.substring(1);
  }
  
  content = content.substring(0, block.start) + objectStr + content.substring(block.end + 1);
}

// INSERT new modules that don't exist in config.js yet
// Find all modules in the desired layout that have no block in config.js
const existingNames = new Set(blocks.map(b => b.name));
const modulesToInsert = [];

for (const [moduleName, placements] of Object.entries(allLayoutModules)) {
  if (!existingNames.has(moduleName)) {
    // This module is new — build a combined placement entry
    const combinedPlacements = placements;
    const firstPos = combinedPlacements[0].pos;
    const classList = [];
    for (const pl of combinedPlacements) {
      classList.push(`pagina_${pl.page}`);
      classList.push(`pagina_${pl.page}_pos_${pl.pos}`);
    }
    const classStr = classList.join(' ');
    modulesToInsert.push({
      name: moduleName,
      pos: firstPos,
      classStr: classStr
    });
  }
}

if (modulesToInsert.length > 0) {
  // Find the closing bracket of the modules array: last ']' before the closing '};' of config
  // Strategy: find 'modules:' then find its array's closing ']'
  const modulesMatch = /modules\s*:\s*\[/.exec(content);
  if (modulesMatch) {
    let depth = 0;
    let arrayStart = modulesMatch.index + modulesMatch[0].length - 1; // index of '['
    let arrayEnd = -1;
    for (let i = arrayStart; i < content.length; i++) {
      if (content[i] === '[') depth++;
      else if (content[i] === ']') {
        depth--;
        if (depth === 0) {
          arrayEnd = i;
          break;
        }
      }
    }
    if (arrayEnd !== -1) {
      // Build the new module blocks string
      let insertStr = '';
      for (const m of modulesToInsert) {
        let configProp = "";
        if (configs[m.name]) {
          const cfgStr = JSON.stringify(configs[m.name], null, 2).split('\n').map(l => '      ' + l).join('\n').trim();
          configProp = `\n      config: ${cfgStr},`;
        }
        insertStr += `\n    {\n      module: "${m.name}",\n      position: "${m.pos}",\n      classes: "${m.classStr}",${configProp}\n    },`;
      }
      // Insert before the closing ']'
      content = content.substring(0, arrayEnd) + insertStr + '\n  ' + content.substring(arrayEnd);
    }
  }
}

fs.writeFileSync(configPath, content, 'utf8');
console.log(JSON.stringify({ ok: true, inserted: modulesToInsert.length }));
"""
        .replaceFirst('__PAGES_JSON__', pagesJson)
        .replaceFirst('__CONFIGS_JSON__', configsJson);

    // Run via tmp file to avoid bash escaping issues over SSH
    await executeCommand("cat << 'EOF' > /tmp/update_magicmirror_config.js\n$jsScript\nEOF");
    final result = await executeCommand("node /tmp/update_magicmirror_config.js");

    if (result != null) {
      try {
        final decoded = json.decode(result.trim());
        if (decoded['ok'] == true) return await restartMagicMirror();
      } catch (_) {}
    }
    return false;
  }

  Future<Map<String, dynamic>?> fetchModuleDefaults(String moduleName) async {
    final jsScript = r"""
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const home = process.env.HOME || '/home/pi';
const moduleFile = path.join(home, 'MagicMirror/modules/__MODULE_NAME__/__MODULE_NAME__.js');

if (!fs.existsSync(moduleFile)) {
  console.log(JSON.stringify({ error: 'file_not_found' }));
  process.exit(0);
}

const content = fs.readFileSync(moduleFile, 'utf8');

const match = /defaults\s*:\s*\{/.exec(content);
if (match) {
  let openBraceIndex = match.index + match[0].length - 1;
  let balance = 1;
  let closeBraceIndex = -1;
  for (let i = openBraceIndex + 1; i < content.length; i++) {
    if (content[i] === '"' || content[i] === "'" || content[i] === '`') {
      const quote = content[i]; i++;
      while (i < content.length && content[i] !== quote) {
        if (content[i] === '\\') i++; i++;
      }
      continue;
    }
    if (content[i] === '{') { balance++; } 
    else if (content[i] === '}') {
      balance--;
      if (balance === 0) { closeBraceIndex = i; break; }
    }
  }
  
  if (closeBraceIndex !== -1) {
      const defaultsBlock = content.substring(openBraceIndex, closeBraceIndex + 1);
      try {
          const context = {};
          vm.createContext(context);
          const parsed = vm.runInContext('(' + defaultsBlock + ')', context);
          console.log(JSON.stringify({ ok: true, defaults: parsed }));
          process.exit(0);
      } catch(e) {
          console.log(JSON.stringify({ error: 'vm_parse_error', details: e.toString() }));
          process.exit(0);
      }
  }
}
console.log(JSON.stringify({ error: 'no_defaults_found' }));
""".replaceAll('__MODULE_NAME__', moduleName);

    await executeCommand("cat << 'EOF' > /tmp/fetch_defaults.js\n$jsScript\nEOF");
    final result = await executeCommand("node /tmp/fetch_defaults.js");
    if (result != null) {
      try {
        final decoded = json.decode(result.trim());
        if (decoded['ok'] == true && decoded['defaults'] != null) {
          return decoded['defaults'] as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    return null;
  }

  /// Busca a configuração "viva" de um módulo diretamente do config.js
  Future<Map<String, dynamic>?> fetchCurrentModuleConfig(String moduleName) async {
    final jsScript = """
const fs = require('fs');
const path = require('path');
const configPath = path.resolve(process.env.HOME || '/home/pi', 'MagicMirror/config/config.js');
try {
  const content = fs.readFileSync(configPath, 'utf8');
  const m = { exports: {} };
  const wrapper = new Function('module', 'process', '__dirname', 'require', content + '; return (typeof config !== "undefined") ? config : module.exports;');
  const configObj = wrapper(m, process, path.dirname(configPath), require);
  
  if (configObj && configObj.modules) {
    // Para módulos duplicados (ex: weather), podemos querer um critério melhor, mas para já apanhamos o 1º
    const mod = configObj.modules.find(x => x.module === '__MODULE_NAME__');
    if (mod && mod.config) {
      console.log(JSON.stringify({ ok: true, config: mod.config }));
    } else {
      console.log(JSON.stringify({ ok: true, config: {} }));
    }
  } else {
    console.log(JSON.stringify({ error: 'no_modules_array' }));
  }
} catch (e) {
  console.log(JSON.stringify({ error: e.message }));
}
""".replaceAll('__MODULE_NAME__', moduleName);

    await executeCommand("cat << 'EOF' > /tmp/fetch_current_config.js\n$jsScript\nEOF");
    final result = await executeCommand("node /tmp/fetch_current_config.js");
    if (result != null) {
      try {
        final decoded = json.decode(result.trim());
        if (decoded['ok'] == true && decoded['config'] != null) {
          return decoded['config'] as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<String?> fetchModuleReadme(String moduleName) async {
    final dir = '\$HOME/MagicMirror/modules/$moduleName';
    
    // Concatena todos os ficheiros .md (case insensitive) numa única string com divisores
    final result = await executeCommand(
      'shopt -s nocaseglob 2>/dev/null; '
      'for f in "$dir"/*.md; do '
      'if [ -f "\$f" ]; then '
      '  echo -e "\\n\\n---\\n# \$(basename "\$f")\\n---\\n"; '
      '  cat "\$f"; '
      'fi; '
      'done'
    );
    
    if (result != null && result.trim().isNotEmpty) {
      return result;
    }
    return null;
  }

  /// Faz upload de um ficheiro via SFTP para a pasta do módulo (opcionalmente numa sub-pasta).
  Future<bool> uploadFile(String moduleName, String fileName, Uint8List bytes, {String? subfolder}) async {
    try {
      final client = await _connect();
      final sftp = await client.sftp();
      // Uses the configured user home directory or fallback to /home/pi
      final home = _user == 'pi' ? '/home/pi' : '/home/$_user';
      
      String targetDir = '$home/MagicMirror/modules/$moduleName';
      if (subfolder != null && subfolder.trim().isNotEmpty) {
        // Ensure no weird paths, just append
        final safeSubfolder = subfolder.trim().replaceAll('..', '');
        targetDir = '$targetDir/$safeSubfolder';
        
        // Criar a sub-pasta caso não exista (via comando shell antes de usar SFTP)
        await client.run('mkdir -p "$targetDir"');
      }
      
      final remotePath = '$targetDir/$fileName';
      
      final file = await sftp.open(remotePath, mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate);
      await file.writeBytes(bytes);
      await file.close();
      client.close();
      return true;
    } catch (e) {
      debugPrint('SSH SFTP Upload Error: $e');
      return false;
    }
  }

  // ─── Instalar / Remover / Atualizar ────────────────────────────────────────

  Future<bool> _deployLocalModule(String moduleName) async {
    try {
      // 1. Encontrar o diretório local do módulo
      Directory localDir = Directory('Modulos_MagicMirror/$moduleName');
      if (!localDir.existsSync()) {
        localDir = Directory('magic_mirror_app/Modulos_MagicMirror/$moduleName');
      }
      if (!localDir.existsSync()) {
        debugPrint('Diretório local do módulo $moduleName não encontrado.');
        return false;
      }

      // 2. Conetar via SSH/SFTP
      final client = await _connect();
      final sftp = await client.sftp();
      final home = _user == 'pi' ? '/home/pi' : '/home/$_user';
      final remoteDir = '$home/MagicMirror/modules/$moduleName';

      // Criar a pasta do módulo no Pi
      await client.run('mkdir -p "$remoteDir"');

      // 3. Listar ficheiros locais e fazer upload
      final entities = localDir.listSync(recursive: true);
      for (final entity in entities) {
        if (entity is File) {
          // Obter caminho relativo
          final relativePath = entity.path
              .replaceAll(localDir.path, '')
              .replaceAll('\\', '/');
          
          // Limpar barra inicial se existir
          final cleanRelativePath = relativePath.startsWith('/')
              ? relativePath.substring(1)
              : relativePath;

          if (cleanRelativePath.isEmpty) continue;

          // Se estiver dentro de subpastas, criar pastas remotas correspondentes
          final parts = cleanRelativePath.split('/');
          if (parts.length > 1) {
            final subfolder = parts.sublist(0, parts.length - 1).join('/');
            await client.run('mkdir -p "$remoteDir/$subfolder"');
          }

          final remoteFilePath = '$remoteDir/$cleanRelativePath';
          final bytes = await entity.readAsBytes();
          
          debugPrint('A enviar $cleanRelativePath para $remoteFilePath...');
          final file = await sftp.open(remoteFilePath,
              mode: SftpFileOpenMode.create |
                  SftpFileOpenMode.write |
                  SftpFileOpenMode.truncate);
          await file.writeBytes(bytes);
          await file.close();
        }
      }

      client.close();

      // 4. Executar npm install se houver um package.json
      final checkNpm = await executeCommand('[ -f "$remoteDir/package.json" ] && echo yes || echo no');
      if (checkNpm != null && checkNpm.trim() == 'yes') {
        debugPrint('A executar npm install para $moduleName...');
        await executeCommand('cd "$remoteDir" && npm install --production 2>&1');
      }

      return true;
    } catch (e) {
      debugPrint('Erro ao fazer deploy do módulo local $moduleName: $e');
      return false;
    }
  }

  Future<bool> installModule(String repoUrl, String moduleName) async {
    // 1. Tentar fazer deploy local se a pasta existir localmente
    Directory localDir = Directory('Modulos_MagicMirror/$moduleName');
    if (!localDir.existsSync()) {
      localDir = Directory('magic_mirror_app/Modulos_MagicMirror/$moduleName');
    }
    if (localDir.existsSync()) {
      debugPrint('Instalação local detetada para o módulo próprio: $moduleName');
      return _deployLocalModule(moduleName);
    }

    // 2. Caso contrário, proceder com a instalação remota (git clone)
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
    // 1. Remover do config.js primeiro para evitar erros ao reiniciar o MagicMirror
    final jsScript = r"""
const fs = require('fs');
const path = require('path');
const home = process.env.HOME || '/home/pi';
const configPath = path.join(home, 'MagicMirror/config/config.js');

if (!fs.existsSync(configPath)) {
  console.log(JSON.stringify({ ok: false, error: 'config not found' }));
  process.exit(0);
}

let content = fs.readFileSync(configPath, 'utf8');

function findEnclosingObjectBounds(str, matchIndex) {
  let openBraceIndex = -1;
  let balance = 0;
  for (let i = matchIndex; i >= 0; i--) {
    if (str[i] === '}') {
      balance++;
    } else if (str[i] === '{') {
      if (balance === 0) { openBraceIndex = i; break; }
      balance--;
    }
  }
  if (openBraceIndex === -1) return null;

  balance = 1;
  let closeBraceIndex = -1;
  for (let i = openBraceIndex + 1; i < str.length; i++) {
    if (str[i] === '"' || str[i] === "'" || str[i] === '`') {
      const quote = str[i]; i++;
      while (i < str.length && str[i] !== quote) {
        if (str[i] === '\\') i++; i++;
      }
      continue;
    }
    if (str[i] === '{') { balance++; } 
    else if (str[i] === '}') {
      balance--;
      if (balance === 0) { closeBraceIndex = i; break; }
    }
  }
  return { start: openBraceIndex, end: closeBraceIndex };
}

const regex = /module\s*:\s*["']([^"']+)["']/g;
let match;
let blocksToRemove = [];
while ((match = regex.exec(content)) !== null) {
  if (match[1] === '__MODULE_NAME__') {
    const bounds = findEnclosingObjectBounds(content, match.index);
    if (bounds) blocksToRemove.push(bounds);
  }
}

blocksToRemove.sort((a, b) => b.start - a.start);
for (const b of blocksToRemove) {
  let endIdx = b.end + 1;
  while(endIdx < content.length && (content[endIdx] === ' ' || content[endIdx] === '\n' || content[endIdx] === '\r')) {
    endIdx++;
  }
  if (content[endIdx] === ',') endIdx++;
  
  content = content.substring(0, b.start) + content.substring(endIdx);
}

if (blocksToRemove.length > 0) {
  fs.writeFileSync(configPath, content, 'utf8');
}
console.log(JSON.stringify({ ok: true, removed: blocksToRemove.length }));
""".replaceAll('__MODULE_NAME__', moduleName);

    // Escrever para um ficheiro temporário e correr, para evitar problemas de escape de bash com node -e
    await executeCommand("cat << 'EOF' > /tmp/remove_module.js\n$jsScript\nEOF");
    final nodeOutput = await executeCommand("node /tmp/remove_module.js");
    debugPrint("removeModule Node output: $nodeOutput");

    // 2. Apagar a pasta
    final dir = '\$HOME/MagicMirror/modules/$moduleName';
    final result = await executeCommand('rm -rf "$dir" && echo RM_OK');
    
    // 3. Reiniciar para aplicar
    if (result != null && result.contains('RM_OK')) {
      await restartMagicMirror();
      return true;
    }
    return false;
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
