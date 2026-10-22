# Progress & Milestones: DeskOrbit

## Overall Status: Production-Ready (v1.5.0)

DeskOrbit is fully implemented, verified on physical hardware, packaged as a universal macOS application, and enhanced with on-device generative AI via Apple's native Foundation Models framework.

---

## Subsystem Completion Status

| Subsystem | Components | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Generative Voice Assistant** | `VoiceAssistantService.swift`, `OrbitNaturalLanguageParser.swift`, `VoiceAssistantBarView.swift` | **Complete** | Powered by Apple `SystemLanguageModel` (`FoundationModels.framework`), on-device `SFSpeechRecognizer`, solar circadian calculation, and thematic presets. |
| **Siri & App Intents** | `DeskOrbitAppIntents.swift`, `Metadata.appintents` | **Complete** | 6 custom App Intents, `AppShortcutsProvider`, metadata extraction via `appintentsmetadataprocessor`. |
| **Smart Lighting** | `WizLightService.swift`, `WizLightCardView.swift` | **Complete** | WiZ v2 HMAC-SHA256 signed UDP on port 38899, dynamic `ts` sync, cross-band ARP auto-recovery, automatic Colors/Whites UI mode switching. |
| **Display Controls** | `DisplayService.swift`, `DisplayCardView.swift` | **Complete** | Apple Silicon DDC/CI (I²C 0x37), DisplayServices native, CoreGraphics Gamma LUT fallback, `.screenSaver` overlay. |
| **Power & Battery** | `BatteryPowerService.swift`, `BatteryPowerCardView.swift` | **Complete** | IOKit `AppleSmartBattery`, real-time input wattage (`IPDInputPower`), USB-PD profiles, health % vs design capacity. |
| **Audio Subsystem** | `AudioService.swift`, `AudioCardView.swift` | **Complete** | CoreAudio HAL `VirtualMainVolume`, mute toggling, output route switching, hardware listener block. |
| **Bluetooth & Storage** | `DeviceManager.swift`, `DeviceCardView.swift` | **Complete** | Peripheral battery levels via IOKit, disk volume gauges and safe unmounting via `DiskArbitration`. |
| **UI & Shell** | `AppDelegate.swift`, `MenuBarView.swift`, `DashboardView.swift`, `LiquidGlass.swift`, `ControlSliders.swift` | **Complete** | Liquid Glass materials, Control Center capsule sliders, Apple HIG &ge;10pt typography floor, 590px popover, auto-presented Dashboard, Dock reopen. |
| **CI/CD & Packaging** | `bundle_app.sh`, `create_dmg.sh`, `.github/workflows/` | **Complete** | Embedded `__info_plist`, auto-kill zombie cleanup, App Intents extraction, universal binary, compressed `.dmg`. |

---

## Release History

### [v1.5.0] — 2026-10-23
- **Apple Foundation Models Integration (`FoundationModels.framework`):** Integrated Apple's on-device `SystemLanguageModel` running locally on Apple Silicon Neural Engine to parse arbitrary creative lighting prompts, moods, and contextual commands.
- **On-Device Voice Assistant:** Integrated Speech framework (`SFSpeechRecognizer`) with Liquid Glass floating waveform bar, enabling natural voice commands for smart bulb colors, scenes, dimming, display brightness, and system audio.
- **Thematic & Circadian Intelligence:**
  - Dynamic solar circadian lighting matching sunrise, morning, midday peak, sunset, and nighttime.
  - Thematic presets for pop-culture references (Money Heist, Blade Runner Cyberpunk, Matrix, Stranger Things, Star Wars, Interstellar).
- **Cross-Band ARP & Routing Self-Healing:** Added synchronous ping re-priming on socket `errno=64/65`, eliminating intermittent UDP packet loss between 5GHz Macs and 2.4GHz smart devices.
- **Embedded `__info_plist` & TCC Signatures:** Linked `__info_plist` into Mach-O binary and added automated bundle detritus cleanup + ad-hoc codesigning to eliminate privacy permission crashes.
- **Siri AI App Intents:** Generated and bundled `Metadata.appintents` using `appintentsmetadataprocessor` for macOS Shortcuts and Siri integration.
- **UI State Synchronization Fix:** Fixed mode switching (`activeLightModes`) and direct `@Published` updates in `DeviceManager` so light cards instantly reflect voice-commanded colors and temperatures.
- **Audio Device Targeting & Intent Isolation:** Added `extractAudioTarget` and `extractPercentageOrWordNumber` to resolve commands for specific hardware devices (MacBook Air Speakers, JBL, AirPods, HDMI/SA272). Partitioned Foundation Model prompt across audio, display, and light to eliminate cross-device bleed.
- **Explicit Power & Mute State Enforcement:** Added `setLightPower` to ensure verbal commands apply absolute boolean states rather than inverting via `toggleLightPower`.
- **App Bundle Finder Icon (`AppIcon.icns`):** Added multi-resolution `AppIcon.icns` packaging into `Contents/Resources/AppIcon.icns` to ensure Finder displays the application icon on distributed DMGs.

### [v1.4.0] — 2026-10-21
- **macOS Golden Gate 27 Liquid Glass:** Added Liquid Glass material modifier with dynamic blur backdrops, specular sheens on scrubbers, accessibility fallbacks, and `.fullSizeContentView` window integration.
- **Apple HIG Interface Redesign:** Tactile Control Center capsule sliders (`OrbitCapsuleSlider` & `OrbitKelvinSlider`), strictly standardized typography floor &ge;10pt.
- **WiZ v2 Cryptographic UDP Engine:** Implemented HMAC-SHA256 signing over sorted JSON keys, dynamic monotonic timestamp (`ts`) synchronization, and Darwin BSD `sockaddr_in.sin_len` socket initialization.
- **Home Structure Auto-Importer:** Scans for downloaded WiZ configuration JSONs to automatically configure credentials and bulb mappings.
- **Purged SmartThings Cloud Integration:** Removed all cloud REST endpoints, personal access tokens, and rate limit freezes in favor of 100% local UDP.

### [v1.3.0] — 2026-10-21
- **Direct WiZ LAN Subsystem:** Added local UDP port 38899 communication with subnet broadcast auto-discovery via Darwin `getifaddrs`.

### [v1.2.0] — 2026-10-13
- **Initial Smart Lighting Subsystem:** First integration with Philips WiZ bulbs.

### [v1.1.0] — 2026-09-15
- **Battery & Power Subsystem:** Real-time charging input wattage, USB-PD contracts, cycle count, and maximum health percentage.

### [v1.0.0] — 2026-09-14
- **Inaugural Public Release:** Unified Apple Silicon DDC/CI display dimming, CoreAudio HAL volume control, Bluetooth battery tracking, and safe disk ejection.
