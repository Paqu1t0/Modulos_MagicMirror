import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('Fetching modules.json...');
  try {
    final res = await http.get(Uri.parse('https://modules.magicmirror.builders/data/modules.json'));
    if (res.statusCode != 200) {
      print('Status: ${res.statusCode}');
      return;
    }
    final data = json.decode(res.body);
    final modules = data['modules'] as List<dynamic>;
    print('Total modules: ${modules.length}');
    
    final categoryCounts = <String, int>{};
    final tagsCounts = <String, int>{};
    
    for (final m in modules) {
      final cat = m['category'] as String?;
      if (cat != null) {
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      }
      
      final tags = m['tags'];
      if (tags is List) {
        for (final t in tags) {
          final tagStr = t.toString().toLowerCase();
          tagsCounts[tagStr] = (tagsCounts[tagStr] ?? 0) + 1;
        }
      }
    }
    
    print('--- Categories in modules.json ---');
    categoryCounts.entries.toList().sort((a, b) => b.value.compareTo(a.value));
    final sortedCats = categoryCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedCats) {
      print('${e.key}: ${e.value}');
    }
    
    print('\n--- Top 30 Tags in modules.json ---');
    final sortedTags = tagsCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedTags.take(30)) {
      print('${e.key}: ${e.value}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
