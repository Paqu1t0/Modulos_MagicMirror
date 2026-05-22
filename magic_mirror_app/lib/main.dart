import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'services/mirror_api_service.dart';
import 'services/ssh_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/store_screen.dart';
import 'screens/layout_screen.dart';
import 'screens/presets_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Bloquear a rotação para retrato
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  await MirrorApiService().init();
  await SshService().init();

  // Carregar preferência de Modo Escuro
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  
  runApp(const MagicMirrorApp());
}

class MagicMirrorApp extends StatelessWidget {
  const MagicMirrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentMode, __) {
        return MaterialApp(
          title: 'Magic Mirror',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.themeData,
          home: const MainShell(),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final ValueNotifier<int> _activeTabNotifier = ValueNotifier<int>(0);

  void _navigate(int index) {
    setState(() => _currentIndex = index);
    _activeTabNotifier.value = index;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        return IndexedStack(
          index: _currentIndex,
          children: [
            DashboardScreen(onNavigate: _navigate),
            StoreScreen(onNavigate: _navigate, activeTabNotifier: _activeTabNotifier),
            LayoutScreen(onNavigate: _navigate, activeTabNotifier: _activeTabNotifier),
            PresetsScreen(onNavigate: _navigate, activeTabNotifier: _activeTabNotifier),
            SettingsScreen(onNavigate: _navigate),
          ],
        );
      },
    );
  }
}
