# Convert Printer

基于 Flutter 的 Windows 桌面应用，集文本编辑、PDF 实时生成、手机扫描 OCR 与局域网双向文件传输于一体。

## 项目描述

Convert Printer 是一款跨设备协作工具。用户在 PC 端编辑文章，右侧实时预览 PDF 排版效果，支持四种中文字体切换、字号/对齐/行距/段距/页边距精细调节，生成后可直接调用 Windows 打印。

内置局域网传输模块（HTTP + WebSocket），手机扫描 QR 码即可连接。手机端支持拍照 OCR（Tesseract.js 中文识别），扫描结果自动发送到 PC 编辑器。PC 端可一键推送文本、PDF 或任意文件到手机。编辑器内容和格式设置本地自动保存，重启不丢失。

**核心亮点：**
- 实时 PDF 排版引擎（自动换行、分页、页眉页脚）
- 四种中文字体（黑体/楷体/仿宋/宋体）
- 手机拍照 OCR → PC 编辑 → PDF 打印 全链路
- 局域网双向传输（QR 码 + WebSocket 推送通知）
- Windows 原生 .exe，双击即用
- 全部数据本地存储，零网络依赖

**技术栈：** Flutter/Dart · PDF Engine · HTTP Server · WebSocket · Tesseract.js OCR

**适用场景：** 快速排版打印 · 会议记录 OCR · 跨设备文件交换 · 课堂笔记整理

## 快速开始

```bash
# 安装依赖
flutter pub get

# 安装中文字体
.\setup_fonts.ps1

# 运行
flutter run -d windows
```

## 构建

```bash
flutter build windows --release
# 输出: build/windows/x64/runner/Release/ConvertPrinter.exe
```

## 许可证

MIT
