# Convert Printer

一款基于 Flutter 的 Windows 桌面应用，支持文本编辑、实时生成 PDF、手机 OCR 扫描，以及局域网双向文件传输。

[English README](README.md)

## 项目简介

Convert Printer 是一款跨设备生产力工具。你可以在电脑上编辑文本，并实时预览 PDF 排版效果。编辑器支持四种中文字体，以及字号、对齐方式、行距、段距和页边距调整。文档完成后，可以直接调用 Windows 打印机进行打印。

内置的局域网传输模块使用 HTTP 和 WebSocket 连接。手机扫描二维码即可连接电脑，并可使用 Tesseract.js 拍照进行 OCR，将识别出的文字自动发送到电脑编辑器。电脑端也可以一键将文本、PDF 或其他文件发送到手机。编辑器内容和格式设置会保存在本地，应用重启后可以自动恢复。

**主要功能：**
- 实时 PDF 排版引擎，支持自动换行、分页、页眉和页脚
- 四种中文字体：黑体、楷体、仿宋和宋体
- 完整工作流：手机 OCR → 电脑编辑 → PDF 打印
- 基于二维码配对和 WebSocket 通知的局域网双向传输
- 原生 Windows `.exe` 应用
- 数据保存在本地，不依赖云服务

**技术栈：** Flutter/Dart · PDF 引擎 · HTTP 服务器 · WebSocket · Tesseract.js OCR

**适用场景：** 快速排版和打印 · 会议记录 OCR · 跨设备文件交换 · 课堂笔记整理

## 快速开始

```bash
# 安装依赖
flutter pub get

# 安装中文字体
.\setup_fonts.ps1

# 运行应用
flutter run -d windows
```

## 构建应用

```bash
flutter build windows --release
# 输出：build/windows/x64/runner/Release/ConvertPrinter.exe
```

## 许可证

MIT
