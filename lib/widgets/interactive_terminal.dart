import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';
import '../services/ssh_service.dart';
import '../app_theme.dart';

class InteractiveTerminal extends StatefulWidget {
  final String initialCommand;

  const InteractiveTerminal({super.key, required this.initialCommand});

  @override
  State<InteractiveTerminal> createState() => _InteractiveTerminalState();
}

class _InteractiveTerminalState extends State<InteractiveTerminal> {
  final List<String> _outputLines = [];
  final _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  SSHSession? _session;
  bool _connecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initTerminal();
  }

  Future<void> _initTerminal() async {
    setState(() {
      _connecting = true;
      _error = null;
      _outputLines.add('--- A Ligar ao Raspberry Pi ---');
    });

    try {
      _session = await SshService().startInteractiveShell();
      if (_session == null) {
        setState(() {
          _error = 'Falha ao iniciar sessão SSH.';
          _outputLines.add('Erro: $_error');
          _connecting = false;
        });
        return;
      }

      setState(() {
        _connecting = false;
        _outputLines.add('--- Ligado com sucesso! ---');
      });

      // Listen to stdout
      _session!.stdout.listen((Uint8List data) {
        final text = utf8.decode(data);
        _appendOutput(text);
      }, onDone: () {
        _appendOutput('\n--- Sessão fechada ---');
      }, onError: (e) {
        _appendOutput('\nErro: $e');
      });

      // Send the initial command (e.g. cd into the module directory)
      Future.delayed(const Duration(milliseconds: 500), () {
        _sendCommand(widget.initialCommand);
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
        _outputLines.add('Erro de Ligação: $_error');
        _connecting = false;
      });
    }
  }

  void _appendOutput(String text) {
    if (!mounted) return;
    
    // Strip ANSI escape codes (CSI colors and OSC window titles)
    final ansiRegex = RegExp(r'\x1B(?:\[[0-?]*[ -/]*[@-~]|].*?(?:\x07|\x1B\\))');
    text = text.replaceAll(ansiRegex, '');
    
    // We get chunks of text. They might contain multiple newlines, or incomplete lines.
    // For a simple chat-like terminal, we just split by \n and add to our lines array.
    final newLines = text.split('\n');
    
    setState(() {
      if (_outputLines.isNotEmpty && !text.startsWith('\n')) {
        // Append to the last line if it didn't start with a newline (this handles prompt streams)
        _outputLines[_outputLines.length - 1] += newLines.first;
        if (newLines.length > 1) {
          _outputLines.addAll(newLines.sublist(1));
        }
      } else {
        _outputLines.addAll(newLines);
      }
    });
    
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendCommand(String cmd) {
    if (_session != null) {
      _appendOutput('\n> $cmd');
      // Enviar CRLF para garantir que o Enter é reconhecido
      _session!.stdin.add(Uint8List.fromList(utf8.encode('$cmd\r\n')));
    }
  }

  void _handleSubmit() {
    final text = _inputController.text;
    if (text.isNotEmpty) {
      _sendCommand(text);
      _inputController.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _session?.close();
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E), // Dark terminal background
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: _connecting
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _outputLines.length,
                    itemBuilder: (context, index) {
                      return Text(
                        _outputLines[index],
                        style: const TextStyle(
                          color: Color(0xFFE0E0E0), // Light terminal text
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                style: TextStyle(color: AppTheme.textPrimary, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Escreve o comando e clica Enter...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onSubmitted: (_) => _handleSubmit(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              color: AppTheme.accent,
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ],
    );
  }
}