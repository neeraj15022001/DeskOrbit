# Contributing to DeskOrbit

Thank you for your interest in contributing to **DeskOrbit**! As an open-source macOS utility, DeskOrbit aims to provide a unified, responsive, and seamless control experience for all connected peripherals and displays.

---

## Code of Conduct

All contributors and maintainers are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md). Please be respectful and constructive in all discussions, issues, and pull requests.

---

## Development Environment & Requirements

- **Operating System:** macOS 14.0 (Sonoma) or newer (Apple Silicon & Intel).
- **Toolchain:** Xcode 15+ or Swift 5.9 / Swift 6 Command Line Tools (`swift --version`).
- **Frameworks Used:** AppKit, SwiftUI, CoreAudio, AudioToolbox, IOKit, IOBluetooth, DiskArbitration, CoreGraphics.

---

## Getting Started

1. **Fork & Clone:**
   ```bash
   git clone https://github.com/<your-username>/DeskOrbit.git
   cd DeskOrbit
   ```

2. **Build and Run:**
   - From Terminal:
     ```bash
     swift build
     swift run
     ```
   - Package into a `.app` bundle:
     ```bash
     ./bundle_app.sh
     open DeskOrbit.app
     ```
   - In Xcode:
     ```bash
     open Package.swift
     ```

---

## Architecture Overview

```
Sources/DevicesControl/
├── main.swift              # App entry point
├── App/
│   └── AppDelegate.swift   # NSStatusItem, NSPopover, and NSWindow lifecycle
├── Models/
│   └── DeviceModels.swift  # Unified data contracts for Displays, Audio, Bluetooth, Storage
├── Services/
│   ├── AudioService.swift    # CoreAudio device enumeration, volume/mute, default routing
│   ├── DisplayService.swift  # IOAVService DDC/CI, GPU Gamma tables, DisplayServices
│   ├── BluetoothService.swift# IOBluetooth peripheral monitoring and battery level query
│   ├── StorageService.swift  # DiskArbitration & NSWorkspace mounted drive manager
│   └── DeviceManager.swift   # Central @ObservableObject coordinator
└── Views/
    ├── MenuBarView.swift     # Popover quick controls
    ├── DashboardView.swift   # Full macOS window dashboard
    └── Components/           # Modular tile cards and sliders
```

---

## AI Co-Creation & Transparency Guidelines

DeskOrbit was initially architected and developed with AI-assisted software engineering (pairing with Gemini Spark / Google DeepMind). We embrace transparent AI-assisted contributions under the following principles:

1. **Hardware Verification:** Any PR touching low-level hardware drivers (`CoreAudio`, `IOAVService`, `IOKit`, `CGSetDisplayTransferByTable`) must be verified on physical Mac hardware to ensure no display panics, audio loops, or memory leaks occur.
2. **Clean Commits & Documentation:** Explain *why* an approach was chosen. If an external reference (such as MonitorControl, Lunar, or SimplyCoreAudio) inspired the solution, link to the upstream context.
3. **No Opaque Code:** All code submitted should be well-typed, idiomatic Swift with clear separation of concerns.

---

## Submitting Pull Requests

1. Create a feature branch (`git checkout -b feature/amazing-feature`).
2. Make your changes and ensure `swift build` compiles without warnings or errors.
3. Commit with concise, descriptive commit messages.
4. Push to your branch and open a Pull Request against `main`.
5. Describe the hardware tested (e.g., *M2 MacBook Air with LG 27UK850 over USB-C*).
