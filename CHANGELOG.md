# Changelog

All notable changes to **DeskOrbit** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.0] - 2026-09-15

**Release Date & Time:** 2026-09-15 13:43:00 IST (+05:30)  
**Target OS:** macOS 14.0+ (Sonoma, Sequoia)  
**Architectures:** Universal (Apple Silicon & Intel)

### Added
- **Battery & Power Subsystem (`BatteryPowerService.swift`):**
  - **Live Battery Percentage & Status:** Continuous tracking of battery level (`0-100%`), charging status, and power state via IOKit `AppleSmartBattery`.
  - **Real-Time Charging Input Power:** Real-time calculation of charger input wattage (`IPDInputPower`), input voltage (`IPDInputVoltage`), and input current (`IPDInputCurrent`) from connected USB-C / MagSafe power supplies.
  - **Power Adapter Telemetry:** Complete hardware profiling including adapter name, manufacturer (`Apple Inc.`), rated wattage, serial string, firmware version, hardware revision, and supported USB Power Delivery (USB-PD) profiles.
  - **Battery Health & Capacity Analysis:** Accurate maximum capacity calculation comparing nominal/full charge capacity against original factory design capacity (`DesignCapacity` in mAh), health condition (`Normal` / `Service Recommended`), and cycle count wear.
  - **Physical Battery Sensors:** Real-time battery voltage, instantaneous charge/discharge current flow (mA), battery power flow (Watts), temperature in °C, controller model (`bq40z651`), and battery serial number.
  - **Dual-Tier User Interface:**
    - *Basic View (Menu Bar Popover & Dashboard):* High-level glanceable battery level, connection state, charging input wattage, cycle count, and health percentage.
    - *Advanced Telemetry View (Expandable):* Comprehensive diagnostic telemetry showing power distribution, USB-PD contract tiers, and physical battery specifications.
  - **Dashboard Category Integration:** Added dedicated `Power & Battery` category filter in `DashboardView` with live device counts and status indicators.

### Changed
- **Side-by-Side Dual-Column Menu Bar Popover (`MenuBarView.swift`, `AppDelegate.swift`):**
  - Expanded popover width from 320px to 590px for an un-cluttered, widescreen experience.
  - Divided the interface into two dedicated columns: Hardware device controllers (Displays, Audio, Bluetooth, Storage) on the left side (310px) and Battery & Power telemetry on the right side (280px).
  - Fixed cramped vertical text wrapping and label clipping on battery percentages, charging indicators, and metric chips (`BatteryPowerCardView.swift`).

---

## [1.0.0] - 2026-09-14

**Release Date & Time:** 2026-09-14 17:15:00 IST (+05:30)  
**Commit:** `26f7d99`  
**Target OS:** macOS 14.0+ (Sonoma, Sequoia)  
**Architectures:** Universal (Apple Silicon M1/M2/M3/M4 & Intel x86_64)

### Added
- **Display Subsystem (`DisplayService.swift`):**
  - Apple Silicon DDC/CI hardware control via private `IOAVService` API over I²C (`0x37`) using VCP opcode `0x10`.
  - Native Apple display backlight control via `DisplayServices` framework for internal Mac displays and Studio Display.
  - Software GPU Gamma lookup table manipulation via CoreGraphics (`CGSetDisplayTransferByTable` and `CGSetDisplayTransferByFormula`) for external screens without DDC/CI support.
  - Transparent `.screenSaver` window level software dimming overlay fallback with click-through event pass-through.
- **Audio Subsystem (`AudioService.swift`):**
  - Zero-latency hardware volume scalar control using CoreAudio HAL properties (`kAudioHardwareServiceDeviceProperty_VirtualMainVolume`).
  - System-wide hardware mute toggling with instant icon feedback.
  - Default audio device routing switcher allowing single-click switching between internal speakers, USB DACs, and wireless headphones.
  - Real-time listener (`AudioObjectAddPropertyListenerBlock`) for device hot-plugging, system volume changes, and default device updates.
- **Bluetooth Subsystem (`BluetoothService.swift`):**
  - Peripheral enumeration and connection monitoring powered by `IOBluetooth`.
  - Battery percentage extraction using IOKit power source APIs (`IOPSCopyPowerSourcesInfo`) for supported accessories (AirPods, Magic Mouse, Magic Keyboard, Bluetooth headsets).
  - One-click peripheral connect and disconnect actions.
- **Storage Subsystem (`StorageService.swift`):**
  - External drive, USB stick, and SD card detection using `NSWorkspace` and `DiskArbitration`.
  - Real-time storage utilization calculation (total, used, and free capacity percentage progress bars).
  - Safe volume unmounting and disk ejection via `NSWorkspace.shared.unmountAndEjectDevice`.
- **Application Lifecycle & UI:**
  - Dual-mode architecture: Runs as an unobtrusive accessory (`LSUIElement = true`) in the menu bar with an `NSPopover`.
  - Dynamic AppKit activation policy switching to `.regular` mode when opening the standalone Home-style dashboard window.
  - Custom fluid SwiftUI control sliders and dark glassmorphic cards.
  - Bespoke 1024×1024 macOS app icon (`AppIcon_1024.png`) featuring an orbital dial motif.
- **Packaging & Developer Tooling:**
  - `bundle_app.sh`: Automated release compilation and `.app` bundle generator.
  - `create_dmg.sh`: Standalone script packaging `DeskOrbit.app` and `/Applications` symlink into a compressed drag-and-drop `.dmg`.
  - `.github/workflows/ci.yml`: Automated macOS build pipeline on GitHub Actions.
  - `.github/workflows/release.yml`: Tag-triggered release packaging and asset publishing.
  - `.github/workflows/pages.yml`: Automated GitHub Pages deployment pipeline.
- **Open Source Community & Governance:**
  - MIT License (`LICENSE`).
  - Contribution Guidelines (`CONTRIBUTING.md`) with hardware testing verification checklists.
  - Contributor Covenant v2.1 (`CODE_OF_CONDUCT.md`).
  - Security vulnerability reporting policy (`SECURITY.md`).
  - Issue & PR templates (`.github/ISSUE_TEMPLATE/bug_report.md`, `feature_request.md`, `PULL_REQUEST_TEMPLATE.md`).
  - AI Co-Creation & Provenance transparency documentation (co-engineered with Google DeepMind / Gemini Spark).
- **Web Presence:**
  - Responsive landing page (`docs/index.html`) featuring an interactive menu bar simulator and live monitor luminance preview.
