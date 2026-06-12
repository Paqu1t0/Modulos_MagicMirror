import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Fetching modules.json...');
  try {
    final res = await http.get(Uri.parse('https://modules.magicmirror.builders/data/modules.json'));
    final data = json.decode(res.body);
    final List<dynamic> modules = data['modules'];
    for (final m in modules) {
      final String name = m['name'] ?? '';
      if (name.toLowerCase().contains('onthisday')) {
        print(const JsonEncoder.withIndent('  ').convert(m));
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
