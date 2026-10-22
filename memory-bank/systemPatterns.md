# System Patterns: DeskOrbit

## System Architecture

```
+---------------------------------------------------------------------------------------+
|                                    USER INTERFACE                                     |
|                                                                                       |
|   +------------------------------------+    +-------------------------------------+   |
|   |  Dual-Column Menu Bar Popover      |    |  Full Home-Style Dashboard Window   |   |
|   |  (590px: Devices Left, Power Right)|    |  (Auto-launched, Category Nav)      |   |
|   +-----------------+------------------+    +------------------+------------------+   |
+---------------------|------------------------------------------|----------------------+
                      |                                          |
                      v                                          v
+---------------------------------------------------------------------------------------+
|                              DEVICE MANAGER (ORCHESTRATOR)                            |
|                            ObservableObject Central Registry                          |
+----+--------------------+--------------------+--------------------+-------------------+
     |                    |                    |                    |
     v                    v                    v                    v
+-----------+       +-----------+        +-----------+        +-----------+
|  Display  |       |   WiZ     |        |  Battery  |        |   Audio   |
|  Service  |       |  Service  |        |  Service  |        |  Service  |
+-----+-----+       +-----+-----+        +-----+-----+        +-----+-----+
      |                   |                    |                    |
      v                   v                    v                    v
+-----------+       +-----------+        +-----------+        +-----------+
|IOAVService|       |POSIX BSD  |        | IOKit     |        |CoreAudio  |
|  DDC/CI   |       |UDP Socket |        |AppleSmart |        |Hardware   |
|Gamma LUT  |       |HMAC-SHA256|        |  Battery  |        |HAL Audio  |
+-----------+       +-----------+        +-----------+        +-----------+
```

---

## Subsystem Design Patterns & Protocols

### 1. WiZ v2 Cryptographic UDP Protocol (`WizLightService.swift`)
Modern WiZ smart bulbs (firmware &ge;1.38.0) reject legacy unauthenticated `setPilot` UDP packets with error codes. Control requires cryptographic message authentication.

#### Key Invariants & Packet Generation:
1. **Target Port:** UDP `38899` unicast to bulb IP, or broadcast `255.255.255.255`.
2. **Parameters Sort Order:** Parameters within the `"params"` object MUST be alphabetically serialized by key name without whitespace:
   - Example: `{"b":100,"mac":"9877d5e9d336","r":255,"state":true}`
3. **Monotonic Timestamp Tracking (`ts`):**
   - The bulb maintains a 32-bit counter (`ts`).
   - Responses to `getPilot` include the current counter: `{"result":{"mac":"...","ts":12345,...}}`.
   - Each outgoing command must supply a timestamp $\ge \text{lastKnownTs} + 1$. DeskOrbit increments this counter atomically to prevent replay rejection.
4. **HMAC-SHA256 Signature Calculation:**
   - Raw binary secret: 16-byte `udp_signing_key` decoded from hex (e.g. `f1890f8362f76dc92dda2e76ff9e916c`).
   - Envelope:
     $$\text{message} = \text{ts} + \text{compactSortedParamsJson}$$
     $$\text{digest} = \text{HMAC-SHA256}(\text{key} = \text{binarySigningKey}, \text{data} = \text{message})$$
     $$\text{envelope} = \text{Base64}(\text{digest})$$
5. **Signed Pilot Payload:**
   ```json
   {
     "method": "setPilot",
     "env": "Base64Digest==",
     "params": {
       "b": 100,
       "mac": "9877d5e9d336",
       "state": true,
       "ts": 12346
     }
   }
   ```
6. **macOS Darwin BSD Socket Alignment (`sin_len`):**
   - On macOS Darwin kernels, `struct sockaddr_in` includes an explicit length member `sin_len`.
   - Failing to populate `sin_len = UInt8(MemoryLayout<sockaddr_in>.size)` causes `sendto()` to fail silently or return `EINVAL` on modern macOS versions.
   - Sockets are configured with `SO_BROADCAST = 1` and `SO_RCVTIMEO` / `SO_SNDTIMEO` (500ms) non-blocking timeouts.

### 2. Display Luminance Control (`DisplayService.swift`)
DeskOrbit applies a three-tiered fallback pattern for display brightness:
- **Tier 1 (Apple Silicon DDC/CI):** Directly loads Apple Silicon I²C driver `IOAVServiceCreate(kCFAllocatorDefault)` and dispatches DDC VCP code `0x10` (`kDisplayBrightnessVCP`) over bus address `0x37`.
- **Tier 2 (Apple Native Backlight):** For Apple Studio Displays and internal Retina panels, interfaces with private `DisplayServicesSetBrightness(displayID, Float)`.
- **Tier 3 (GPU Gamma LUT Manipulation):** For external screens without DDC/CI hardware support, calculates linear gamma transfer tables via `CGSetDisplayTransferByTable(displayID, tableSize, red, green, blue)` to software-dim the output without crushing contrast.
- **Tier 4 (Window Level Overlay):** Transparent click-through `.screenSaver` level overlay window spanning all virtual Spaces.

