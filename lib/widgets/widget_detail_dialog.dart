import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/widget_model.dart';
import '../services/mirror_api_service.dart';
import 'module_config_dialog.dart';

/// Modo do diálogo: instalar (catálogo) ou gerir (instalado).
enum WidgetDialogMode { install, manage }

class WidgetDetailDialog extends StatefulWidget {
  final WidgetModel widget;
  final WidgetDialogMode mode;
  final VoidCallback? onActionDone;

  /// Callback legado para compatibilidade (install).
  final VoidCallback? onInstalled;

  const WidgetDetailDialog({
    super.key,
    required this.widget,
    this.mode = WidgetDialogMode.install,
    this.onActionDone,
    this.onInstalled,
  });

  @override
  State<WidgetDetailDialog> createState() => _WidgetDetailDialogState();
}

class _WidgetDetailDialogState extends State<WidgetDetailDialog> {
  bool _loading = false;
  String? _actionLabel;

  Future<void> _handleInstall() async {
    // Passo 1: Clonar repositório
    setState(() { _loading = true; _actionLabel = 'A instalar...'; });
    await Future.delayed(const Duration(milliseconds: 200));

    final success = await MirrorApiService().installModule(
      widget.widget.id,
      repoUrl: widget.widget.repoUrl,
    );

    if (!mounted) return;

    if (success) {
      // Passo 2: Simular feedback de instalação de dependências
      setState(() { _actionLabel = '📦 A instalar dependências (npm)...'; });
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() { _actionLabel = '✔️ Concluído!'; });
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      setState(() { _loading = false; _actionLabel = null; });
      widget.onInstalled?.call();
      widget.onActionDone?.call(); // Dispara refresh + muda para tab instalados
      if (mounted) Navigator.of(context).pop(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${widget.widget.name} instalado! Já aparece nos teus módulos.'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } else {
      setState(() { _loading = false; _actionLabel = null; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Erro ao instalar. Verifica a ligação SSH nas Definições.'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _handleRemove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Confirmar Remoção', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text(
          'Tens a certeza que queres remover "${widget.widget.name}"?\nEsta ação apaga a pasta do módulo no Pi.',
          style: AppTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() { _loading = true; _actionLabel = 'A remover...'; });
    final success = await MirrorApiService().removeModule(widget.widget.id);
    if (!mounted) return;
    setState(() { _loading = false; _actionLabel = null; });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${widget.widget.name} removido com sucesso!'
              : 'Erro ao remover. Verifica a ligação SSH.'),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    if (success) {
      widget.onActionDone?.call();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _handleUpdate() async {
    setState(() { _loading = true; _actionLabel = 'A atualizar...'; });
    
    bool success;
    if (widget.widget.isOurs) {
      // Para os nossos módulos, "atualizar" significa re-enviar os ficheiros locais (assets)
      success = await MirrorApiService().installModule(widget.widget.id);
    } else {
      // Para repositórios do GitHub, usamos o git pull
      success = await MirrorApiService().updateModule(widget.widget.id);
    }
    
    if (!mounted) return;
    setState(() { _loading = false; _actionLabel = null; });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${widget.widget.name} atualizado com sucesso!'
              : 'Erro ao atualizar. Verifica a ligação SSH.'),
          backgroundColor: success ? AppTheme.success : AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    if (success) {
      widget.onActionDone?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.widget;
    final isManage = widget.mode == WidgetDialogMode.manage;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + badges
            Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(w.icon, size: 28, color: AppTheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.name, style: AppTheme.headingMedium),
                      const SizedBox(height: 4),
                      Text(w.category, style: AppTheme.labelPrimary),
                    ],
                  ),
                ),
                if (w.stars > 0)
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: AppTheme.warning),
                      const SizedBox(width: 3),
                      Text('${w.stars}', style: AppTheme.bodySmall),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            Text(w.description, style: AppTheme.bodyMedium),

            // Repo URL (se disponível)
            if (w.repoUrl != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.link, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(w.repoUrl!, style: AppTheme.bodySmall,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],

            // Aviso se o módulo estiver arquivado ou descontinuado
            if (w.isArchived || (w.outdated != null && w.outdated!.isNotEmpty)) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        w.outdated ?? 'Este módulo foi arquivado pelo autor e pode não funcionar corretamente no MagicMirror.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Loading indicator
            if (_loading)
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(_actionLabel ?? '', style: AppTheme.bodySmall),
                  ],
                ),
              )
            else if (isManage) ...[
              // ── Modo GERIR (instalado) ────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleUpdate,
                      icon: const Icon(Icons.system_update_alt, size: 18),
                      label: const Text('Atualizar', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => ModuleConfigDialog(module: widget.widget),
                        );
                      },
                      icon: const Icon(Icons.settings_applications, size: 18),
                      label: const Text('Config JSON', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: AppTheme.border),
                        foregroundColor: AppTheme.textSecondary,
                      ),
                      child: const Text('Fechar', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _handleRemove,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remover', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppTheme.error),
                        foregroundColor: AppTheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // ── Modo INSTALAR (catálogo) ──────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: AppTheme.border),
                        foregroundColor: AppTheme.textSecondary,
                      ),
                      child: const Text('Fechar', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: w.isInstalled ? null : _handleInstall,
                      icon: Icon(w.isInstalled ? Icons.check : Icons.download, size: 18),
                      label: Text(
                        w.isInstalled ? 'Instalado' : 'Instalar',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}