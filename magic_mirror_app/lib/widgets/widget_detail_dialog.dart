import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/widget_model.dart';
import '../services/mirror_api_service.dart';

class WidgetDetailDialog extends StatefulWidget {
  final WidgetModel widget;
  final VoidCallback? onInstalled;

  const WidgetDetailDialog({
    super.key,
    required this.widget,
    this.onInstalled,
  });

  @override
  State<WidgetDetailDialog> createState() => _WidgetDetailDialogState();
}

class _WidgetDetailDialogState extends State<WidgetDetailDialog> {
  bool _loading = false;

  Future<void> _handleInstall() async {
    setState(() => _loading = true);
    final success = await MirrorApiService().installModule(widget.widget.id);
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      widget.onInstalled?.call();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.widget.name} instalado com sucesso!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erro ao instalar. Verifica a ligação ao Pi.'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                widget.widget.icon,
                size: 28,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            // Name
            Text(widget.widget.name, style: AppTheme.headingMedium),
            const SizedBox(height: 4),
            // Category
            Text(widget.widget.category, style: AppTheme.labelPrimary),
            const SizedBox(height: 12),
            // Description
            Text(widget.widget.description, style: AppTheme.bodyMedium),
            const SizedBox(height: 20),
            // Preview box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preview', style: AppTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text(
                    'Widget preview would appear here',
                    style: AppTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: AppTheme.border),
                      foregroundColor: AppTheme.textSecondary,
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading || widget.widget.isInstalled ? null : _handleInstall,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.download, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                widget.widget.isInstalled ? 'Installed' : 'Install',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
