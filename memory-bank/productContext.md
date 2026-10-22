# Product Context: DeskOrbit

## Why DeskOrbit Exists
Modern desk setups connect Mac users to multiple external peripherals: high-resolution external monitors, studio monitors/DACs, wireless headphones, external backup SSDs, USB-C/MagSafe chargers, and desk smart lighting. 

Historically, controlling these devices on macOS required a fragmented collection of separate apps:
- Third-party monitor dimmers (often paid or subscription-based).
- Dedicated audio routing utilities.
- Proprietary smart-home mobile apps requiring cloud accounts, logins, and internet round-trips.
- System Settings menus buried deep within macOS for power profiles and battery health.

DeskOrbit unifies this entire hardware orbit into one cohesive, lightweight, privacy-respecting macOS experience.

## User Personas & Workflows
1. **The Modern Desk Worker / Creator:**
   - Works with external third-party monitors (LG, Dell, BenQ, ASUS) and needs fast, hardware-level DDC/CI brightness dimming without reaching for physical monitor buttons.
   - Adjusts desk ambient lighting throughout the day (cool daylight for morning focus, warm white or dynamic fireplace scene for evening work).
   - Switches audio seamlessly between studio monitors and AirPods during meetings.
2. **The Power User & Hardware Enthusiast:**
   - Inspects real-time charging wattage delivered by multi-port GaN chargers or Thunderbolt docks to verify negotiated USB-PD contracts.
   - Monitors physical battery wear, true health percentage against factory design capacity, cycle count, and internal temperature.
   - Demands 100% offline control with zero vendor lock-in, zero cloud accounts, and zero background analytics.

## User Experience & Interface Architecture
DeskOrbit employs a dual-tier interface pattern tailored for both quick micro-actions and deep hardware inspection:

### 1. Dual-Column Menu Bar Popover (`MenuBarView.swift`)
- Accessible with a single click or keyboard shortcut from the macOS menu bar status item.
- Engineered with a 590px side-by-side layout:
  - **Left Column (310px):** Hardware Device Controllers — External display luminance sliders, audio output picker and volume scalar, WiZ smart bulb toggle with quick brightness/color controls, Bluetooth peripheral battery bars, and external disk ejectors.
  - **Right Column (280px):** Live Power & Battery Telemetry — Instant glanceable battery level, charging state, real-time input wattage, cycle count, and expandable diagnostic telemetry.
- Header contains an instant launcher for the full Dashboard Window and a clean Quit action.

### 2. Full Home-Style Dashboard (`DashboardView.swift`)
- Standalone macOS window styled after Apple Home with frosted glass vibrancy and fluid animations.
- Automatically launches on app start or when reopening via Dock/Spotlight.
- Categorized navigation sidebar:
  - **All Devices:** Comprehensive grid of all connected hardware.
  - **Displays:** Dedicated monitor controls (DDC/CI, Apple Native, Gamma LUT).
  - **Smart Lights:** WiZ v2 card featuring full RGB color wheel, Kelvin temperature slider, built-in scenes, bulb IP management, and homeStructure JSON configuration auto-importer.
  - **Power & Battery:** Full battery health metrics, USB-PD contracts, physical sensors.
  - **Audio:** Master volume and device routing.
  - **Storage & Bluetooth:** Mounted drive capacity gauges and peripheral battery indicators.

## Solving Smart Lighting Fragility: WiZ v2 Direct LAN
Previous iterations explored cloud REST APIs (such as Samsung SmartThings). While functional, cloud APIs suffered from:
- Reliance on personal access tokens and third-party cloud uptime.
- Latency (300ms–1500ms round trips) causing noticeable lag when adjusting sliders.
- Strict API rate limits resulting in dropped packets during continuous slider adjustments.

DeskOrbit v1.4.0 completely severed the cloud umbilical cord by reverse-engineering WiZ v2's modern firmware requirements:
- WiZ bulbs running firmware `1.38.0+` enforce **HMAC-SHA256 signature verification** on incoming UDP pilot datagrams.
- DeskOrbit automatically imports the home's 16-byte UDP signing key from WiZ v2 configuration JSON exports and dynamically signs every datagram with the bulb's synchronized monotonic timestamp (`ts`).
- Result: **Zero cloud dependency, sub-10ms instantaneous response, 100% local operation even when the internet is offline.**

## Siri AI & Local Intelligence: On-Device Foundation Models
In v1.5.0, DeskOrbit introduced zero-cloud voice and natural language control:
- **No HomeKit Hardware Bridge Required:** Users who don't have Apple TV, HomePod, or HomeKit-certified accessories can now control their smart lights directly using Siri or the in-app voice assistant.
- **Apple Silicon Foundation Models:** Leverages Apple's on-device `SystemLanguageModel` (Apple Intelligence) running on the Neural Engine to parse natural language requests:
  - *Contextual & Thematic:* "Change color to theme of Money Heist" (crimson red), "Cyberpunk vibe" (electric neon), "Matrix green".
  - *Circadian Daylight Sync:* "Match light with daytime" calculates solar elevation based on current system time and transitions from morning warmth to midday daylight (6000K) and evening amber (2200K).
  - *Functional:* "Set light to 80% for reading", "turn off lights", "movie night".
- **Total Privacy:** Audio transcription (`SFSpeechRecognizer`) and LLM inference run entirely on-device with zero telemetry and zero external server round-trips.