### 3. Battery & Power Hardware Profiling (`BatteryPowerService.swift`)
- Queries IOKit master port `kIOMainPortDefault` for matching service `AppleSmartBattery`.
- Pulls live properties:
  - Real-time input wattage: `IPDInputPower`, `IPDInputVoltage`, `IPDInputCurrent`.
  - Battery capacity health: $\frac{\text{NominalCapacity}}{\text{DesignCapacity}} \times 100\%$.
  - Wear statistics: `CycleCount`, `BatteryInstalled`, `Amperage` (charge/discharge flow in mA), `Voltage` (mV), `Temperature` (scaled by 10 in °C).
  - Power adapter profiling: Manufacturer, Watts, Hardware Revision, Serial Number, and USB-PD Contract specifications.

### 4. Audio Routing & CoreAudio HAL (`AudioService.swift`)
- Direct interaction with CoreAudio Hardware Abstraction Layer via `kAudioObjectSystemObject`.
- Reads and updates `kAudioHardwareServiceDeviceProperty_VirtualMainVolume` across default output devices.
- Uses `AudioObjectAddPropertyListenerBlock` to listen for hardware route changes (headphones plugged in/out, AirPods connection) and updates the UI instantly without polling loops.

### 5. Application Lifecycle & Presentation (`AppDelegate.swift`)
- Configured with `LSUIElement = true` (Agent mode) to keep the Dock clean during menu bar background operation.
- On application launch, automatically presents and focuses the floating Home-style Dashboard window:
  ```swift
  func applicationDidFinishLaunching(_ notification: Notification) {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
          self.openDashboard()
      }
  }
  ```
- Implements `applicationShouldHandleReopen:hasVisibleWindows:` ensuring clicks on the application icon in Finder, Dock, or Spotlight reliably reopen and focus the Dashboard.


### 6. Apple HIG & macOS Golden Gate 27 Liquid Glass Architecture (`LiquidGlass.swift`, `ControlSliders.swift`)

#### Two-Layer Depth Separation Model:
- **Floating Functional Layer:** Navigation bars, toolbars, modal headers, and floating sidebars utilize Liquid Glass (`.liquidGlass(.regular)`) with background vibrancy and edge-diffusion over scrolling cards.
- **Content Layer:** Device cards, lists, and main window backdrops use semantic solid fills (`NSColor.controlBackgroundColor` and subtle borders), eliminating "glass on glass" visual muddiness.
- **Transient Interaction Sheen:** In the content layer, tactile capsule sliders take on specular highlights and specular edge gradients exclusively during active mouse hover and scrubbing.

#### Control Center Tactile Sliders (`OrbitCapsuleSlider` & `OrbitKelvinSlider`):
- **Capsule Track Geometry:** Continuous 28pt capsule track with dynamic leading SF Symbol glyphs and high-contrast text adaptation.
- **Continuous Gesture Scrubbing:** Direct drag gesture computes normalized fraction `(drag.location.x / totalWidth)` with instant haptic responsiveness.
- **Kelvin Spectrum Track:** Maps 2200K–6500K across an amber-to-cyan gradient track with a high-contrast draggable capsule thumb.

#### Accessibility Floor & Edge-to-Edge Windowing:
- **Strict Typography Floor:** All labels and readouts are $\ge 10\text{pt}$, completely eradicating sub-10pt micro-type.
- **Hit Targets:** Buttons and interactive icons maintain minimum $\ge 24\times 24\text{pt}$ / $28\times 28\text{pt}$ frames.
- **Accessibility Degradation:** Automatic observation of `accessibilityDisplayShouldReduceTransparency` (swapping blur for opaque fill) and `accessibilityDisplayShouldIncreaseContrast` (doubling border strokes).
- **Edge-to-Edge Content:** Configured `window.styleMask.insert(.fullSizeContentView)` and `window.titlebarAppearsTransparent = true` in `AppDelegate.swift`.

