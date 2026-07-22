# Convert Printer

A Flutter desktop application for LAN file transfer and PDF generation.

## Features

- Text editing with real-time PDF preview
- Multi-font support (Hei Ti, Kai Ti, Fang Song, Song Ti)
- LAN file transfer via HTTP + QR code
- Phone-to-PC text and file upload
- PC-to-phone file push with WebSocket notifications
- Adjustable font size, alignment, line spacing, margins
- Windows native print support
- A4 / Letter paper size switching

## Prerequisites

- Flutter SDK (master channel)
- Visual Studio 2022 with "Desktop development with C++"
- Windows Developer Mode enabled

## Setup

### 1. Install Chinese fonts

```powershell
.\setup_fonts.ps1
```

This copies system Chinese fonts (SimHei, SimKai, SimFang, SimSong) to `assets/fonts/`.

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run

```bash
flutter run -d windows
```

Or build release:

```bash
flutter build windows --release
```

## Architecture

```
lib/
├── constants/     Page config, theme
├── models/        Format config, page data
├── services/      PDF generation, HTTP server, LAN transfer, printing
├── providers/     Editor state management
└── widgets/       Editor panel, PDF preview, toolbar, LAN panel
```

## License

MIT
