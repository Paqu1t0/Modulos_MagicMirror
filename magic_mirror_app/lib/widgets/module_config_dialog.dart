import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../models/widget_model.dart';
import '../services/mirror_api_service.dart';
import '../app_theme.dart';
import 'interactive_terminal.dart';

class ModuleConfigDialog extends StatefulWidget {
  final WidgetModel module;

  const ModuleConfigDialog({super.key, required this.module});

  @override
  State<ModuleConfigDialog> createState() => _ModuleConfigDialogState();
}

class _ModuleConfigDialogState extends State<ModuleConfigDialog> {
  bool _loading = true;
  String? _error;
  
  Map<String, dynamic>? _defaults;
  Map<String, dynamic> _currentConfig = {};
  String? _readmeContent;
  
  // Fallback to raw JSON if needed
  bool _useRawJson = false;
  final _rawJsonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    // Fetch defaults from JS file
    final defaults = await MirrorApiService().getModuleDefaults(widget.module.id);
    
    // Fetch README
    final readme = await MirrorApiService().getModuleReadme(widget.module.id);
    
    // Fetch LIVE config from config.js (the truth)
    final liveConfig = await MirrorApiService().getCurrentModuleConfig(widget.module.id);
    
    // Fetch saved config from SharedPreferences (local overrides)
    final savedJsonStr = await MirrorApiService().getModuleConfig(widget.module.id);
    Map<String, dynamic> savedConfig = {};
    if (savedJsonStr != null && savedJsonStr.isNotEmpty && savedJsonStr != "{}") {
      try {
        savedConfig = json.decode(savedJsonStr);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _defaults = defaults;
        _readmeContent = readme;
        if (defaults == null || defaults.isEmpty) {
          // If no defaults found, fallback to raw JSON
          _useRawJson = true;
          // Merge liveConfig and savedConfig for the text editor
          final Map<String, dynamic> mergedForRaw = {};
          if (liveConfig != null) mergedForRaw.addAll(liveConfig);
          mergedForRaw.addAll(savedConfig);
          
          if (mergedForRaw.isNotEmpty) {
            _rawJsonController.text = const JsonEncoder.withIndent('  ').convert(mergedForRaw);
          } else {
            _rawJsonController.text = "{\n  \n}";
          }
        } else {
          // Merge order: defaults <- liveConfig <- savedConfig
          _currentConfig = Map<String, dynamic>.from(defaults);
          if (liveConfig != null) {
            liveConfig.forEach((key, value) {
              _currentConfig[key] = value;
            });
          }
          savedConfig.forEach((key, value) {
            _currentConfig[key] = value;
          });
          // Update raw JSON controller just in case user switches to it
          _rawJsonController.text = const JsonEncoder.withIndent('  ').convert(_currentConfig);
        }
        _loading = false;
      });
    }
  }

  Future<void> _saveConfig() async {
    String jsonToSave;
    
    if (_useRawJson) {
      final text = _rawJsonController.text.trim();
      if (text.isNotEmpty && text != "{}") {
        try {
          final parsed = json.decode(text);
          if (parsed is! Map<String, dynamic>) {
            setState(() => _error = 'A configuração tem de ser um objeto JSON válido {...}');
            return;
          }
          jsonToSave = text;
        } catch (e) {
          setState(() => _error = 'JSON inválido. Verifica a sintaxe.');
          return;
        }
      } else {
        jsonToSave = "{}";
      }
    } else {
      // Compare current config with original defaults to only save overrides
      final overrides = <String, dynamic>{};
      _currentConfig.forEach((key, value) {
        if (_defaults == null || _defaults![key] != value) {
          overrides[key] = value;
        }
      });
      jsonToSave = json.encode(overrides);
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    final success = await MirrorApiService().saveModuleConfig(widget.module.id, jsonToSave);
    
    if (!mounted) return;
    
    setState(() => _loading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuração guardada! Guarda o Layout para enviar para o Pi.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = 'Erro ao guardar configuração localmente.');
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o link.'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _uploadFile() async {
    String? subfolder;
    
    // Ask for subfolder first
    await showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text('Sub-pasta de destino', style: TextStyle(color: AppTheme.textPrimary)),
          content: TextField(
            controller: ctrl,
            style: TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Ex: public, images (Deixa em branco para a raiz)',
              hintStyle: TextStyle(color: AppTheme.textMuted),
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancelar', style: TextStyle(color: AppTheme.textSecondary)),
              onPressed: () {
                Navigator.pop(ctx);
                subfolder = null; // flag as cancelled
              },
            ),
            TextButton(
              child: const Text('Continuar', style: TextStyle(color: AppTheme.primary)),
              onPressed: () {
                subfolder = ctrl.text.trim();
                Navigator.pop(ctx);
              },
            ),
          ],
        );
      },
    );

    // Se carregou em Cancelar (subfolder ficou null)
    if (subfolder == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(withData: true);
      if (result != null && result.files.single.bytes != null) {
        final file = result.files.single;
        final fileBytes = file.bytes!;
        
        setState(() => _loading = true);
        
        final success = await MirrorApiService().uploadModuleFile(widget.module.id, file.name, fileBytes, subfolder: subfolder);
        
        setState(() => _loading = false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Ficheiro ${file.name} enviado com sucesso!' : 'Erro ao enviar ficheiro.'),
              backgroundColor: success ? AppTheme.success : AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao escolher ficheiro.'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Widget _buildDynamicForm() {
    if (_defaults == null || _defaults!.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Não foi possível extrair o formulário automaticamente. Usa o Modo Avançado.',
            style: TextStyle(color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _currentConfig.keys.map((key) {
        final val = _currentConfig[key];
        
        if (val is bool) {
          return SwitchListTile(
            title: Text(key, style: TextStyle(color: AppTheme.textPrimary)),
            activeThumbColor: AppTheme.accent,
            value: val,
            contentPadding: EdgeInsets.zero,
            onChanged: (newVal) {
              setState(() => _currentConfig[key] = newVal);
            },
          );
        } else if (val is num) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              initialValue: val.toString(),
              keyboardType: TextInputType.number,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: key,
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
              ),
              onChanged: (newVal) {
                final n = num.tryParse(newVal);
                if (n != null) {
                  _currentConfig[key] = n;
                }
              },
            ),
          );
        } else {
          // Strings or anything else
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextFormField(
              initialValue: val.toString(),
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: key,
                labelStyle: TextStyle(color: AppTheme.textSecondary),
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
              ),
              onChanged: (newVal) {
                _currentConfig[key] = newVal;
              },
            ),
          );
        }
      }).toList(),
    );
  }

  Widget _buildRawJsonEditor() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _error != null ? AppTheme.error : AppTheme.border),
      ),
      child: TextField(
        controller: _rawJsonController,
        maxLines: 10,
        style: TextStyle(
          fontFamily: 'monospace',
          color: AppTheme.textPrimary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
          hintText: '{\n  "clientId": "123",\n  "clientSecret": "456"\n}',
          hintStyle: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }

  Widget _buildConfigTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_defaults != null && _defaults!.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Modo Avançado (JSON)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  Switch(
                    value: _useRawJson,
                    activeThumbColor: AppTheme.accent,
                    onChanged: (v) {
                      setState(() {
                        if (v) {
                          // Convert current config back to string to show in JSON editor
                          _rawJsonController.text = const JsonEncoder.withIndent('  ').convert(_currentConfig);
                        } else {
                          // Try to parse back to currentConfig
                          try {
                            final parsed = json.decode(_rawJsonController.text);
                            if (parsed is Map<String, dynamic>) {
                              _currentConfig = parsed;
                            }
                          } catch (_) {}
                        }
                        _useRawJson = v;
                      });
                    },
                  ),
                ],
              ),
            _useRawJson ? _buildRawJsonEditor() : _buildDynamicForm(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadmeTab() {
    if (_readmeContent == null) {
      return Center(
        child: Text(
          'Documentação não encontrada para este módulo.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    
    return Column(
      children: [
        if (widget.module.repoUrl != null && widget.module.repoUrl!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Abrir GitHub / Site Oficial'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  side: const BorderSide(color: AppTheme.accent),
                ),
                onPressed: () => _launchUrl(widget.module.repoUrl!),
              ),
            ),
          ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Markdown(
              data: _readmeContent!,
              selectable: true,
              onTapLink: (text, href, title) {
                if (href != null) _launchUrl(href);
              },
              styleSheet: MarkdownStyleSheet(
                h1: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                h2: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                h3: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                p: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                a: const TextStyle(color: AppTheme.accent, decoration: TextDecoration.underline),
                code: TextStyle(backgroundColor: AppTheme.iconBg, color: AppTheme.primaryDark, fontFamily: 'monospace'),
                codeblockDecoration: BoxDecoration(
                  color: AppTheme.iconBg,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardBg,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: DefaultTabController(
        length: 3,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.settings, color: AppTheme.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Config: ${widget.module.name}',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.upload_file, color: AppTheme.accent),
                      tooltip: 'Upload Ficheiro para o Módulo',
                      onPressed: _loading ? null : _uploadFile,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Tabs
                TabBar(
                  labelColor: AppTheme.accent,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.accent,
                  tabs: [
                    Tab(text: 'Formulário'),
                    Tab(text: 'Docs'),
                    Tab(text: 'Terminal'),
                  ],
                ),
                
                if (_loading)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildConfigTab(),
                        _buildReadmeTab(),
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: InteractiveTerminal(
                            initialCommand: 'cd \$HOME/MagicMirror/modules/${widget.module.id}',
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _loading ? null : _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}