### 7. Voice Assistant & Apple Foundation Models (`VoiceAssistantService.swift`, `OrbitNaturalLanguageParser.swift`)
DeskOrbit pairs native speech recognition with Apple's on-device Foundation Model runtime (`FoundationModels.framework` / `SystemLanguageModel`):
- **Dual-Tier Hybrid Parser Architecture:**
  - **Tier 1 (Instant Local Rules & Circadian Curves):**
    - Instant regex matching for power (`turn on`, `off`), brightness (`set brightness to 60%`), and Kelvin temperatures (`warm white`, `daylight`, `reading`).
    - Pre-compiled cinematic & atmospheric presets: *Money Heist* (crimson `#DC143C`), *Cyberpunk* (electric neon cyan/magenta), *Matrix* (matrix green), *Interstellar* (deep space indigo).
    - Dynamic Solar Circadian Curve: Maps queries like "match light with daytime" or "circadian rhythm" against 5 temporal intervals (dawn, midday 6000K, afternoon 4800K, sunset 3000K, night 2200K amber) based on user's exact system time.
  - **Tier 2 (On-Device Apple Intelligence):**
    - Invokes `SystemLanguageModel.default` when available on Apple Silicon running macOS Sequoia.
    - Guides inference with a multi-device system prompt partitioned across `target: "audio" | "display" | "light"`.
    - Handles open-ended natural language while strictly isolating audio and display adjustments from lighting mutations.
    - Zero cloud network calls; 100% private, on-device Neural Engine execution.
  - **Named Device Resolution Engine (`extractAudioTarget` & `extractDisplayTarget`):**
    - Dynamically scans active peripherals in `DeviceManager.shared.audioDevices` and `displays`.
    - Resolves target devices by full name, token overlap (`"JBL"`, `"MacBook"`, `"SA272"`), and hardware synonyms (`"internal"`, `"speaker"`, `"bluetooth"`, `"hdmi"`).
    - Supports spoken word numbers ("fifty", "half", "max") and relative level scaling (+15% / -15%).
- **TCC Permission Enforcement for Command Line / SwiftPM Executables:**
  - `SFSpeechRecognizer` and `AVAudioEngine` enforce TCC checks at Mach-O load time. If the Mach-O binary lacks an embedded `__info_plist` section, macOS raises `SIGABRT` upon microphone activation.
  - Resolved in `bundle_app.sh` by passing `-Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$DIR/Info.plist"` during SwiftPM linking, followed by ad-hoc deep code signing.

### 8. Siri & Shortcuts Integration via App Intents (`DeskOrbitAppIntents.swift`)
Direct zero-bridge integration with Apple Siri AI and Shortcuts via `AppIntents.framework`:
- **Native Intents:**
  - `ToggleDeskOrbitLightIntent`: Toggle power state.
  - `SetDeskOrbitBrightnessIntent`: Target brightness (1–100%).
  - `SetDeskOrbitLightColorIntent`: Preset colors (Red, Crimson, Cyberpunk Neon, Green, Blue, Sunset, Candlelight, White).
  - `SetDeskOrbitCircadianIntent`: Sync lighting with daytime solar curve.
  - `SetDeskOrbitDisplayBrightnessIntent`: External monitor hardware luminance.
  - `MuteDeskOrbitAudioIntent`: System master mute control.
- **AppShortcutsProvider:** Registers automatic Siri phrases (`"Turn on lights in DeskOrbit"`, `"Match lights with daytime in DeskOrbit"`).
- **Metadata Compilation Pipeline:** SwiftPM does not compile `.appintents` metadata natively. `bundle_app.sh` uses `xcrun appintentsmetadataprocessor` with `-source-file-list` and `-swift-const-vals-list` (produced by `-Xswiftc -emit-const-values-path`) to generate `Contents/Resources/Metadata.appintents`.

### 9. Dual-Band Cross-Band Network Self-Healing ARP Probing (`WizLightService.swift`)
Dual-band consumer routers (e.g. Airtel, Netgear, TP-Link) route Mac traffic on 5GHz to WiZ bulbs on 2.4GHz:
- After idle periods, the router's ARP cache for the 2.4GHz target expires, causing the Darwin kernel to drop outgoing UDP packets and raise `EHOSTDOWN (64)` or `EHOSTUNREACH (65)`.
- **Self-Healing Loop:**
  - `WizLightService` intercepts `EHOSTDOWN` / `EHOSTUNREACH` in `sendSignedDatagram()`.
  - Executes a synchronous 150ms ICMP ping probe (`/sbin/ping -c 1 -W 150 <bulbIP>`), forcing the macOS kernel network stack and router to resolve ARP immediately.
  - Retries socket dispatch on the same function invocation, providing 100% packet delivery without user-facing failures.
- **SwiftUI Mode Synchronization:**
  - When setting RGB color via voice or App Intents, `DeviceManager.setLightRGBColor` explicitly sets `activeLightModes[light.id] = "Colors"`.
  - Prevents mode desynchronization in `WizLightCardView`, ensuring UI sliders and glowing color orbs update instantaneously on the main thread.
