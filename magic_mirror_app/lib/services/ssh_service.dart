import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SshService {
  static const String _prefKeyIp = 'mirror_ip'; // Partilhado com MirrorApiService
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

  /// Reinicia fisicamente o Raspberry Pi (requer sudo sem password ou login root).
  Future<bool> rebootPi() async {
    final result = await executeCommand('sudo reboot');
    return result != null;
  }
  
  /// Reinicia apenas o processo do MagicMirror (via pm2, que é o padrão).
  Future<bool> restartMagicMirror() async {
    final result = await executeCommand('pm2 restart MagicMirror');
    return result != null;
  }

  /// Atualiza o config.js para atribuir as classes de página aos módulos.
  Future<bool> updateMagicMirrorConfig(Map<int, Map<String, String>> pages) async {
    // Para cada página e para cada módulo, precisamos de um script que edite o config.js
    // Como parsear JS via Regex em Bash é muito difícil, vamos gerar um script Node.js
    // que faz o trabalho pesado e enviá-lo para o Pi.

    final script = '''
const fs = require('fs');
const path = require('path');
const configPath = path.resolve(process.env.HOME || '/home/pi', 'MagicMirror/config/config.js');
if (!fs.existsSync(configPath)) { console.log('Config not found'); process.exit(1); }

let configContent = fs.readFileSync(configPath, 'utf8');
const pagesData = ${json.encode(pages)};

// Expressão regular básica para remover a tag pagina_X de todos os módulos
configContent = configContent.replace(/classes:\\s*["']pagina_[0-9]+["']\\s*,?/g, '');

for (const [pageStr, layout] of Object.entries(pagesData)) {
    for (const [position, moduleName] of Object.entries(layout)) {
        // Encontra o módulo e adiciona a classe da página e a posição correta
        // Assume que o módulo existe no config.js
        const regex = new RegExp(`(module:\\s*["']\${moduleName}["']\\s*,)`);
        if(configContent.match(regex)) {
            const posFormatted = position.toLowerCase().replace(' ', '_');
            configContent = configContent.replace(regex, `\$1\\n    classes: "pagina_\${pageStr}",\\n    position: "\${posFormatted}",`);
        }
    }
}

fs.writeFileSync(configPath, configContent, 'utf8');
console.log('Config updated');
''';

    final escapedScript = script.replaceAll('\\\\', '\\\\\\\\').replaceAll('"', '\\\\"').replaceAll('\\\$', '\\\\\\\$');
    final command = 'node -e "$escapedScript"';
    
    final result = await executeCommand(command);
    
    if (result != null && result.contains('Config updated')) {
      return await restartMagicMirror();
    }
    return false;
  }
}
