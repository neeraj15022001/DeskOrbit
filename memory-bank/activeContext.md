# Active Context: DeskOrbit

## Current State & Recent Milestones
DeskOrbit has reached version **v1.5.0**, introducing an on-device Voice Assistant powered by Apple's native **Foundation Models** framework (`SystemLanguageModel`), cross-band Wi-Fi ARP self-healing for WiZ smart lights, and full App Shortcuts / App Intents integration for Siri.

### Live Hardware & Intelligence Verification (Completed)
- **Target Bulb:** Philips WiZ A60 Smart Bulb.
- **Bulb MAC Address:** `98:77:d5:e9:d3:36`.
- **Static DHCP Address:** `192.168.1.2:38899`.
- **Home ID:** `21840859`.
- **UDP Signing Key:** `f1890f8362f76dc92dda2e76ff9e916c`.
- **Apple Intelligence Foundation Model:** `SystemLanguageModel.default` from `FoundationModels.framework` active on Apple Silicon Neural Engine.
- **Physical Verification:** Bulb verified toggling, dimming, setting RGB colors, adjusting color temperature (2000K-6500K), and applying complex cultural/thematic prompts with sub-second response times.

---

## Recent Critical Architecture Decisions

### 1. Apple On-Device Foundation Model Integration (`FoundationModels.framework`)
- **Architecture:** Directly imports Apple's `FoundationModels` framework and initializes `SystemLanguageModel.default` with customized system instructions.
- **Dual-Tier Hybrid AI Pipeline:**
  - **Tier 1 (Instant / Zero-latency):** Mathematical solar circadian calculator for time-of-day dynamic lighting and pre-cached thematic tokens (Money Heist, Cyberpunk, Matrix, etc.).
  - **Tier 2 (On-Device LLM):** For open-ended natural language requests, `SystemLanguageModel` dynamically parses prompts into structured JSON lighting parameters (`r`, `g`, `b`, `brightness`, `kelvin`, `description`).
- **Apple HIG Generative AI Alignment:** Follows Apple's guidelines on on-device privacy, predictable latency, specific feedback during generation, and preserving human control.

### 2. POSIX Socket Routing & Cross-Band ARP Auto-Recovery
- **Discovery:** On dual-band routers (e.g. Airtel AOT-4221SR) where Mac is on 5 GHz and WiZ bulb is on 2.4 GHz, macOS kernel routing periodically expires ARP entries when idle, returning `errno=64 (EHOSTDOWN)` or `errno=65 (EHOSTUNREACH)` on `sendto()`.
- **Solution:** In `WizLightService.sendUDPUnicast`, if `sendto()` returns `errno=64` or `errno=65`, a synchronous, ultra-fast 150ms ping probe is triggered immediately to re-prime the kernel ARP table, followed by an immediate packet retry in the same call.
- **Darwin `errno` Sanitation:** Initialized `errno = 0` explicitly before every socket syscall to prevent false-positive error evaluations.

### 3. Real-Time UI Synchronization & Active Mode Switching
- **Fix:** Routed all voice assistant hardware actions through `DeviceManager` (`manager.setLightRGBColor`, `manager.setLightTemperature`, `manager.setLightBrightness`).
- **Tab State Auto-Switching:** Setting an RGB color automatically flips `activeLightModes[light.id] = "Colors"`, and setting white temperature flips it to `"Whites"`. The UI card and bulb glow update instantly on `@Published` mutations on the main thread.

### 4. Mach-O Embedded `__info_plist` & TCC Privacy Authorization
- **Discovery:** macOS TCC abruptly terminated the app (`EXC_CRASH / SIGABRT` namespace `TCC`) when requesting microphone and speech recognition permissions because the standalone SwiftPM binary did not have an embedded `__info_plist` section.
- **Fix:** Added `-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Info.plist` to linker flags in `bundle_app.sh`, accompanied by automated bundle detritus cleaning (`dot_clean` + `xattr -c`) and ad-hoc code-signing.

### 5. App Intents Extraction for Apple Shortcuts & Siri AI
- **Implementation:** Added `DeskOrbitShortcutsProvider` and 6 App Intents (`TurnLightOnIntent`, `SetBulbBrightnessIntent`, `SetBulbColorIntent`, etc.).
- **Build Pipeline:** Integrated `xcrun appintentsmetadataprocessor` into `bundle_app.sh` using `-emit-const-values-path` to extract and package `Metadata.appintents` inside `DeskOrbit.app/Contents/Resources`.

### 6. Named Audio/Display Device Targeting & Intent Cross-Bleed Isolation
- **Discovery:** Directionless audio queries like *"adjust volume"* failed regex percentage matching (`\d+`) and dropped to the on-device Foundation Model, which previously mapped all unclassified requests to smart lighting presets. Furthermore, verbal commands referencing specific devices (e.g., *"set MacBook speaker volume to 50%"*) were ignored, routing volume mutations exclusively to `manager.defaultAudioOutput`.
- **Solution:**
  - Expanded `AssistantAction` payloads to include target identifiers: `.setAudioVolume(percent: Int, deviceName: String?)`, `.setAudioMute(isMuted: Bool, deviceName: String?)`, and `.setDisplayBrightness(percent: Int, displayName: String?)`.
  - Implemented `extractAudioTarget`: scans active `AudioItem` instances for exact name, multi-word token overlap (`"JBL"`, `"MacBook"`, `"SA272"`), and hardware synonyms (`"internal"`, `"speaker"`, `"bluetooth"`, `"hdmi"`).
  - Implemented `extractPercentageOrWordNumber`: converts spoken numbers (*"fifty"*, *"half"*, *"max"*) into normalized percentages.
  - Directionless queries calculate delta from active device volume (+15% / -15%).
  - Multi-target Foundation Model: partitioned system prompt and JSON decoding across `target: "audio" | "display" | "light"`.

### 7. Explicit Power & Mute State Enforcement
- **Fix:** Added `DeviceManager.setLightPower(light: WizLightItem, isOn: Bool)` to ensure spoken *"turn on"* and *"turn off"* enforce absolute boolean targets rather than blind toggle inversion via `toggleLightPower`.
- Applied identical explicit state verification for `setAudioMute(isMuted: Bool, deviceName: String?)`.

---

## Active Focus & Next Steps
1. **Adaptive Circadian Schedule Daemon:** Add an optional background timer to slowly adjust Kelvin temperature matching the daylight curve throughout the day.
2. **Multi-Bulb Grouping:** Group multiple bulbs into unified zones (e.g., Desk, Ceiling, Ambient) for synchronized AI commands.
3. **Release Packaging:** Update automated GitHub Release tag to `v1.5.0` with the universal `.dmg`.
