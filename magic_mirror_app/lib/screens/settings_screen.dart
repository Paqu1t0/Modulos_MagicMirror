import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/mirror_api_service.dart';
import '../services/ssh_service.dart';
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
  final _sshUserController = TextEditingController();
  final _sshPassController = TextEditingController();
  
  bool _saving = false;
  bool _testing = false;
  
  String? _apiConnectionResult;
  String? _sshConnectionResult;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _sshUserController.dispose();
    _sshPassController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final ip = await MirrorApiService().getSavedIp();
    final port = await MirrorApiService().getSavedPort();
    final sshUser = await SshService().getSavedUser();
    final sshPass = await SshService().getSavedPass();
    if (mounted) {
      _ipController.text = ip;
      _portController.text = port;
      _sshUserController.text = sshUser;
      _sshPassController.text = sshPass;
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();
    final sshUser = _sshUserController.text.trim();
    final sshPass = _sshPassController.text.trim();
    
    await MirrorApiService().saveConfig(ip, port);
    await SshService().saveConfig(ip, sshUser, sshPass);
    
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
    setState(() { 
      _testing = true; 
      _apiConnectionResult = null;
      _sshConnectionResult = null;
    });
    
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();
    final sshUser = _sshUserController.text.trim();
    final sshPass = _sshPassController.text.trim();
    
    await MirrorApiService().saveConfig(ip, port);
    await SshService().saveConfig(ip, sshUser, sshPass);
    
    // Test API
    final status = await MirrorApiService().getStatus();
    
    // Test SSH
    final sshOk = await SshService().testConnection();
    
    if (mounted) {
      setState(() {
        _testing = false;
        _apiConnectionResult = status.isOnline ? 'connected' : 'failed';
        _sshConnectionResult = sshOk ? 'connected' : 'failed';
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

              // Network Connection Card
              _SettingsCard(
                title: 'Endereço de Rede',
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
                      label: 'Porta da API (MMM-Remote-Control)',
                      controller: _portController,
                      hint: '8080',
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // SSH Connection Card
              _SettingsCard(
                title: 'Credenciais SSH',
                icon: Icons.terminal,
                child: Column(
                  children: [
                    _buildField(
                      label: 'Username',
                      controller: _sshUserController,
                      hint: 'pi',
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      label: 'Password',
                      controller: _sshPassController,
                      hint: 'raspberry',
                      obscureText: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Actions and Results
              _SettingsCard(
                title: 'Ações de Ligação',
                icon: Icons.sync,
                child: Column(
                  children: [
                    if (_apiConnectionResult != null || _sshConnectionResult != null) ...[
                      _ConnectionStatusBadge(
                        label: 'API REST',
                        status: _apiConnectionResult,
                        successMessage: 'Conectado!',
                        errorMessage: 'Falhou. Verifica IP/Porta.',
                      ),
                      const SizedBox(height: 10),
                      _ConnectionStatusBadge(
                        label: 'Terminal SSH',
                        status: _sshConnectionResult,
                        successMessage: 'Autenticado!',
                        errorMessage: 'Falhou. Verifica credenciais.',
                      ),
                      const SizedBox(height: 20),
                    ],
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
                                : const Text('Testar Ligações',
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
                title: 'Como conectar',
                icon: Icons.info_outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStep('1', 'Descobre o IP do Pi com o comando: hostname -I'),
                    _buildStep('2', 'Garante que o Pi e o telemóvel estão na mesma rede WiFi'),
                    _buildStep('3', 'Preenche as credenciais SSH para poderes instalar módulos diretamente da App'),
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
    bool obscureText = false,
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
            obscureText: obscureText,
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
}

class _ConnectionStatusBadge extends StatelessWidget {
  final String label;
  final String? status; // 'connected' | 'failed' | null
  final String successMessage;
  final String errorMessage;

  const _ConnectionStatusBadge({
    required this.label,
    required this.status,
    required this.successMessage,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();
    final bool isSuccess = status == 'connected';
    final Color color = isSuccess ? AppTheme.success : AppTheme.error;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  isSuccess ? successMessage : errorMessage,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
