# Project Brief: DeskOrbit

## Executive Summary
DeskOrbit is an open-source, zero-telemetry macOS hardware controller and smart-home accessory. It consolidates external display management (Apple Silicon DDC/CI & GPU Gamma), WiZ smart bulb automation via authenticated local UDP, CoreAudio HAL routing, Bluetooth peripheral battery monitoring, battery health & charger telemetry, and external storage disk management into a single lightweight menu bar utility and native macOS Home-style dashboard.

## Core Principles & Non-Negotiables
1. **100% Zero-Cloud & Local First:**
   - No external cloud services, API tokens, user accounts, or internet connectivity required.
   - All smart bulb controls communicate directly over the local Wi-Fi network via cryptographic UDP datagrams.
2. **Native Low-Level macOS Integration:**
   - Zero bulky third-party frameworks or bloated runtimes.
   - Direct integration with Apple private & public C/Objective-C frameworks: `IOAVService`, `DisplayServices`, `CoreAudio HAL`, `IOKit AppleSmartBattery`, `IOBluetooth`, `DiskArbitration`, and Darwin POSIX BSD sockets.
3. **Zero Telemetry & 100% Privacy:**
   - Absolute user privacy. No analytics, tracking, background beaconing, or diagnostics telemetry sent externally.
4. **Instant, Tactile Responsiveness:**
   - Sub-15ms local latency for hardware adjustments (display luminance, audio volume, smart bulb power/color).
   - Atomic debouncing on sliders to protect hardware buses from command flooding.
5. **Universal Apple Silicon & Intel Binary:**
   - Native compilation across Apple Silicon (M1/M2/M3/M4) and Intel x86_64 architectures running macOS 14.0+ (Sonoma and Sequoia).

## Subsystems & Scope
- **Display Subsystem (`DisplayService.swift`):** Apple Silicon DDC/CI hardware brightness via I²C bus `0x37` with VCP opcode `0x10`, Apple native display backlight control via `DisplayServices`, GPU Gamma LUT scaling via `CGSetDisplayTransferByTable`, and a floating transparent `.screenSaver` overlay fallback.
- **Smart Lighting Subsystem (`WizLightService.swift`):** WiZ v2 cryptographic HMAC-SHA256 authenticated UDP pilot controls on port `38899`, dynamic 32-bit counter (`ts`) tracking, Darwin subnet broadcast auto-discovery, home configuration JSON auto-importer, 16M RGB color picker, tunable Kelvin white (2200K–6500K), and dynamic WiZ scenes.
- **Battery & Power Subsystem (`BatteryPowerService.swift`):** Real-time charging input wattage, voltage, current (`IPDInputPower`), USB-PD contract tiers, charger hardware profiling, battery health vs. factory design capacity (`DesignCapacity` mAh), and physical sensors via `AppleSmartBattery`.
- **Audio Subsystem (`AudioService.swift`):** Zero-latency volume scalar control and mute toggling via CoreAudio HAL, default audio output device switching, and real-time hardware listener updates.
- **Peripherals Subsystem (`DeviceManager.swift`):** Bluetooth peripheral battery telemetry via IOKit and external disk storage usage with safe ejection via `DiskArbitration` and `NSWorkspace`.
- **Application Shell & UX (`AppDelegate.swift`, `MenuBarView.swift`, `DashboardView.swift`):** Dual-mode `LSUIElement` menu bar accessory with dynamic policy elevation to `.regular`, side-by-side 590px dual-column menu bar popover, and a full macOS Home-style dashboard window auto-presented on launch.
