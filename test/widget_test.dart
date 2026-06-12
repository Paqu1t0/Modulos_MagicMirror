import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:magic_mirror_app/main.dart';
import 'package:magic_mirror_app/services/ssh_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SshService.isTesting = true;
  });

  testWidgets('Magic Mirror app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MagicMirrorApp());
    expect(find.byType(MagicMirrorApp), findsOneWidget);
  });
}
