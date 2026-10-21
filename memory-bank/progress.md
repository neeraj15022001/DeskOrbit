# Progress & Milestones: DeskOrbit

## Overall Status: Production-Ready (v1.4.0)

DeskOrbit is fully implemented, verified on physical hardware, packaged as a universal macOS application, and deployed with a responsive documentation website and interactive simulator.

---

## Subsystem Completion Status

| Subsystem | Components | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Smart Lighting** | `WizLightService.swift`, `WizLightCardView.swift` | **Complete** | WiZ v2 HMAC-SHA256 signed UDP on port 38899, dynamic `ts` sync, auto-import homeStructure JSON. SmartThings 100% removed. |
| **Display Controls** | `DisplayService.swift`, `DisplayCardView.swift` | **Complete** | Apple Silicon DDC/CI (I²C 0x37), DisplayServices native, CoreGraphics Gamma LUT fallback, `.screenSaver` overlay. |
| **Power & Battery** | `BatteryPowerService.swift`, `BatteryPowerCardView.swift` | **Complete** | IOKit `AppleSmartBattery`, real-time input wattage (`IPDInputPower`), USB-PD profiles, health % vs design capacity. |
| **Audio Subsystem** | `AudioService.swift`, `AudioCardView.swift` | **Complete** | CoreAudio HAL `VirtualMainVolume`, mute toggling, output route switching, hardware listener block. |
| **Bluetooth & Storage** | `DeviceManager.swift`, `DeviceCardView.swift` | **Complete** | Peripheral battery levels via IOKit, disk volume gauges and safe unmounting via `DiskArbitration`. |
| **UI & Shell** | `AppDelegate.swift`, `MenuBarView.swift`, `DashboardView.swift`, `LiquidGlass.swift`, `ControlSliders.swift` | **Complete** | Liquid Glass materials, Control Center capsule sliders, Apple HIG &ge;10pt typography floor, 590px popover, auto-presented Dashboard, Dock reopen. |
| **CI/CD & Packaging** | `bundle_app.sh`, `create_dmg.sh`, `.github/workflows/` | **Complete** | Universal binary (`arm64` + `x86_64`), compressed `.dmg` generation, GitHub Actions CI & Pages. |

---

## Release History

### [v1.4.0] — 2026-10-21 (Commits `d6409cf`, `780b7bb`, `0c4241d`)
- **macOS Golden Gate 27 Liquid Glass (Commit `0c4241d`):** Added Liquid Glass material modifier (`LiquidGlass.swift`) with dynamic blur backdrops on floating headers, transient interaction specular sheens on scrubbers, accessibility fallbacks, and `.fullSizeContentView` window integration.
- **Apple HIG Interface Redesign (Commit `780b7bb`):** Redesigned entire UI adhering to Apple Human Interface Guidelines, built tactile Control Center capsule sliders (`OrbitCapsuleSlider` & `OrbitKelvinSlider`), and strictly standardized typography floor &ge;10pt.
- **WiZ v2 Cryptographic UDP Engine:** Implemented HMAC-SHA256 signing over sorted JSON keys, dynamic monotonic timestamp (`ts`) synchronization, and Darwin BSD `sockaddr_in.sin_len` socket initialization.
- **Home Structure Auto-Importer:** Scans `~/Downloads` for downloaded WiZ configuration JSONs to automatically configure `home_id`, `udp_signing_key`, and bulb mappings.
- **Purged SmartThings Cloud Integration:** Removed all cloud REST endpoints, personal access tokens, and rate limit freezes in favor of 100% local UDP.
- **Dashboard Auto-Presentation:** DeskOrbit automatically opens and focuses the full Dashboard on launch, with Dock reopen support.

### [v1.3.0] — 2026-10-21 (Commit `97d9b41`)
- **Direct WiZ LAN Subsystem:** Added local UDP port 38899 communication with subnet broadcast auto-discovery via Darwin `getifaddrs`.
- **Dynamic WiZ Scenes:** Added built-in scene support (Fireplace, Sunset, Party) and static presets.
- **Manual Bulb IP Pairing:** Modal dialog for adding bulbs on segmented or mesh networks.

### [v1.2.0] — 2026-10-13 (Commit `2df2b25`, `37d20f6`)
- **Initial Smart Lighting Subsystem:** First integration with Philips WiZ A60 bulbs via cloud REST API.
- **macOS Native ColorPicker:** Interactive system color wheel and live HEX preview debounced at 200ms.

### [v1.1.0] — 2026-09-15 (Commit `4b71e89`)
- **Battery & Power Subsystem:** Real-time charging input wattage, USB-PD contracts, cycle count, and maximum health percentage.
- **Dual-Column Menu Bar Popover:** Expanded popover width to 590px with dedicated hardware and power columns.

### [v1.0.0] — 2026-09-14 (Commit `26f7d99`)
- **Inaugural Public Release:** Unified Apple Silicon DDC/CI display dimming, CoreAudio HAL volume control, Bluetooth battery tracking, and safe disk ejection.
