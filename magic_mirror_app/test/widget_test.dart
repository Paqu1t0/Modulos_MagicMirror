import 'package:flutter_test/flutter_test.dart';
import 'package:magic_mirror_app/main.dart';

void main() {
  testWidgets('Magic Mirror app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MagicMirrorApp());
    expect(find.byType(MagicMirrorApp), findsOneWidget);
  });
}
