import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../services/ssh_service.dart';

class PowerManagementScreen extends StatefulWidget {
  const PowerManagementScreen({super.key});

  @override
  State<PowerManagementScreen> createState() => _PowerManagementScreenState();
}

class _PowerManagementScreenState extends State<PowerManagementScreen> {
  bool _scheduleEnabled = false;
  
  // Controllers para os campos de hora/minuto
  final _offHourController = TextEditingController(text: '23');
  final _offMinuteController = TextEditingController(text: '00');
  final _onHourController = TextEditingController(text: '07');
  final _onMinuteController = TextEditingController(text: '00');

  bool _isScreenOn = true;
  bool _loadingState = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _offHourController.dispose();
    _offMinuteController.dispose();
    _onHourController.dispose();
    _onMinuteController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loadingState = true);
    final prefs = await SharedPreferences.getInstance();
    
    // Carregar configurações locais
    final scheduleEnabled = prefs.getBool('sleep_schedule_enabled') ?? false;
    final offHour = prefs.getString('sleep_off_hour') ?? '23';
    final offMinute = prefs.getString('sleep_off_minute') ?? '00';
    final onHour = prefs.getString('sleep_on_hour') ?? '07';
    final onMinute = prefs.getString('sleep_on_minute') ?? '00';
    final screenOn = prefs.getBool('sleep_screen_state') ?? true;

    if (mounted) {
      setState(() {
        _scheduleEnabled = scheduleEnabled;
        _offHourController.text = offHour;
        _offMinuteController.text = offMinute;
        _onHourController.text = onHour;
        _onMinuteController.text = onMinute;
        _isScreenOn = screenOn;
        _loadingState = false;
      });
    }
  }

  Future<void> _toggleImmediatePower(bool value) async {
    setState(() {
      _isScreenOn = value;
      _saving = true;
    });

    final success = await SshService().setMonitorPower(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sleep_screen_state', value);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? (value ? 'Ecrã do espelho ligado!' : 'Ecrã do espelho colocado em Sleep Mode!')
                : 'Erro ao comunicar com o espelho via SSH.',
          ),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _applySchedule() async {
    // Validar formato das horas
    final offH = int.tryParse(_offHourController.text.trim()) ?? -1;
    final offM = int.tryParse(_offMinuteController.text.trim()) ?? -1;
    final onH = int.tryParse(_onHourController.text.trim()) ?? -1;
    final onM = int.tryParse(_onMinuteController.text.trim()) ?? -1;

    if (offH < 0 || offH > 23 || offM < 0 || offM > 59 ||
        onH < 0 || onH > 23 || onM < 0 || onM > 59) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Horas ou minutos inválidos. Introduza valores válidos (0-23h, 0-59m).'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    // Formatar strings com dois dígitos
    final offHourStr = offH.toString().padLeft(2, '0');
    final offMinuteStr = offM.toString().padLeft(2, '0');
    final onHourStr = onH.toString().padLeft(2, '0');
    final onMinuteStr = onM.toString().padLeft(2, '0');

    // 1. Guardar localmente
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sleep_schedule_enabled', _scheduleEnabled);
    await prefs.setString('sleep_off_hour', offHourStr);
    await prefs.setString('sleep_off_minute', offMinuteStr);
    await prefs.setString('sleep_on_hour', onHourStr);
    await prefs.setString('sleep_on_minute', onMinuteStr);

    // 2. Enviar crontab via SSH
    final success = await SshService().updatePowerCronSchedule(
      enabled: _scheduleEnabled,
      offHour: offHourStr,
      offMinute: offMinuteStr,
      onHour: onHourStr,
      onMinute: onMinuteStr,
    );

    if (mounted) {
      setState(() => _saving = false);
      
      // Atualiza os valores visuais formatados nos controladores
      _offHourController.text = offHourStr;
      _offMinuteController.text = offMinuteStr;
      _onHourController.text = onHourStr;
      _onMinuteController.text = onMinuteStr;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Agendamento aplicado com sucesso no Magic Mirror!' 
                : 'Erro ao configurar crontab via SSH.',
          ),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Gestão de Energia',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _loadingState
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Poupança e Controlo do Ecrã',
                      style: AppTheme.headingMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Poupe energia configurando o modo sleep manual ou definindo um agendamento para desligar o espelho automaticamente.',
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),

                    // Card 1: Immediate Control
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.cardDecoration,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.iconBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _isScreenOn ? Icons.lightbulb_outline : Icons.nights_stay_outlined,
                              color: _isScreenOn ? AppTheme.warning : AppTheme.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Modo Sleep Manual',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isScreenOn ? 'Ecrã ativo agora' : 'Ecrã desligado / Em sleep',
                                  style: AppTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: !_isScreenOn,
                            onChanged: _saving ? null : (val) => _toggleImmediatePower(!val),
                            activeThumbColor: AppTheme.primary,
                            activeTrackColor: AppTheme.primaryLight,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Card 2: Scheduling Configuration
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
                                child: const Icon(Icons.schedule, color: AppTheme.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Agendamento Diário',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: _scheduleEnabled,
                                onChanged: (val) {
                                  setState(() {
                                    _scheduleEnabled = val;
                                  });
                                },
                                activeThumbColor: AppTheme.primary,
                                activeTrackColor: AppTheme.primaryLight,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: AppTheme.border, height: 1),
                          const SizedBox(height: 20),

                          AnimatedOpacity(
                            opacity: _scheduleEnabled ? 1.0 : 0.45,
                            duration: const Duration(milliseconds: 200),
                            child: IgnorePointer(
                              ignoring: !_scheduleEnabled,
                              child: Column(
                                children: [
                                  // Time 1: Turn OFF
                                  _buildTimeRow(
                                    title: 'Desligar Ecrã',
                                    subtitle: 'Colocar o espelho em modo sleep',
                                    icon: Icons.brightness_3,
                                    iconColor: Colors.orange,
                                    hourController: _offHourController,
                                    minuteController: _offMinuteController,
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Time 2: Turn ON
                                  _buildTimeRow(
                                    title: 'Ligar Ecrã',
                                    subtitle: 'Acordar o espelho automaticamente',
                                    icon: Icons.wb_sunny,
                                    iconColor: AppTheme.primary,
                                    hourController: _onHourController,
                                    minuteController: _onMinuteController,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 28),
                          
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _saving ? null : _applySchedule,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Aplicar Configurações',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTimeRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required TextEditingController hourController,
    required TextEditingController minuteController,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
        
        // Relógio digital com inputs
        Row(
          children: [
            _buildTimeInput(hourController),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                ':',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            _buildTimeInput(minuteController),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeInput(TextEditingController controller) {
    return Container(
      width: 48,
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: 2,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
