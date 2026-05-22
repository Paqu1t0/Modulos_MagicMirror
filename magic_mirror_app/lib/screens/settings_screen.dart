import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../services/mirror_api_service.dart';
import '../widgets/bottom_nav_bar.dart';
import 'connection_settings_screen.dart';
import 'power_management_screen.dart';
import 'ultrasonic_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const SettingsScreen({super.key, required this.onNavigate});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _savedIp = '';
  bool _isOnline = false;
  bool _checkingConnection = false;

  @override
  void initState() {
    super.initState();
    _loadConnectionWidgetData();
  }

  Future<void> _loadConnectionWidgetData() async {
    setState(() => _checkingConnection = true);
    
    // Obter o IP atualmente configurado
    final ip = await MirrorApiService().getSavedIp();
    
    // Testar ligação rápida
    final apiStatus = await MirrorApiService().getStatus();
    final isOnline = apiStatus.isOnline;

    if (mounted) {
      setState(() {
        _savedIp = ip.isEmpty ? 'Não configurado' : ip;
        _isOnline = isOnline;
        _checkingConnection = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header com Perfil (Igual ao mockup do utilizador)
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.iconBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.8),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Definições',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Configurações do Magic Mirror',
                          style: AppTheme.bodySmall.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Widget de Conexão (Solução para "em widget acrescenta a conexão do mesmo")
              Container(
                padding: const EdgeInsets.all(18),
                decoration: AppTheme.cardDecoration,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isOnline 
                            ? AppTheme.success.withValues(alpha: 0.1) 
                            : AppTheme.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isOnline ? Icons.wifi : Icons.wifi_off,
                        color: _isOnline ? AppTheme.success : AppTheme.error,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ligação ao Espelho',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'IP: $_savedIp',
                            style: AppTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isOnline 
                                ? AppTheme.success.withValues(alpha: 0.1) 
                                : AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: _isOnline ? AppTheme.success : AppTheme.error,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _checkingConnection ? null : _loadConnectionWidgetData,
                          child: Text(
                            _checkingConnection ? 'A verificar...' : 'Atualizar',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Modo Escuro (Sem card)
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, themeMode, _) {
                  final isDark = themeMode == ThemeMode.dark;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24.0, left: 4.0, right: 4.0),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark 
                                ? Colors.amber.withValues(alpha: 0.15) 
                                : Colors.indigo.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                            color: isDark ? Colors.amber : Colors.indigo,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Modo Escuro',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isDark ? 'Visual confortável para a noite' : 'Visual padrão brilhante',
                                style: AppTheme.bodySmall.copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: isDark,
                          onChanged: (value) async {
                            themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('dark_mode', value);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Título de Secção
              Text(
                'CONFIGURAÇÕES DO SISTEMA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 14),

              // Card Portal 1: Gestão de Energia
              _buildPortalCard(
                context: context,
                title: 'Gestão de Energia',
                subtitle: 'Modo sleep e agendamento',
                icon: Icons.power_settings_new_outlined,
                iconColor: Colors.blue,
                destination: const PowerManagementScreen(),
              ),
              const SizedBox(height: 14),

              // Card Portal 2: Sensor Ultrassónico
              _buildPortalCard(
                context: context,
                title: 'Sensor Ultrassónico',
                subtitle: 'Deteção de presença',
                icon: Icons.radar_outlined,
                iconColor: Colors.teal,
                destination: const UltrasonicSettingsScreen(),
              ),
              const SizedBox(height: 14),

              // Card Portal 3: Conexão do Espelho (Redes e SSH)
              _buildPortalCard(
                context: context,
                title: 'Conexão do Espelho',
                subtitle: 'Configurações de IP e acesso SSH',
                icon: Icons.settings_ethernet_outlined,
                iconColor: Colors.indigo,
                destination: const ConnectionSettingsScreen(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: MirrorBottomNavBar(
        currentIndex: 4,
        onTap: widget.onNavigate,
      ),
    );
  }

  Widget _buildPortalCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget destination,
  }) {
    return Container(
      decoration: AppTheme.cardDecoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Navega para o sub-ecrã e recarrega os dados do widget ao voltar
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => destination),
            );
            _loadConnectionWidgetData();
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                // Ícone circular decorativo
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                
                // Textos descritivos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: AppTheme.bodySmall.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                
                // Chevron indicador de navegação
                Icon(
                  Icons.chevron_right,
                  color: AppTheme.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
