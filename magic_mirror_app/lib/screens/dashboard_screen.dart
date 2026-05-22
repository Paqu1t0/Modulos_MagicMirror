import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/mirror_status.dart';
import '../services/mirror_api_service.dart';
import '../widgets/bottom_nav_bar.dart';

class DashboardScreen extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Começa sempre offline — só fica verde quando o Pi responder
  MirrorStatus _status = MirrorStatus.offline;
  bool _loading = false;
  bool _applying = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    // Polling automático a cada 30 segundos
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadStatus());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final status = await MirrorApiService().getStatus();
    if (mounted) setState(() { _status = status; _loading = false; });
  }

  Future<void> _applyAndReset() async {
    setState(() => _applying = true);
    
    // Primeiro, recarregar o layout e gravar tudo para sincronizar configurações alteradas
    final currentLayout = await MirrorApiService().loadLayout();
    final syncSuccess = await MirrorApiService().saveLayout(currentLayout);
    
    // Opcionalmente reiniciar caso o saveLayout não o faça (mas o saveLayout já chama restart internamente)
    // Para ter a certeza absoluta, chamamos restart se syncSuccess falhar ou não for chamado
    
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _applying = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncSuccess
                ? 'Sincronizado! Espelho a reiniciar...'
                : 'Erro a sincronizar definições com o Pi.',
          ),
          backgroundColor: syncSuccess ? AppTheme.success : AppTheme.error,
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
      body: SafeArea(
        child: _loading && _status == MirrorStatus.offline
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadStatus,
                color: AppTheme.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text('Magic Mirror', style: AppTheme.headingLarge),
                      const SizedBox(height: 4),
                      Text('Control Center', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
                      const SizedBox(height: 28),

                      // Mirror Status Card
                      _MirrorStatusCard(status: _status, onRefresh: _loadStatus),
                      const SizedBox(height: 24),

                      // Quick Stats
                      Text('Quick Stats', style: AppTheme.headingMedium),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              value: '${_status.activeWidgets}',
                              label: 'Active Widgets',
                              icon: Icons.widgets_outlined,
                              onTap: () => widget.onNavigate(2),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _StatCard(
                              value: '${_status.savedPresets}',
                              label: 'Saved Presets',
                              icon: Icons.tune_outlined,
                              onTap: () => widget.onNavigate(3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              value: _status.isOnline ? 'Online' : 'Offline',
                              label: 'Mirror Status',
                              icon: Icons.monitor_outlined,
                              valueColor: _status.isOnline ? AppTheme.success : AppTheme.error,
                              onTap: _loadStatus,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _StatCard(
                              value: _status.wifiStrong ? 'Forte' : 'Fraca',
                              label: 'Ligação WiFi',
                              icon: Icons.wifi,
                              valueColor: _status.wifiStrong ? AppTheme.success : AppTheme.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),

                      // Apply & Reset Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _applying ? null : _applyAndReset,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _applying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.monitor, size: 20, color: Colors.white),
                                    SizedBox(width: 10),
                                    Text(
                                      'Apply & Reset Mirror',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          'This will save all positions and sync to your mirror',
                          style: AppTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: MirrorBottomNavBar(
        currentIndex: 0,
        onTap: widget.onNavigate,
      ),
    );
  }
}

// ─── Mirror Status Card ────────────────────────────────────────────────────────

class _MirrorStatusCard extends StatelessWidget {
  final MirrorStatus status;
  final VoidCallback onRefresh;

  const _MirrorStatusCard({required this.status, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.monitor, color: AppTheme.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mirror Status', style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    )),
                    const SizedBox(height: 3),
                    Text(
                      status.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: status.isOnline ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              // Botão de refresh manual
              GestureDetector(
                onTap: onRefresh,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.refresh, color: AppTheme.primary, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              // Indicador colorido (bolinha verde/vermelha)
              _StatusDot(isOnline: status.isOnline),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatusIndicator(icon: Icons.wifi, label: 'WiFi', active: status.wifiStrong),
              _StatusIndicator(icon: Icons.battery_charging_full, label: 'Powered', active: status.isPowered),
              _StatusIndicator(icon: Icons.sync, label: 'Synced', active: status.isSynced),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatefulWidget {
  final bool isOnline;
  const _StatusDot({required this.isOnline});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isOnline ? AppTheme.success : AppTheme.error;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: widget.isOnline
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: _pulse.value * 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _StatusIndicator({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: active ? AppTheme.primary : AppTheme.textMuted),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

// ─── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color? valueColor;
  final VoidCallback? onTap;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: AppTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}