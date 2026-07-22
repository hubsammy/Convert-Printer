import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'constants/page_config.dart';
import 'providers/editor_provider.dart';
import 'widgets/format_toolbar.dart';
import 'widgets/text_editor_panel.dart';
import 'widgets/pdf_preview_panel.dart';

class PdfGeneratorApp extends StatelessWidget {
  const PdfGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Convert Printer',
      debugShowCheckedModeBanner: false,
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
  }

  @override
  void dispose() {
    _notifSub?.cancel();
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
                  child: _buildMainContent(provider),
                ),
                _buildStatusBar(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(EditorProvider provider) {
    return Row(
      children: [
        SizedBox(
          width: 400,
          child: TextEditorPanel(provider: provider),
        ),
        Container(
          width: 4,
          color: const Color(0xFFE0E0E0),
          child: Center(
            child: Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Expanded(
          child: PdfPreviewPanel(provider: provider),
        ),
      ],
    );
  }

  Widget _buildStatusBar(EditorProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: const Border(
          top: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      child: Row(
        children: [
          Text(
            '字数: ${provider.charCount}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
          ),
          const SizedBox(width: 24),
          Text(
            '页数: ${provider.pageCount}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
          ),
          const SizedBox(width: 24),
          Text(
            '字号: ${provider.format.fontSize.toStringAsFixed(0)}pt',
            style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
          ),
          const SizedBox(width: 24),
          Text(
            '纸张: ${provider.format.pageSizeType.label}',
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
                  '生成中...',
                  style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
