# Convert Printer

A Flutter Windows desktop application for text editing, PDF generation, and LAN file transfer between PC and mobile devices.

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
