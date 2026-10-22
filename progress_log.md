# Engineering Progress Log: DeskOrbit

This log documents the chronological development history, engineering decisions, reverse-engineering discoveries, and milestone verifications of DeskOrbit.

---

## 2026-10-23: On-Device Foundation Models, Siri AI & Network Self-Healing (v1.5.0)

### Phase 1: On-Device Voice Assistant & Speech Framework
- **Goal:** Enable hands-free control of hardware peripherals and smart lighting from DeskOrbit.
- **Implementation:**
  - Implemented `VoiceAssistantService.swift` using Apple's `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true` and `AVAudioEngine`.
  - Added interactive Liquid Glass waveform visualizer (`VoiceAssistantBarView.swift`) to both the Dashboard and Menu Bar popover.
- **TCC Privacy Crash Resolution:**
  - *Symptom:* Clicking the mic button caused macOS TCC to crash the process with `EXC_CRASH (SIGABRT)` citing missing usage descriptions even though `Info.plist` had `NSSpeechRecognitionUsageDescription` and `NSMicrophoneUsageDescription`.
  - *Root Cause:* Standalone SwiftPM executables lack an embedded `__info_plist` Mach-O segment, causing TCC to report `Info.plist=not bound`.
  - *Fix:* Passed `-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Info.plist` during compilation and added automated `dot_clean` + `codesign --force --deep --sign -` to `bundle_app.sh`.

### Phase 2: Apple Foundation Models & Generative AI (`FoundationModels.framework`)
- **Discovery:** macOS provides native access to Apple's on-device 3B Foundation Model via `FoundationModels.framework` on Apple Silicon Neural Engine (`SystemLanguageModel.default`).
- **Architecture:**
  - Linked `FoundationModels.framework` in `Package.swift`.
  - Built `OrbitNaturalLanguageParser.swift` with a dual-tier hybrid architecture:
    1. **Circadian Calculator:** Computes exact solar Kelvin and dimming (2000K-5800K) based on local time of day.
    2. **Thematic Engine:** Pre-compiled semantic presets for cultural themes (Money Heist Crimson Red `rgb: 220, 20, 60`, Cyberpunk Neon, Matrix Terminal Green, etc.).
    3. **On-Device LLM:** Initialized `LanguageModelSession(model: SystemLanguageModel.default, instructions: ...)` to parse arbitrary conversational queries into structured lighting JSON.

### Phase 3: Cross-Band Wi-Fi ARP Expiration & Self-Healing Sockets
- **Problem:** When Mac is connected to 5 GHz Wi-Fi and WiZ bulbs are on 2.4 GHz, router cross-band bridging times out after periods of inactivity, causing POSIX `sendto()` to fail with `errno=64 (EHOSTDOWN)` or `errno=65 (EHOSTUNREACH)`.
- **Solution:** In `WizLightService.sendUDPUnicast`:
  - Reset `errno = 0` prior to socket operations.
  - On catching `EHOSTDOWN` or `EHOSTUNREACH`, immediately executes a synchronous 150ms ICMP ping probe to re-prime the kernel routing table, then retries the UDP transmission within the same call.
- **Result:** Toggling and color changes now succeed reliably 100% of the time.

### Phase 4: App Intents & Siri Shortcuts Integration
- **Implementation:** Built `DeskOrbitAppIntents.swift` defining 6 App Intents (`TurnLightOnIntent`, `SetBulbBrightnessIntent`, `SetBulbColorIntent`, etc.) and `DeskOrbitShortcutsProvider`.
- **Extraction Pipeline:** Enhanced `bundle_app.sh` with `-emit-const-values-path` and `xcrun appintentsmetadataprocessor` to compile and bundle `Metadata.appintents` in `Contents/Resources`.

### Phase 5: UI State Synchronization Fix
- **Problem:** Voice assistant changes adjusted the physical bulb, but the UI widget card didn't consistently update.
- **Root Cause:**
  1. `WizLightCardView` conditionally displays either the "Whites" or "Colors" controls based on `manager.activeLightModes[light.id]`. Setting an RGB color did not flip this mode to `"Colors"`, keeping the white slider visible.
  2. Voice service was modifying `wizLightService` directly instead of `manager.smartLights`.
- **Fix:** Routed all voice actions through `manager.setLightRGBColor` and `manager.setLightTemperature`, updating `activeLightModes` and notifying `@Published var smartLights` on the main thread.

### Phase 6: Named Audio/Display Device Targeting & Intent Cross-Bleed Isolation
- **Problem:** Directionless commands like *"adjust volume"* failed regex percentage parsing and dropped through to the Foundation Model, which previously mapped all unclassified requests to smart lighting presets. Furthermore, verbal commands referencing specific devices (e.g., *"set MacBook speaker volume to 50%"*) were ignored, routing volume mutations exclusively to `manager.defaultAudioOutput`.
- **Root Cause:**
  1. `AssistantAction.setAudioVolume` only accepted `percent: Int`, omitting device identity.
  2. `isVolumeIntent` didn't catch directionless phrases or word numbers ("fifty", "half", "max"), causing fallthrough.
  3. Foundation Model system prompt lacked multi-device schema, forcing all outputs into light presets.
- **Fix:**
  - Expanded `AssistantAction` payloads to include target identifiers: `.setAudioVolume(percent: Int, deviceName: String?)`, `.setAudioMute(isMuted: Bool, deviceName: String?)`, and `.setDisplayBrightness(percent: Int, displayName: String?)`.
  - Implemented `extractAudioTarget`: scans active `AudioItem` peripherals for exact names, token overlap (`"JBL"`, `"MacBook"`, `"SA272"`), and hardware synonyms (`"internal"`, `"speaker"`, `"bluetooth"`, `"hdmi"`).
  - Added `extractPercentageOrWordNumber`: converts spoken words and relative adjustments (+15% / -15%).
  - Multi-target Foundation Model: partitioned system instructions and JSON decoding across `target: "audio" | "display" | "light"`.

### Phase 7: Explicit Power & Mute State Enforcement
- **Fix:** Added `DeviceManager.setLightPower(light: WizLightItem, isOn: Bool)` ensuring verbal *"turn on"* and *"turn off"* set explicit target boolean states instead of inverting state via `toggleLightPower`.
- Applied identical explicit boolean state verification for `setAudioMute`.

---

## 2026-10-21: The WiZ v2 Local Control & Zero-Cloud Migration (v1.3.0 & v1.4.0)

### Phase 1: Direct LAN WiZ Exploration (v1.3.0)
- Implemented `WizLightService.swift` using native POSIX UDP sockets on port `38899`.
- Added subnet broadcast auto-discovery querying Darwin network interfaces (`getifaddrs`).

### Phase 2: Reverse Engineering WiZ v2 Firmware 1.38.0+
- Implemented HMAC-SHA256 envelope signing with alphabetical key sorting and monotonic timestamp tracking (`ts`).

### Phase 3: Darwin BSD Socket Alignment & Live Physical Verification
- Corrected `sin_len = UInt8(MemoryLayout<sockaddr_in>.size)` on Darwin BSD sockets.

### Phase 4: Complete Removal of Samsung SmartThings & UX Polish (v1.4.0)
- Completely purged all Samsung SmartThings cloud APIs, tokens, and rate limiters for 100% local operation.
