import 'package:flutter/material.dart';

import '../constants/page_config.dart';
import '../providers/editor_provider.dart';
import 'landrop_panel.dart';

class FormatToolbar extends StatelessWidget {
  final EditorProvider provider;

  const FormatToolbar({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFB0B0B0)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFontSizeControl(),
                  _buildDivider(),
                  _buildFontSelector(context),
                  _buildDivider(),
                  _buildAlignmentControl(context),
                  _buildDivider(),
                  _buildLineSpacingControl(),
                  _buildDivider(),
                  _buildMarginControl(context),
                  _buildDivider(),
                  _buildPageSizeButton(context),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const SizedBox(
      height: 24,
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: Color(0xFFB0B0B0),
      ),
    );
  }

  TextAlign _effectiveAlignment() {
    switch (provider.selectionAlign) {
      case 'left':
        return TextAlign.left;
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
    }
    return provider.format.textAlign == TextAlign.justify
        ? TextAlign.left
        : provider.format.textAlign;
  }

  Widget _buildFontSizeControl() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.format_size, size: 18),
        const SizedBox(width: 4),
        SizedBox(
          width: 140,
          child: Slider(
            value: provider.format.fontSize,
            min: PageConfig.minFontSize,
            max: PageConfig.maxFontSize,
            divisions: ((PageConfig.maxFontSize - PageConfig.minFontSize) / 0.5)
                .round(),
            label: '${provider.format.fontSize.toStringAsFixed(1)}pt',
            onChanged: provider.setFontSize,
          ),
        ),
        const SizedBox(width: 6),
        _buildFontSizeSelector(),
      ],
    );
  }

  static const _fontSizePresets = <double>[
    8,
    9,
    10,
    10.5,
    11,
    12,
    14,
    15,
    16,
    18,
    20,
    22,
    24,
    26,
    28,
    32,
    36,
    42,
    48,
    56,
    64,
    72,
  ];

  String _ptLabel(double value) => value == value.roundToDouble()
      ? '${value.round()} pt'
      : '${value.toStringAsFixed(1)} pt';

  Widget _buildFontSizeSelector() {
    final current = provider.format.fontSize;
    final values = <double>{..._fontSizePresets, current}.toList()..sort();
    return PopupMenuButton<double>(
      tooltip: '字号',
      initialValue: current,
      onSelected: provider.setFontSize,
      itemBuilder: (_) => [
        for (final value in values)
          PopupMenuItem<double>(
            value: value,
            height: 34,
            child: Text(
              _ptLabel(value),
              style: const TextStyle(fontSize: 13),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFBDBDBD)),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_ptLabel(current), style: const TextStyle(fontSize: 12)),
            const Icon(Icons.arrow_drop_down, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildFontSelector(BuildContext context) {
    final names = provider.fontNames;
    return PopupMenuButton<int>(
      tooltip: 'Font',
      initialValue: provider.currentFontIndex,
      onSelected: provider.setFontIndex,
      itemBuilder: (_) => List.generate(names.length, (i) {
        return PopupMenuItem(value: i, child: Text(names[i], style: const TextStyle(fontSize: 12)));
      }),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.font_download, size: 18),
          const SizedBox(width: 2),
          Text(provider.currentFontName, style: const TextStyle(fontSize: 12)),
          const Icon(Icons.arrow_drop_down, size: 16),
        ],
      ),
    );
  }

  Widget _buildAlignmentControl(BuildContext context) {
    final align = _effectiveAlignment();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _alignButton(context, Icons.format_align_left, TextAlign.left, align),
        _alignButton(
            context, Icons.format_align_center, TextAlign.center, align),
        _alignButton(
            context, Icons.format_align_right, TextAlign.right, align),
      ],
    );
  }

  Widget _alignButton(BuildContext context, IconData icon, TextAlign value,
      TextAlign current) {
    final isSelected = current == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: () => provider.setAlignment(value),
        tooltip: value.name,
        style: IconButton.styleFrom(
          backgroundColor:
              isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
          minimumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildLineSpacingControl() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('行距', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        SizedBox(
          width: 100,
          child: Slider(
            value: provider.format.lineSpacing,
            min: PageConfig.minLineSpacing,
            max: PageConfig.maxLineSpacing,
            divisions:
                ((PageConfig.maxLineSpacing - PageConfig.minLineSpacing) / 0.25)
                    .round(),
            label: '${provider.format.lineSpacing.toStringAsFixed(2)}x',
            onChanged: provider.setLineSpacing,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${provider.format.lineSpacing.toStringAsFixed(1)}x',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildMarginControl(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '页边距',
      icon: const Icon(Icons.margin, size: 20),
      onSelected: (value) {
        _showMarginDialog(context);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'custom', child: Text('自定义页边距...')),
        const PopupMenuItem(value: 'normal', child: Text('正常 (25.4 mm)')),
        const PopupMenuItem(value: 'narrow', child: Text('窄 (12.7 mm)')),
        const PopupMenuItem(value: 'wide', child: Text('宽 (38.1 mm)')),
      ],
    );
  }

  void _showMarginDialog(BuildContext context) {
    const pointsPerMm = 72 / 25.4;
    showDialog(
      context: context,
      builder: (ctx) {
        var top = provider.format.marginTop / pointsPerMm;
        var bottom = provider.format.marginBottom / pointsPerMm;
        var left = provider.format.marginLeft / pointsPerMm;
        var right = provider.format.marginRight / pointsPerMm;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('自定义页边距 (mm)'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _marginRow('上', top, (v) => setLocal(() => top = v)),
                    _marginRow('下', bottom, (v) => setLocal(() => bottom = v)),
                    _marginRow('左', left, (v) => setLocal(() => left = v)),
                    _marginRow('右', right, (v) => setLocal(() => right = v)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    provider.setMarginTop(top * pointsPerMm);
                    provider.setMarginBottom(bottom * pointsPerMm);
                    provider.setMarginLeft(left * pointsPerMm);
                    provider.setMarginRight(right * pointsPerMm);
                    Navigator.pop(ctx);
                  },
                  child: const Text('应用'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _marginRow(
      String label, double value, ValueChanged<double> onChanged) {
    const pointsPerMm = 72 / 25.4;
    final minMm = PageConfig.minMargin / pointsPerMm;
    final maxMm = PageConfig.maxMargin / pointsPerMm;
    return Row(
      children: [
        SizedBox(width: 24, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(minMm, maxMm),
            min: minMm,
            max: maxMm,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 58,
          child: Text(
            '${value.toStringAsFixed(1)} mm',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPageSizeButton(BuildContext context) {
    return PopupMenuButton<PageSizeType>(
      tooltip: '页面尺寸',
      initialValue: provider.format.pageSizeType,
      onSelected: provider.setPageSizeType,
      itemBuilder: (_) => PageSizeType.values.map((t) {
        return PopupMenuItem(value: t, child: Text('${t.label} 纸张'));
      }).toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined, size: 18),
          const SizedBox(width: 2),
          Text(provider.format.pageSizeType.label,
              style: const TextStyle(fontSize: 12)),
          const Icon(Icons.arrow_drop_down, size: 16),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionButton(
          context,
          icon: Icons.qr_code_2,
          label: '二维码转送',
          onPressed: () => _showTransferDialog(context),
          isSecondary: true,
        ),
        const SizedBox(width: 6),
        FilledButton.icon(
          onPressed: provider.isInitialized ? () => _printNow(context) : null,
          icon: const Icon(Icons.print, size: 16),
          label: const Text('打印', style: TextStyle(fontSize: 12)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        PopupMenuButton<String>(
          tooltip: '更多',
          onSelected: (value) {
            if (value == 'newA4') {
              _confirmNewA4(context);
            } else if (value == 'export') {
              _exportNow(context);
            } else if (value == 'clear') {
              _confirmClear(context);
            }
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem<String>(
              value: 'newA4',
              child: Row(
                children: [
                  Icon(Icons.note_add_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('新建 A4 纸面', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.save_alt, size: 18),
                  SizedBox(width: 8),
                  Text('导出 PDF', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 18),
                  SizedBox(width: 8),
                  Text('删除内容', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.more_horiz, size: 20),
          ),
        ),
      ],
    );
  }

  Future<void> _showTransferDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_2, size: 20),
            SizedBox(width: 8),
            Text('二维码文章转送', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: SingleChildScrollView(
              child: LanTransferPanel(
                provider: provider,
                onTransferComplete: () {
                  if (Navigator.of(ctx).canPop()) {
                    Navigator.of(ctx).pop();
                  }
                },
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _printNow(BuildContext context) async {
    try {
      final ok = await provider.printCurrentPdf();
      if (!context.mounted) return;
      if (!ok) {
        _showMessage(context, 'PDF 尚未准备好，请稍后重试');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showMessage(context, '打印失败: $e');
    }
  }

  Future<void> _exportNow(BuildContext context) async {
    try {
      final ok = await provider.shareCurrentPdf();
      if (!context.mounted) return;
      if (!ok) {
        _showMessage(context, 'PDF 尚未准备好，请稍后重试');
      }
    } catch (e) {
      if (!context.mounted) return;
      _showMessage(context, '导出失败: $e');
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmNewA4(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建 A4 纸面'),
        content: const Text('将清空当前内容，并新建一张默认 A4 纸面。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('新建'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      provider.newA4Document();
    }
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除内容'),
        content: const Text('确定删除编辑器中的全部内容？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
      provider.clearDocument();
    }
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isSecondary = false,
  }) {
    return isSecondary
        ? OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
          )
        : FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: Size.zero,
            ),
          );
  }
}
