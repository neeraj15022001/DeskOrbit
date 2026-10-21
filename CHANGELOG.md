# Changelog

All notable changes to **DeskOrbit** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.4.0] - 2026-10-21

**Release Date & Time:** 2026-10-21 22:45:00 IST (+05:30)  
**Target OS:** macOS 14.0+ (Sonoma, Sequoia)  
**Architectures:** Universal (Apple Silicon & Intel)

### Added
- **WiZ v2 Cryptographic HMAC-SHA256 Signed UDP Engine (`WizLightService.swift`):**
  - **WiZ v2 Local Protocol Support:** Full implementation of WiZ v2 signed UDP pilot commands on port `38899`, required by modern WiZ bulb firmware (`v1.38.0+`) which rejects legacy unauthenticated `setPilot` packets.
  - **HMAC-SHA256 Envelope Generation:** Real-time generation of SHA-256 message authentication codes over alphabetically sorted JSON payload parameters (`key:value`), keyed with the 16-byte home UDP signing key (`udp_signing_key`).
  - **Dynamic Timestamp Synchronization:** Autonomous tracking of the bulb's monotonically increasing 32-bit counter (`ts` / timestamp) from status response packets, auto-incrementing timestamps for each pilot transmission to defeat replay attack checks.
  - **Home Structure Auto-Importer (`homeStructure` JSON):** Single-click or auto-detection import of WiZ v2 home configuration JSON exports (generated via WiZ app Third-Party Integrations link), extracting `home_id`, `udp_signing_key`, room mappings, and paired bulb identifiers without manual key entry.
  - **Download Folder Auto-Discovery:** Automatic scanning of `~/Downloads` for downloaded WiZ configuration payloads, sorted by newest modification date for zero-touch configuration.
- **macOS BSD Socket Alignment (`WizLightService.swift`):**
  - **Darwin `sockaddr_in` Alignment:** Corrected macOS Darwin BSD socket structure initialization (`sin_len = UInt8(MemoryLayout<sockaddr_in>.size)`). Resolved silent UDP transmission dropouts when dispatching unicast and broadcast UDP packets via POSIX `sendto()`.
- **Application Lifecycle & Dashboard Window Presentation (`AppDelegate.swift`):**
  - **Automatic Dashboard Launch:** DeskOrbit now automatically opens and focuses the full Home-style Dashboard window on launch, providing instant visibility into all connected hardware and smart lights.
  - **Dock / App Reopen Handler:** Implemented `applicationShouldHandleReopen:hasVisibleWindows:` ensuring clicking the app icon in Dock or Spotlight restores the active Dashboard window.
- **Diagnostic Logging Subsystem:**
  - Added centralized persistent diagnostics logging to `/tmp/deskorbit.log` for troubleshooting socket binds, packet round-trips, and HMAC validations in real-time.

### Removed
- **Samsung SmartThings Cloud Integration:**
  - Completely purged all Samsung SmartThings Personal Access Token (PAT) storage, cloud REST API networking (`api.smartthings.com/v1`), token verification alerts, and rate-limiting debouncers.
  - Removed cloud latency bottlenecks, cloud dependency, and credential expiration risks, making DeskOrbit 100% local, private, and zero-cloud.

### Changed
- **Comprehensive Apple Human Interface Guidelines (HIG) UI Redesign:**
  - **Liquid Glass & macOS Golden Gate 27 Visual Principles (`LiquidGlass.swift`):** Applied Apple's dynamic Liquid Glass material to the Dashboard toolbar and WiZ Hub header (`.liquidGlass(.regular)`), enabling underlying cards to diffuse and peek through during scrolling. Capsule sliders take on a dynamic Liquid Glass specular sheen and edge reflection when actively scrubbed or hovered. Configured `NSWindow` with `.fullSizeContentView` and transparent title bar, and added automatic fallbacks for Reduce Transparency and Increase Contrast.
  - **Tactile Capsule Sliders (`OrbitCapsuleSlider` & `OrbitKelvinSlider`):** Replaced default thin sliders with full-height Apple Control Center style capsule sliders featuring dynamic leading iconography, continuous drag scrubbing, high-contrast text adaptation, and a 2200K–6500K Kelvin spectrum track.
  - **Typography & Hit Target Accessibility Floor:** Standardized typography across all components to strictly obey Apple HIG guidelines (`>= 10pt` minimum text, eliminating 8pt/9pt micro-type), with 28x28pt minimum hit targets for buttons and icons.
  - **Calm, Unified Semantic Visual System:** Replaced clashing colored badges with calm Apple Home-style elevated surfaces (`NSColor.controlBackgroundColor`), continuous 14pt corner radii (`.continuous`), and subtle hover elevation.
  - **Menu Bar Status Item Polish:** Replaced `macmini` icon with Apple's standard hardware device controller symbol `slider.horizontal.3` and added 24x24pt hit frames with active hardware counter.
