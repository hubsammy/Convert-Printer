# Convert Printer

基于 Flutter 的 Windows 桌面应用，集文本编辑、PDF 实时生成、手机扫描 OCR 与局域网双向文件传输于一体。

## Overview

Convert Printer 是一款跨设备协作工具。用户在 PC 端编辑文章，右侧实时预览 PDF 排版效果，支持四种中文字体切换、字号/对齐/行距/段距/页边距精细调节，生成后可直接调用 Windows 打印。

内置局域网传输模块（HTTP + WebSocket），手机扫描 QR 码即可连接。手机端支持拍照 OCR（Tesseract.js 中文识别），扫描结果自动发送到 PC 编辑器。PC 端可一键推送文本、PDF 或任意文件到手机。编辑器内容和格式设置本地自动保存，重启不丢失。

**Core Highlights:**
- 实时 PDF 排版引擎（自动换行、分页、页眉页脚）
- 四种中文字体（黑体/楷体/仿宋/宋体）
- 手机拍照 OCR → PC 编辑 → PDF 打印 全链路
- 局域网双向传输（QR 码 + WebSocket 推送通知）
- Windows 原生 .exe，双击即用
- 全部数据本地存储，零网络依赖

**Tech Stack:** Flutter/Dart · PDF Engine · HTTP Server · WebSocket · Tesseract.js OCR

**Use Cases:** 快速排版打印 · 会议记录 OCR · 跨设备文件交换 · 课堂笔记整理

## Features

### PDF Generation
- Real-time PDF preview as you type
- 4 Chinese fonts: Hei Ti (黑体), Kai Ti (楷体), Fang Song (仿宋), Song Ti (宋体)
- Adjustable font size (8-72pt), text alignment, line spacing (1-3x), paragraph spacing (0-40pt)
- Customizable page margins (20-120pt)
- A4 / Letter paper size switching
- Auto pagination with page numbers
- Windows native print support

### LAN Transfer
- Built-in LANDrop protocol server (TCP 45874)
- HTTP server + QR code (TCP 8080) for mobile browser access
- Phone → PC: send text directly to editor, upload images/audio/files
- PC → Phone: push text, PDF, or any file via WebSocket notification
- Auto-discovery via subnet TCP scanning
- Real-time file receive notifications

### Persistence
- Editor text auto-save (`_editor_autosave.txt`)
- Format settings saved (`_editor_config.json`)
- Survives app restart and disconnection

## Quick Start

```bash
# 1. Install dependencies
flutter pub get

# 2. Copy Chinese fonts from Windows
.\setup_fonts.ps1

# 3. Run
flutter run -d windows
```

## Usage

### Editor
```
┌──────────────────────────────────────────────────┐
│ [Font Size] [Font] [Align] [Line] [Para] [Print] │ ← Toolbar
├────────────────────┬─────────────────────────────┤
│  Text Editor       │  PDF Preview                │
│  (input article)   │  (real-time rendering)      │
├────────────────────┴─────────────────────────────┤
│  Words: 123  |  Pages: 3  |  Font: 14pt  |  A4   │
└──────────────────────────────────────────────────┘
```

### LAN Transfer Panel
```
┌─ LAN Transfer ──────────────┐
│ Service RUNNING             │
│ TCP:45874  HTTP:192.168.x.x │
│ ┌───QR Code───┐             │
│ └─────────────┘             │
│ [Send Text] [Send PDF] [Send File] │
└─────────────────────────────┘
```

### Phone ↔ PC Transfer

| Direction | How |
|-----------|-----|
| Phone → PC Text | Scan QR → type → [Send to PC] |
| Phone → PC Files | Scan QR → choose files → [Upload to PC] |
| PC → Phone Text | Click [Send Text] in LAN panel |
| PC → Phone PDF | Click [Send PDF] in LAN panel |
| PC → Phone File | Click [Send File] → choose any file |

### Font Selection

Click the font dropdown in the toolbar to switch fonts. PDF preview updates instantly.

| Font | Name | Style |
|------|------|-------|
| Hei Ti | 黑体 | Bold, modern |
| Kai Ti | 楷体 | Calligraphic |
| Fang Song | 仿宋 | Official document |
| Song Ti | 宋体 | Classic serif |

## Architecture

```
lib/
├── constants/         Page config (A4/Letter sizes, defaults)
├── models/            FormatConfig (font, alignment, margins)
├── services/
│   ├── font_service.dart          Multi-font loader
│   ├── pdf_generator_service.dart PDF generation engine
│   ├── http_server.dart           HTTP + WebSocket server
│   ├── lan_drop_ui_protocol.dart  TCP file transfer
│   ├── landrop_service.dart       LAN transfer orchestrator
│   └── print_service.dart         Windows printing
├── providers/
│   └── editor_provider.dart       Central state management
└── widgets/
    ├── text_editor_panel.dart      Text input
    ├── pdf_preview_panel.dart      PDF display
    ├── format_toolbar.dart         Font size, alignment, etc.
    └── landrop_panel.dart          LAN transfer UI
```

## Build

### Prerequisites
- Flutter SDK (stable channel)
- Visual Studio 2022 with "Desktop development with C++" workload

### Release Build

```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/ConvertPrinter.exe
```

### Configure Firewall

On first run, Windows may block network access. Run as administrator once:

```powershell
.\launch_admin.ps1
```

### Font Setup (required before first build)

```powershell
.\setup_fonts.ps1
```

This copies SimHei, SimKai, SimFang, and SimSong fonts from `C:\Windows\Fonts\` to the project.

## License

MIT
