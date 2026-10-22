# Technical Context: DeskOrbit

## Technologies & Frameworks

### Core Platform
- **Programming Language:** Swift 5.9 / Swift 6
- **UI Frameworks & Design System:** SwiftUI + AppKit (`NSStatusItem`, `NSPopover`, `NSWindow`, `NSApplication`, `NSVisualEffectView`)
  - **macOS Golden Gate 27 Liquid Glass:** `LiquidGlass.swift` modifier with dynamic vibrancy materials (`.regular`, `.clear`, `.tinted`) and accessibility contrast degradation.
  - **Tactile Sliders:** `ControlSliders.swift` (`OrbitCapsuleSlider` & `OrbitKelvinSlider`) featuring 28pt Control Center capsule geometry and transient interaction specular sheen.
- **Target OS:** macOS 14.0+ (Sonoma, Sequoia)
- **Architectures:** Universal Binary (`arm64` Apple Silicon & `x86_64` Intel)

### Low-Level Darwin & C Frameworks
- **FoundationModels (`FoundationModels.framework`):**
  - Apple native `SystemLanguageModel.default` running directly on Apple Silicon Neural Engine (macOS Sequoia / Apple Intelligence). Open-ended natural language intent parser to structured JSON.
- **Speech & Audio Engine (`Speech.framework`, `AVFoundation.framework`):**
  - Native `SFSpeechRecognizer` real-time audio buffer transcription paired with `AVAudioEngine`.
  - Embedded `__info_plist` Mach-O binary section compliance for TCC microphone & speech authorization.
- **AppIntents (`AppIntents.framework`):**
  - Native Siri AI voice triggers and macOS Shortcuts actions without HomeKit bridges.
  - Compile-time metadata extraction via `xcrun appintentsmetadataprocessor` producing `Metadata.appintents`.
- **POSIX BSD Sockets (`sys/socket.h`, `arpa/inet.h`, `netinet/in.h`):**
  - Manages non-blocking UDP communication on port `38899`.
  - Configures `SO_BROADCAST`, `SO_RCVTIMEO`, and Darwin-specific `sockaddr_in.sin_len`.
  - Kernel ARP self-healing via synchronous ICMP ping for cross-band router traversal (5GHz Mac to 2.4GHz bulb).
- **CommonCrypto (`CommonCrypto/CommonHMAC.h`):**
  - High-performance SHA-256 HMAC cryptographic signing for WiZ v2 envelope generation.
- **IOKit & AppleSmartBattery (`IOKit/IOKitLib.h`):**
  - Direct hardware access to battery management unit (BMU), charging input power, cycle wear, and power adapter telemetry.
- **CoreAudio HAL (`CoreAudio/AudioHardware.h`):**
  - System-wide hardware audio volume scalar manipulation, mute state, and device routing via `AudioObjectPropertyAddress`.
- **Apple Silicon DDC/CI (`IOAVService`):**
  - Private I²C communication with external monitor microcontrollers for hardware backlight and contrast control.
- **DisplayServices (`DisplayServices.framework`):**
  - Private framework for controlling Apple Studio Display and internal MacBook screen brightness.
- **DiskArbitration (`DiskArbitration.framework`):**
  - Disk mount/unmount detection and safe external volume ejection.

---

## Dependencies & Third-Party Code
- **Zero Third-Party Dependencies:** DeskOrbit deliberately uses **zero external Swift packages (SPM)**, zero CocoaPods, and zero dynamic libraries.
- All network serialization, cryptography, hardware polling, and UI components are implemented entirely using Apple standard libraries and Darwin primitives.

---

## Storage & Persistence
- **UserDefaults:**
  - `WizSavedHomeId`: Numeric WiZ home identifier (e.g. `21840859`).
  - `WizSavedSigningKey`: Hex-encoded 16-byte UDP signing key (e.g. `f1890f8362f76dc92dda2e76ff9e916c`).
  - `WizCustomBulbs`: JSON-encoded array of discovered/manually added WiZ bulbs (`WizLightDevice`).
- **File System Auto-Discovery:**
  - Scans `~/Downloads` for WiZ export files (`*.json`) containing `udp_signing_key` and `home_id`.
- **Diagnostics File:**
  - Appends timestamped socket, HMAC, and service logs to `/tmp/deskorbit.log`.

---

## Build, Test & Packaging Pipelines
- **Build Tool:** `swift build -c release --arch arm64 --arch x86_64`
- **Application Bundle Packaging:** `bundle_app.sh`
  - Assembles `DeskOrbit.app` with vector AppIcon ICNS, resource assets, and embedded Mach-O `__info_plist` section.
  - Extracts and compiles AppIntents metadata via `xcrun appintentsmetadataprocessor` (`Metadata.appintents`).
  - Cleans extended attributes and applies ad-hoc deep code signing (`codesign --force --deep --sign -`).
- **Release DMG Generation:** `create_dmg.sh`
  - Produces compressed, distributable `DeskOrbit.dmg` with `/Applications` drag-and-drop symlink.
- **Continuous Integration (CI):**
  - `.github/workflows/ci.yml`: Automated compilation and verification for pull requests.
  - `.github/workflows/release.yml`: Automated build triggered on every push to `main` (or version tags), dynamic version & tag resolution from `CHANGELOG.md`, DMG/ZIP packaging with SHA256 checksums, and GitHub Releases publication.
  - `.github/workflows/pages.yml`: Automated deployment of `docs/` to GitHub Pages.