- **Menu Bar Header Polish (`MenuBarView.swift`):**
  - Replaced ambiguous header power toggle button with an explicit, high-contrast **Dashboard Window** button and dedicated **Quit DeskOrbit** action.
  - Cleaned up light card telemetry pills to display exact local Wi-Fi IP and direct hardware MAC address.

---

## [1.3.0] - 2026-10-21

**Release Date & Time:** 2026-10-21 21:30:00 IST (+05:30)  
**Target OS:** macOS 14.0+ (Sonoma, Sequoia)  
**Architectures:** Universal (Apple Silicon & Intel)

### Added
- **Direct WiZ Third-Party Local LAN Integration (`WizLightService.swift`):**
  - **Local UDP Protocol (Port 38899):** Direct, zero-latency (<10ms) communication with WiZ smart bulbs over local Wi-Fi without requiring cloud round-trips or internet access.
  - **Auto-Discovery via Subnet Broadcast:** Dynamically queries Darwin network interfaces (`getifaddrs`) to determine active IPv4 subnet broadcast addresses, discovering responding WiZ bulbs and registering push controller subscriptions.
  - **Add Bulb by Local IP:** Dedicated modal sheet allowing manual IP addition (e.g. `192.168.1.x`) and custom naming for complex mesh or dual-band networks.
  - **Native WiZ Dynamic Scenes:** Full local support for built-in WiZ scenes (Fireplace, Sunset, Party) alongside static presets (Warm White, Daylight, Cozy, Night Light).
- **Hybrid Dual-Route Architecture (Local LAN + SmartThings Cloud):**
  - **Intelligent Pairing & Deduplication:** When a WiZ bulb is connected via the WiZ app's Samsung SmartThings integration and also present on the local Wi-Fi, DeskOrbit unifies them into a **Hybrid (LAN + Cloud)** device.
  - **Instant Local Execution with Cloud Sync:** Commands (power, brightness, RGB color, color temperature, scenes) fire immediately over UDP for flicker-free local response, and automatically update Samsung SmartThings Cloud in the background.
  - **Link Local IP Tool:** Single-click popover on SmartThings cloud bulbs enabling users to attach a local LAN IP for instant local control upgrade.
- **Third-Party Integration Setup Guide Sheet (`DashboardView.swift`):**
  - Interactive modal guide detailing setup for both WiZ app Third-Party Integrations:
    1. *Samsung SmartThings Cloud Integration* via WiZ app pairing code.
    2. *Local Network Communication* via WiZ app Security & Privacy settings.
    3. *Hybrid Operation* benefits and verification tips.
- **Connection Badges & Diagnostics:**
  - Real-time connection badges (`Direct Wi-Fi (LAN)`, `SmartThings Cloud`, `Hybrid (LAN + Cloud)`) with detailed telemetry popovers (IP, MAC, firmware version, module model).

---

## [1.2.0] - 2026-10-13

**Release Date & Time:** 2026-10-13 12:15:00 IST (+05:30)  
**Target OS:** macOS 14.0+ (Sonoma, Sequoia)  
**Architectures:** Universal (Apple Silicon & Intel)

### Added
- **Smart Lighting Subsystem — Samsung SmartThings Integration (`WizLightService.swift`):**
  - **Direct SmartThings Cloud REST Integration:** Dedicated cloud REST API communication (`api.smartthings.com/v1`) controlling Philips WiZ A60 smart bulbs via Samsung SmartThings with zero local UDP socket blocking.
  - **Power & Dimming Control:** Remote ON/OFF toggling and `switchLevel` dimming (10% to 100%).
  - **16M RGB Color Tuning:** Full-spectrum RGB color selection with rapid preset swatches, translating RGB to normalized HSV (Hue `0-100`, Saturation `0-100`) via SmartThings `colorControl` capability.
  - **Native macOS RGB Color Picker:** Interactive system `ColorPicker` with HEX indicator badge placed alongside the preset swatches, granting access to macOS color wheels, spectrum sliders, and eyedropper tools.
  - **Tunable White Temperature (Kelvin):** Continuous Kelvin temperature adjustment from 2200K (Warm Candlelight) to 6500K (Cool Daylight) via SmartThings `colorTemperature` capability.
  - **Quick Scene Presets:** Instant scene presets (Warm White, Daylight, Cozy, Night Light).
  - **Automatic Status Synchronization:** Background status polling (`GET /v1/devices/{deviceId}/status`) keeping power, brightness, color, and temperature in sync without false offline indicators.

### Fixed
- **API Request Debouncing & Queue Freezes:** Implemented 250ms debouncing on continuous sliders (brightness & color temperature) and atomic command batching to prevent SmartThings API rate limiting and queue stalls after multiple rapid actions.
- **Removed Local Wi-Fi Detection & Purged Duplicates:** Purged all unreachable local Wi-Fi UDP instances, transitioning light management exclusively to the reliable SmartThings Cloud integration.

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
