import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/mirror_api_service.dart';
import '../services/ssh_service.dart';

class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() => _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  final _ipController = TextEditingController();
  final _sshUserController = TextEditingController();
  final _sshPassController = TextEditingController();
  
  bool _saving = false;
  bool _testing = false;
  String? _connectionResult; // 'connected' | 'failed'

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _sshUserController.dispose();
    _sshPassController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final ip = await MirrorApiService().getSavedIp();
    final sshUser = await SshService().getSavedUser();
    final sshPass = await SshService().getSavedPass();
    if (mounted) {
      setState(() {
        _ipController.text = ip;
        _sshUserController.text = sshUser;
        _sshPassController.text = sshPass;
      });
    }
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    final ip = _ipController.text.trim();
    final sshUser = _sshUserController.text.trim();
    final sshPass = _sshPassController.text.trim();
    
    await MirrorApiService().saveConfig(ip, '8080');
    await SshService().saveConfig(ip, sshUser, sshPass);
    
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Configuração de ligação guardada!'),
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
      _connectionResult = null;
    });
    
    final ip = _ipController.text.trim();
    final sshUser = _sshUserController.text.trim();
    final sshPass = _sshPassController.text.trim();
    
    await MirrorApiService().saveConfig(ip, '8080');
    await SshService().saveConfig(ip, sshUser, sshPass);
    
    final sshOk = await SshService().testConnection();
    final apiOk = (await MirrorApiService().getStatus()).isOnline;
    
    if (mounted) {
      setState(() {
        _testing = false;
        _connectionResult = (sshOk || apiOk) ? 'connected' : 'failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBg,
        elevation: 0.5,
        title: Text(
          'Conexão do Espelho',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Definições de Rede e SSH',
                style: AppTheme.headingMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Configure a ligação local e o acesso SSH para que a aplicação possa enviar comandos ao Raspberry Pi.',
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Form Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.iconBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.router, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Credenciais de Ligação',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Divider(color: AppTheme.border, height: 1),
                    const SizedBox(height: 18),
                    
                    _buildField(
                      label: 'Endereço IP do Raspberry Pi',
                      controller: _ipController,
                      hint: 'ex: 192.168.1.100',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'Utilizador SSH',
                            controller: _sshUserController,
                            hint: 'ex: pi',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildField(
                            label: 'Palavra-passe SSH',
                            controller: _sshPassController,
                            hint: 'ex: raspberry',
                            obscureText: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (_connectionResult != null) ...[
                      _ConnectionStatusBadge(status: _connectionResult),
                      const SizedBox(height: 16),
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

              // Instructions Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.cardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.iconBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Como configurar a rede',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Divider(color: AppTheme.border, height: 1),
                    const SizedBox(height: 18),
                    _buildStep('1', 'Descobre o IP do Pi executando no terminal: hostname -I'),
                    _buildStep('2', 'Certifica-te que o telemóvel e o Magic Mirror estão ligados à mesma rede Wi-Fi.'),
                    _buildStep('3', 'Preenche as credenciais SSH (por defeito, utilizador é "pi" ou "root").'),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        Text(label, style: TextStyle(
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
            style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
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
  final String? status; // 'connected' | 'failed'

  const _ConnectionStatusBadge({required this.status});

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
            child: Text(
              isSuccess 
                  ? 'Ligação estabelecida com sucesso!' 
                  : 'Falha na ligação. Verifica o IP e credenciais.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}