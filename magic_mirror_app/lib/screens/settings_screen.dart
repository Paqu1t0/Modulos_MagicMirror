import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/mirror_api_service.dart';
import '../widgets/bottom_nav_bar.dart';

class SettingsScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const SettingsScreen({super.key, required this.onNavigate});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  bool _saving = false;
  bool _testing = false;
  String? _connectionResult;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final ip = await MirrorApiService().getSavedIp();
    final port = await MirrorApiService().getSavedPort();
    if (mounted) {
      _ipController.text = ip;
      _portController.text = port;
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    await MirrorApiService().saveConfig(
      _ipController.text.trim(),
      _portController.text.trim(),
    );
    if (mounted) {
      setState(() { _saving = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Configuração guardada!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() { _testing = true; _connectionResult = null; });
    await MirrorApiService().saveConfig(
      _ipController.text.trim(),
      _portController.text.trim(),
    );
    final status = await MirrorApiService().getStatus();
    if (mounted) {
      setState(() {
        _testing = false;
        _connectionResult = status.isOnline ? 'connected' : 'failed';
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
              // Header
              const Text('Settings', style: AppTheme.headingLarge),
              const SizedBox(height: 4),
              const Text('Configure a ligação ao Magic Mirror', style: AppTheme.bodyMedium),
              const SizedBox(height: 28),

              // Connection card
              _SettingsCard(
                title: 'Ligação ao Raspberry Pi',
                icon: Icons.wifi,
                child: Column(
                  children: [
                    _buildField(
                      label: 'Endereço IP do Raspberry Pi',
                      controller: _ipController,
                      hint: 'ex: 192.168.1.100',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      label: 'Porta',
                      controller: _portController,
                      hint: '8080',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 20),
                    // Connection status badge
                    if (_connectionResult != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: _connectionResult == 'connected'
                              ? AppTheme.success.withOpacity(0.1)
                              : AppTheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _connectionResult == 'connected'
                                ? AppTheme.success.withOpacity(0.4)
                                : AppTheme.error.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _connectionResult == 'connected'
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: _connectionResult == 'connected'
                                  ? AppTheme.success
                                  : AppTheme.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _connectionResult == 'connected'
                                  ? 'Conectado com sucesso!'
                                  : 'Falha na ligação. Verifica o IP e porta.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _connectionResult == 'connected'
                                    ? AppTheme.success
                                    : AppTheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _testing ? null : _testConnection,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: AppTheme.primary),
                              foregroundColor: AppTheme.primary,
                            ),
                            child: _testing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primary,
                                    ),
                                  )
                                : const Text('Testar Ligação',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _saveConfig,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Guardar',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // How to configure card
              _SettingsCard(
                title: 'Como conectar ao Magic Mirror',
                icon: Icons.info_outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStep('1', 'Instala o módulo MMM-Remote-Control no Raspberry Pi'),
                    _buildStep('2', 'Garante que o Pi e o telemóvel estão na mesma rede WiFi'),
                    _buildStep('3', 'Descobre o IP do Pi com o comando: hostname -I'),
                    _buildStep('4', 'Introduz o IP acima e testa a ligação'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.iconBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Porta padrão do MMM-Remote-Control: 8080',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.primary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // App info
              _SettingsCard(
                title: 'Sobre a App',
                icon: Icons.apps,
                child: Column(
                  children: [
                    _buildInfoRow('Versão', '1.0.0'),
                    const Divider(color: AppTheme.border, height: 20),
                    _buildInfoRow('Módulo Pi necessário', 'MMM-Remote-Control'),
                    const Divider(color: AppTheme.border, height: 20),
                    _buildInfoRow('Protocolo', 'HTTP REST'),
                  ],
                ),
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

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondary,
        )),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(number, style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              )),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTheme.bodyMedium),
        Text(value, style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        )),
      ],
    );
  }
}

// ─── Settings Card ────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SettingsCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              )),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
