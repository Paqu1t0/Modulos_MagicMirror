import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('build/flutter_assets/AssetManifest.json');
  if (!file.existsSync()) {
    print('Manifest not found');
    return;
  }
  final content = file.readAsStringSync();
  final map = json.decode(content) as Map<String, dynamic>;
  final keys = map.keys.toList();
  final modulosKeys = keys.where((k) => k.startsWith('Modulos_MagicMirror/')).toList();
  print('Found ${modulosKeys.length} modulos keys');
  for (var k in modulosKeys) {
    print('Key: $k');
  }
}
