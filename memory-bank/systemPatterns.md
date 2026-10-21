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
