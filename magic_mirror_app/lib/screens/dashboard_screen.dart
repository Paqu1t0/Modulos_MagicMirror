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
  MirrorStatus _status = MirrorStatus.demo;
  bool _loading = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    final status = await MirrorApiService().getStatus();
    if (mounted) setState(() { _status = status; _loading = false; });
  }

  Future<void> _applyAndReset() async {
    setState(() => _applying = true);
    await MirrorApiService().restartMirror();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _applying = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Configurações aplicadas e espelho reiniciado!'),
          backgroundColor: AppTheme.success,
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
        child: _loading
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
                      const Text('Magic Mirror', style: AppTheme.headingLarge),
                      const SizedBox(height: 4),
                      Text('Control Center', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
                      const SizedBox(height: 28),

                      // Mirror Status Card
                      _MirrorStatusCard(status: _status),
                      const SizedBox(height: 24),

                      // Quick Stats
                      const Text('Quick Stats', style: AppTheme.headingMedium),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              value: '${_status.activeWidgets}',
                              label: 'Active Widgets',
                              onTap: () => widget.onNavigate(2),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _StatCard(
                              value: '${_status.savedPresets}',
                              label: 'Saved Presets',
                              onTap: () => widget.onNavigate(3),
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

// ─── Mirror Status Card ───────────────────────────────────────────────────────

class _MirrorStatusCard extends StatelessWidget {
  final MirrorStatus status;
  const _MirrorStatusCard({required this.status});

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
                    const Text('Mirror Status', style: TextStyle(
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
                        color: status.isOnline ? AppTheme.primary : AppTheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: status.isOnline ? AppTheme.success : AppTheme.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (status.isOnline ? AppTheme.success : AppTheme.error).withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatusIndicator(icon: Icons.wifi, label: 'WiFi Strong', active: status.wifiStrong),
              _StatusIndicator(icon: Icons.battery_charging_full, label: 'Powered', active: status.isPowered),
              _StatusIndicator(icon: Icons.sync, label: 'Synced', active: status.isSynced),
            ],
          ),
        ],
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
        Icon(icon, size: 22, color: active ? AppTheme.textSecondary : AppTheme.textMuted),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

// ─── Stat Card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatCard({required this.value, required this.label, this.onTap});

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
            Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
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
