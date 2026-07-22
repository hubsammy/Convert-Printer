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
          bottom: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
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
            _buildParagraphSpacingControl(),
            _buildDivider(),
            _buildMarginControl(context),
            _buildDivider(),
            _buildPageSizeButton(context),
            const SizedBox(width: 24),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const SizedBox(
      height: 24,
      child: VerticalDivider(width: 1, thickness: 1),
    );
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
        SizedBox(
          width: 48,
          child: Text(
            '${provider.format.fontSize.toStringAsFixed(0)}pt',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
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
    final align = provider.format.textAlign;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _alignButton(context, Icons.format_align_left, TextAlign.left, align),
        _alignButton(
            context, Icons.format_align_center, TextAlign.center, align),
        _alignButton(
            context, Icons.format_align_right, TextAlign.right, align),
        _alignButton(
            context, Icons.format_align_justify, TextAlign.justify, align),
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

  Widget _buildParagraphSpacingControl() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('段距', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        SizedBox(
          width: 100,
          child: Slider(
            value: provider.format.paragraphSpacing,
            min: PageConfig.minParagraphSpacing,
            max: PageConfig.maxParagraphSpacing,
            divisions:
                ((PageConfig.maxParagraphSpacing - PageConfig.minParagraphSpacing) / 2)
                    .round(),
            label: '${provider.format.paragraphSpacing.toStringAsFixed(0)}pt',
            onChanged: provider.setParagraphSpacing,
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '${provider.format.paragraphSpacing.toStringAsFixed(0)}pt',
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
        const PopupMenuItem(value: 'normal', child: Text('正常 (72pt / 1英寸)')),
        const PopupMenuItem(value: 'narrow', child: Text('窄 (36pt / 0.5英寸)')),
        const PopupMenuItem(value: 'wide', child: Text('宽 (108pt / 1.5英寸)')),
      ],
    );
  }

  void _showMarginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        var top = provider.format.marginTop;
        var bottom = provider.format.marginBottom;
        var left = provider.format.marginLeft;
        var right = provider.format.marginRight;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('自定义页边距 (pt)'),
              content: SizedBox(
                width: 300,
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
                    provider.setMarginTop(top);
                    provider.setMarginBottom(bottom);
                    provider.setMarginLeft(left);
                    provider.setMarginRight(right);
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
    return Row(
      children: [
        SizedBox(width: 24, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: PageConfig.minMargin,
            max: PageConfig.maxMargin,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${value.toStringAsFixed(0)}pt',
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
        _buildLandropButton(context),
        const SizedBox(width: 8),
        _actionButton(
          context,
          icon: Icons.print,
          label: '打印',
          onPressed: () async {
            if (provider.pdfData != null) {
              await provider.printService.printPdf(provider.pdfData!);
            }
          },
        ),
        const SizedBox(width: 4),
        _actionButton(
          context,
          icon: Icons.save_alt,
          label: '导出PDF',
          onPressed: () async {
            if (provider.pdfData != null) {
              await provider.printService
                  .sharePdf(provider.pdfData!, fileName: 'article.pdf');
            }
          },
        ),
        const SizedBox(width: 4),
        _actionButton(
          context,
          icon: Icons.refresh,
          label: '重新生成',
          onPressed: () => provider.rebuildLayout(),
          isSecondary: true,
        ),
      ],
    );
  }

  Widget _buildLandropButton(BuildContext context) {
    final isRunning = provider.landropService.isRunning;
    return Tooltip(
      message: isRunning ? 'LANDrop connected' : 'LANDrop disconnected',
      child: IconButton(
        icon: Stack(
          children: [
            const Icon(Icons.wifi, size: 20),
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRunning ? Colors.green : Colors.red,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
          ],
        ),
        onPressed: () => LandropPanel.show(context, provider),
        tooltip: 'LANDrop 接收文件',
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
        ),
      ),
    );
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
