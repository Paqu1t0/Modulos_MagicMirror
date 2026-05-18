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
}
