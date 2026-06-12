import 'dart:convert';
import 'dart:io';

void main() async {
  print("=== Diagnóstico de Configuração ===");
  
  final appData = Platform.environment['APPDATA'];
  final localAppData = Platform.environment['LOCALAPPDATA'];
  
  final List<String> pathsToTry = [
    if (appData != null) "$appData/magic_mirror_app/shared_preferences.json",
    if (appData != null) "$appData/com.example.magic_mirror_app/shared_preferences.json",
    if (localAppData != null) "$localAppData/magic_mirror_app/shared_preferences.json",
    if (localAppData != null) "$localAppData/com.example.magic_mirror_app/shared_preferences.json",
  ];
  
  File? prefsFile;
  for (final path in pathsToTry) {
    final file = File(path.replaceAll(r'\', '/'));
    if (await file.exists()) {
      prefsFile = file;
      print("Ficheiro SharedPreferences encontrado em: ${file.path}");
      break;
    }
  }
  
  if (prefsFile == null) {
    print("Não foi possível encontrar o ficheiro shared_preferences.json nas localizações comuns.");
    print("Por favor, verifica se a app já foi executada como aplicação Windows.");
    return;
  }
  
  try {
    final content = await prefsFile.readAsString();
    final jsonContent = json.decode(content) as Map<String, dynamic>;
    
    print("\nDefinições Encontradas:");
    print("IP do Espelho: ${jsonContent['flutter.mirror_ip']}");
    print("Utilizador SSH: ${jsonContent['flutter.ssh_user']}");
    print("Password SSH: ${jsonContent['flutter.ssh_pass'] != null ? '******' : 'não configurada'}");
  } catch (e) {
    print("Erro ao ler/descodificar shared_preferences.json: $e");
  }
}
