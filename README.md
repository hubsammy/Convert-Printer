# Convert Printer

A Flutter-based Windows desktop application for text editing, real-time PDF generation, mobile OCR scanning, and two-way file transfer over a local network.

## Overview

Convert Printer is a cross-device productivity tool. Edit text on your PC and preview the PDF layout in real time. The editor supports four Chinese fonts, font size, alignment, line spacing, paragraph spacing, and page margin controls. Completed documents can be sent directly to a Windows printer.

The built-in LAN transfer module uses HTTP and WebSocket connections. A phone can connect by scanning a QR code, take a photo for OCR with Tesseract.js, and automatically send the recognized text to the PC editor. From the PC, you can push text, PDFs, or other files to the phone with one click. Editor content and formatting settings are saved locally and restored after restart.

**Highlights:**
- Real-time PDF layout engine with automatic wrapping, pagination, headers, and footers
- Four Chinese fonts: Hei, Kai, FangSong, and Song
- Complete workflow: mobile OCR → PC editing → PDF printing
- Two-way LAN transfer with QR-code pairing and WebSocket notifications
- Native Windows `.exe` application
- Local data storage with no cloud service dependency

**Tech stack:** Flutter/Dart · PDF engine · HTTP server · WebSocket · Tesseract.js OCR

**Use cases:** Quick document formatting and printing · OCR for meeting notes · Cross-device file exchange · Organizing class notes

## Getting Started

```bash
# Install dependencies
flutter pub get

# Install Chinese fonts
.\setup_fonts.ps1

# Run the application
flutter run -d windows
```

## Building

```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/ConvertPrinter.exe
```

## License

MIT
