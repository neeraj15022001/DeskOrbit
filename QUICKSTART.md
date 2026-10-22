# DeskOrbit Quick Start Guide

Welcome to **DeskOrbit** — the native, zero-cloud macOS utility that unifies your external displays, audio devices, battery telemetry, and local smart lighting into a single liquid-glass Control Center.

---

## 1. System Requirements

- **Operating System:** macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia).
- **Architecture:** Universal Binary — natively runs on **Apple Silicon (M1/M2/M3/M4)** and **Intel (x86_64)**.
- **Apple Intelligence / Local LLM:** Requires Apple Silicon running macOS Sequoia for on-device Foundation Model inference. On Intel Macs, deterministic circadian solar curves and regex rule engines run natively.
- **Dependencies:** **Zero.** No HomeKit bridge, no Node.js, no Docker, and zero third-party dynamic libraries.

---

## 2. Installation Options

### Option A: Install via Prebuilt `.dmg` (Recommended)
1. Download the latest release from the [GitHub Releases](https://github.com/neeraj15022001/DeskOrbit/releases/latest) page.
2. Double-click `DeskOrbit.dmg`.
3. Drag **DeskOrbit** into your `/Applications` folder.
4. Launch DeskOrbit from Spotlight (`Cmd + Space` &rarr; `DeskOrbit`) or `/Applications`.

### Option B: Build from Source
Ensure Xcode Command Line Tools are installed:
```bash
# Clone the repository
git clone https://github.com/neeraj15022001/DeskOrbit.git
cd DeskOrbit

# Build the release bundle with embedded entitlements and App Intents
./bundle_app.sh

# Launch the application
open /Applications/DeskOrbit.app
```

---

## 3. Permissions & First-Time Setup

When launching DeskOrbit for the first time, macOS may request standard system permissions:

| Permission | Purpose | Where to Enable |
| :--- | :--- | :--- |
| **Microphone** | Audio input for the in-app Voice Assistant bar. | *System Settings &rarr; Privacy & Security &rarr; Microphone* |
| **Speech Recognition** | On-device speech-to-text transcription via `SFSpeechRecognizer`. | *System Settings &rarr; Privacy & Security &rarr; Speech Recognition* |
| **Accessibility** (Optional) | Smooth multi-monitor brightness overlays and shortcut listening. | *System Settings &rarr; Privacy & Security &rarr; Accessibility* |

> [!NOTE]
> All speech recognition and natural language processing occur **100% locally on your Mac's Neural Engine**. No audio or prompt data ever leaves your device.

---

## 4. Connecting WiZ Smart Lights (v2 Local Protocol)

DeskOrbit communicates directly with WiZ smart bulbs over your local network using UDP port `38899` with **HMAC-SHA256 signature verification**. No cloud account or external internet connection is required.

### Method 1: Automatic Auto-Discovery (Easiest)
1. In the WiZ mobile app, navigate to **Settings &rarr; Home &rarr; Export Settings**.
2. Save or AirDrop the exported JSON configuration file (e.g. `homeStructure.json`) to your Mac's `~/Downloads` folder.
3. Launch DeskOrbit. The app automatically scans `~/Downloads`, extracts your numeric `home_id` and 16-byte `udp_signing_key`, and discovers active bulbs on your LAN.

### Method 2: Manual Configuration
1. Open the DeskOrbit Dashboard (`Cmd + O` or click the Dashboard button in the Menu Bar popover).
2. Navigate to **Smart Lights** in the sidebar.
3. Click **Add Bulb** or **Configure WiZ Home**:
   - **Bulb IP:** Enter the local static IP of your bulb (e.g., `192.168.1.2`).
   - **Home ID:** Enter your WiZ numeric Home ID.
   - **Signing Key:** Enter your 32-character hex key (e.g., `f1890f8362f76dc92dda2e76ff9e916c`).
4. Click **Save & Connect**.

> [!TIP]
> **Dual-Band Wi-Fi (5GHz Mac &harr; 2.4GHz Bulb):**
> If your Mac is connected to 5GHz Wi-Fi and your bulb is on 2.4GHz, consumer routers may drop cross-band ARP entries during idle periods. DeskOrbit includes built-in kernel ARP self-healing via synchronous ICMP ping probes to keep the connection instant.

---

## 5. Voice Assistant & Siri AI

DeskOrbit v1.5.0 introduces voice control without requiring an Apple HomeKit hub or HomePod.

### In-App Voice Assistant Bar
1. Look at the top of the DeskOrbit Dashboard or Menu Bar popover.
2. Click the **Microphone icon** (or press the voice shortcut).
3. Speak your command naturally. DeskOrbit's hybrid parser (Circadian curves + Apple Foundation Model) processes your intent instantly.

### Siri Voice Commands & Shortcuts
Because DeskOrbit provides native **App Intents**, you can control your desk hands-free via Siri:
- *"Hey Siri, turn on lights in DeskOrbit"*
- *"Hey Siri, set light to 80% with DeskOrbit"*
- *"Hey Siri, match lights with daytime in DeskOrbit"*
- *"Hey Siri, set lights to crimson with DeskOrbit"*
- *"Hey Siri, mute audio in DeskOrbit"*

### Supported Natural Language Commands
- **Daylight & Circadian Sync:**
  - *"Match the light with daytime"*
  - *"Set circadian rhythm"*
  - *(Dynamically calculates solar elevation: cool 6000K daylight at noon, gentle 4800K in afternoon, warm 2200K amber at night).*
- **Cinematic & Thematic Presets:**
  - *"Change color to theme of Money Heist"* &rarr; Deep Crimson Red (`#DC143C`)
  - *"Cyberpunk mode"* &rarr; Electric Neon Cyan / Magenta
  - *"Matrix green"* &rarr; Matrix Phosphor Green
  - *"Interstellar vibe"* &rarr; Deep Space Indigo
- **Audio & Volume Control:**
  - *"Set volume to 50%"* / *"Volume up"* / *"Make it louder"* / *"Volume to sixty percent"*
  - *"Set MacBook speaker volume to 40%"* (targets built-in speakers)
  - *"Set JBL volume to 80%"* / *"Set headphones volume to 65%"* (targets specific active audio peripheral)
  - *"Mute audio"* / *"Mute MacBook"* / *"Unmute"*
- **Display Brightness:**
  - *"Set display brightness to 80%"* / *"Screen brighter"* / *"Dim monitor"*
  - *"Set external monitor brightness to 60%"*
- **Standard Lighting:**
  - *"Turn on lights"*, *"Turn off lights"*, *"Dim to 20%"*, *"Set brightness to 75%"*
  - *"Warm white for relaxing"*, *"Cool white for focus"*

---

## 6. External Displays, Audio & Power Telemetry

### External Monitor Backlight (DDC/CI)
- DeskOrbit sends standard DDC VCP code `0x10` directly over the Apple Silicon I²C bus to your monitor microcontroller.
- Supports LG UltraFine, Dell UltraSharp, BenQ, ASUS, and other major monitors.
- If DDC/CI is disabled in your monitor's physical OSD menu, DeskOrbit seamlessly falls back to GPU Gamma LUT software dimming.

### Real-Time Power & Battery Telemetry
- Open the Menu Bar popover (right column) or Dashboard &rarr; **Power & Battery**.
- View negotiated USB-PD charging wattage, real-time input voltage/amperage, battery health percentage against factory design capacity, cycle wear, and power brick serial numbers.

---

## 7. Troubleshooting & Diagnostics

- **Live Socket Logs:**
  DeskOrbit writes timestamped diagnostics to `/tmp/deskorbit.log`. To inspect real-time UDP pilot dispatches:
  ```bash
  tail -f /tmp/deskorbit.log
  ```
- **Verify Bulb Network Reachability:**
  ```bash
  ping -c 3 192.168.1.2
  ```
- **Reset Configuration:**
  If you ever need to clear saved bulbs and signing keys:
  ```bash
  defaults delete com.deskorbit.DeskOrbit
  ```

---

## 8. Need Help or Have Feedback?

- [Interactive Web Documentation](https://neeraj15022001.github.io/DeskOrbit/)
- [Release Changelog](https://neeraj15022001.github.io/DeskOrbit/changelog.html)
- [GitHub Issues & Discussions](https://github.com/neeraj15022001/DeskOrbit/issues)
