import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../services/ssh_service.dart';

class UltrasonicSettingsScreen extends StatefulWidget {
  const UltrasonicSettingsScreen({super.key});

  @override
  State<UltrasonicSettingsScreen> createState() => _UltrasonicSettingsScreenState();
}

class _UltrasonicSettingsScreenState extends State<UltrasonicSettingsScreen> with SingleTickerProviderStateMixin {
  double _distanceLimit = 150.0; // cm
  int _activeSeconds = 30; // seconds

  bool _loading = false;
  bool _saving = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    
    final distance = prefs.getDouble('sensor_distance_limit') ?? 150.0;
    final seconds = prefs.getInt('sensor_active_time') ?? 30;

    if (mounted) {
      setState(() {
        _distanceLimit = distance;
        _activeSeconds = seconds;
        _loading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);

    // Mostrar feedback imediato enquanto o SSH trabalha
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
              SizedBox(width: 14),
              Text('A enviar configuração para o espelho...'),
            ],
          ),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    // 1. Guardar localmente
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('sensor_distance_limit', _distanceLimit);
    await prefs.setInt('sensor_active_time', _activeSeconds);

    // 2. Enviar para o Raspberry Pi via SSH
    final success = await SshService().saveUltrasonicConfig(
      distanceLimit: _distanceLimit,
      activeSeconds: _activeSeconds,
    );

    if (mounted) {
      setState(() => _saving = false);
      // Fechar o snackbar de "a enviar..."
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Guardado! Sensor a recarregar em ~2s...'
                : 'Erro ao guardar configurações no Magic Mirror.',
          ),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
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
          'Sensor Ultrassónico',
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deteção de Presença',
                      style: AppTheme.headingMedium,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ajuste a sensibilidade do sensor de proximidade. O espelho liga-se quando alguém se aproxima e desliga-se após a ausência programada.',
                      style: AppTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),

                    // Card 1: Sensor Status
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.cardDecoration,
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppTheme.success,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.success.withValues(alpha: _pulseAnimation.value * 0.5),
                                      blurRadius: 8,
                                      spreadRadius: 3,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Estado do Sensor',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Ativo e a monitorizar em tempo real',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.success,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'ON',
                              style: TextStyle(
                                color: AppTheme.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Card 2: Distance Limit
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
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.straighten, color: Colors.blue, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Distância de Ativação',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: AppTheme.border, height: 1),
                          const SizedBox(height: 20),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Distância limite:', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                              Text(
                                '${_distanceLimit.toInt()} cm / ${(_distanceLimit / 100).toStringAsFixed(1)} metros',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.blue,
                              inactiveTrackColor: Colors.blue.withValues(alpha: 0.15),
                              thumbColor: Colors.blue,
                              overlayColor: Colors.blue.withValues(alpha: 0.2),
                              trackHeight: 6,
                            ),
                            child: Slider(
                              value: _distanceLimit,
                              min: 10.0,
                              max: 300.0,
                              divisions: 29,
                              onChanged: (val) {
                                setState(() {
                                  _distanceLimit = val;
                                });
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          // Visual proximity bar preview
                          Container(
                            height: 8,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: const LinearGradient(
                                colors: [Colors.green, Colors.yellow, Colors.orange, Colors.red],
                              ),
                            ),
                            child: Stack(
                              children: [
                                Align(
                                  alignment: Alignment(((_distanceLimit - 10) / (300 - 10) * 2) - 1.0, 0.0),
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 3,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('10cm (Ultra-sensível)', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                              Text('300cm (Longe)', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Card 3: Active Time Limit
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
                                  color: Colors.deepPurple.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.timer_outlined, color: Colors.deepPurple, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Tempo Ativo Sem Ninguém',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: AppTheme.border, height: 1),
                          const SizedBox(height: 20),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tempo para desligar:', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                              Text(
                                '$_activeSeconds s / ${(_activeSeconds >= 60) ? '${(_activeSeconds / 60).floor()}m ${_activeSeconds % 60}s' : '$_activeSeconds segundos'}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.deepPurple,
                              inactiveTrackColor: Colors.deepPurple.withValues(alpha: 0.15),
                              thumbColor: Colors.deepPurple,
                              overlayColor: Colors.deepPurple.withValues(alpha: 0.2),
                              trackHeight: 6,
                            ),
                            child: Slider(
                              value: _activeSeconds.toDouble(),
                              min: 5.0,
                              max: 120.0,
                              divisions: 23,
                              onChanged: (val) {
                                setState(() {
                                  _activeSeconds = val.toInt();
                                });
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          const Text(
                            'Predefinições Rápidas:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [10, 30, 60, 90].map((sec) {
                              final isSelected = _activeSeconds == sec;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _activeSeconds = sec;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.deepPurple : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected ? Colors.deepPurple : AppTheme.border,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${sec}s',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Guardar Configurações do Sensor',
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
      ),
    );
  }
}
