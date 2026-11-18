import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:provider/provider.dart';

import 'providers/editor_provider.dart';
import 'widgets/format_toolbar.dart';
import 'widgets/text_editor_panel.dart';

class PdfGeneratorApp extends StatelessWidget {
  const PdfGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Convert Printer',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late EditorProvider _provider;
  StreamSubscription? _notifSub;
  StreamSubscription<String>? _imageSub;

  @override
  void initState() {
    super.initState();
    _provider = EditorProvider();
    _provider.initialize();
    _notifSub = _provider.onNotification.listen((msg) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
                ],
              ),
              backgroundColor: const Color(0xFF1565C0),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    });
    _imageSub = _provider.onImagePreview.listen((path) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (ctx) => _ImagePreviewDialog(
            path: path,
            provider: _provider,
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _imageSub?.cancel();
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<EditorProvider>(
        builder: (context, provider, _) {
          return Scaffold(
            body: Column(
              children: [
                FormatToolbar(provider: provider),
                Expanded(
                  child: TextEditorPanel(provider: provider),
                ),
                _buildStatusBar(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBar(EditorProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: const Border(
          top: BorderSide(color: Color(0xFFB0B0B0)),
        ),
      ),
      child: Row(
        children: [
          Text(
            '字数: ${provider.charCount}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
          ),
          const Spacer(),
          if (provider.isComputing)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                SizedBox(width: 4),
                Text(
                  '生成�?..',
                  style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ImagePreviewDialog extends StatefulWidget {
  final String path;
  final EditorProvider provider;

  const _ImagePreviewDialog({
    required this.path,
    required this.provider,
  });

  @override
  State<_ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<_ImagePreviewDialog> {
  bool _printing = false;

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      await widget.provider.printImagePreview(widget.path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('图片打印失败: $e')),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('图片预览'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 620,
          maxHeight: 620,
        ),
        child: InteractiveViewer(
          child: Image.file(
            File(widget.path),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Text('图片无法打开'),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _printing ? null : () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        FilledButton.icon(
          onPressed: _printing ? null : _print,
          icon: _printing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.print, size: 18),
          label: Text(_printing ? '打印中...' : '打印'),
        ),
      ],
    );
  }
}

