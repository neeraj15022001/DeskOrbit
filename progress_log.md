# Engineering Progress Log: DeskOrbit

This log documents the chronological development history, engineering decisions, reverse-engineering discoveries, and milestone verifications of DeskOrbit.

---

## 2026-10-21: The WiZ v2 Local Control & Zero-Cloud Migration (v1.3.0 & v1.4.0)

### Phase 1: Direct LAN WiZ Exploration (v1.3.0)
- **Problem Statement:** Controlling WiZ bulbs via Samsung SmartThings Cloud REST API worked, but suffered from 500ms–1500ms latency and occasional API rate limit freezes during continuous color/brightness slider movement.
- **Initial Implementation:**
  - Implemented `WizLightService.swift` using native POSIX UDP sockets on port `38899`.
  - Added subnet broadcast auto-discovery querying Darwin network interfaces (`getifaddrs`) with `{"method":"getSystemConfig"}`.
  - Implemented legacy WiZ UDP commands (`{"method":"setPilot","params":{"state":true,"dimming":100}}`).
  - Added manual IP modal sheet for partitioned networks and dynamic WiZ scenes (Fireplace, Sunset, Party).
- **Result:** Successfully committed in `97d9b41`.

### Phase 2: Reverse Engineering WiZ v2 Firmware 1.38.0+
- **Symptom:** The physical WiZ bulb (`9877d5e9d336`) at `192.168.1.6` was discovered on the network, but silently rejected or dropped legacy `setPilot` UDP packets. The light would not turn on or off.
- **Root Cause Investigation:**
  - User generated a temporary 15-minute third-party integration link in the WiZ v2 mobile application and downloaded the home configuration JSON payload (`b60fcab415ee99eb4cfceb206593924055848fffa25bee65bd8fc7b9e44c1f5f.json`).
  - Analyzing this payload revealed:
    - `home_id`: `21840859`
    - `udp_signing_key`: `f1890f8362f76dc92dda2e76ff9e916c` (16 binary bytes)
    - Modern WiZ bulbs running firmware `v1.38.0+` enforce local cryptographic packet signing to prevent unauthorized devices on the local Wi-Fi from manipulating lights.
- **Cryptographic Protocol Implementation:**
  1. **Monotonic Counter (`ts`):** Modern firmware validates timestamps to defeat replay attacks. The bulb responds to `getPilot` with its internal counter `ts`. DeskOrbit dynamically tracks and increments this counter for every dispatched pilot.
  2. **Parameter Key Ordering:** JSON parameters in `params` must be sorted alphabetically by key name without extraneous whitespace.
  3. **HMAC-SHA256 Envelope (`env`):**
     $$\text{payload} = \text{ts} + \text{compactSortedParamsJson}$$
     $$\text{env} = \text{Base64}(\text{HMAC-SHA256}(\text{key} = \text{binaryKey}, \text{data} = \text{payload}))$$
  4. Dispatched signed envelope in commit `aabb190`.

### Phase 3: Darwin BSD Socket Alignment & Live Physical Verification
- **Symptom:** Sockets on macOS Darwin kernels were intermittently failing to dispatch unicast UDP datagrams to `192.168.1.6:38899`.
- **Root Cause:**
  - On Darwin/BSD POSIX sockets, `struct sockaddr_in` includes a mandatory `sin_len` field. When uninitialized, `sendto()` dropped packets or returned `EINVAL`.
- **The Fix:**
  ```swift
  var addr = sockaddr_in()
  addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
  addr.sin_family = sa_family_t(AF_INET)
  addr.sin_port = in_port_t(port).bigEndian
  ```
- **Live Terminal Verification:** Dispatched a live signed packet to `192.168.1.6:38899`.
  - Response received: `{"method":"setPilot","env":"...","result":{"success":true}}`.
  - The physical bulb toggled instantly with zero latency (<10ms).

### Phase 4: Complete Removal of Samsung SmartThings & UX Polish (v1.4.0)
- **User Decision:** Remove Samsung SmartThings cloud integration entirely to make DeskOrbit 100% offline, private, and local-first.
- **Purge Execution:**
  - Removed SmartThings Personal Access Token (PAT) storage and UI sheets.
  - Purged all `api.smartthings.com/v1` REST networking and debouncers.
  - Added auto-discovery of downloaded WiZ configuration JSON files in `~/Downloads`, sorted by newest modification date.
  - Added automatic presentation and focusing of the Dashboard window in `AppDelegate.swift` on launch, plus `applicationShouldHandleReopen:hasVisibleWindows:`.
  - Replaced ambiguous menu bar header power icon with explicit Dashboard Window and Quit buttons.
- **Result:** Successfully committed in `d6409cf` and pushed to `main`.

### Phase 5: Automated Continuous GitHub Release Workflow
- **Goal:** Trigger automated build and release generation whenever new code is pushed to `main`.
- **Workflow Architecture (`.github/workflows/release.yml`):**
  - Triggers on `push` to `main`, tags `v*`, and `workflow_dispatch`.
  - Dynamically extracts latest semantic version from `CHANGELOG.md` (e.g. `1.4.0`).
  - Checks remote git tags: if `v1.4.0` is fresh, publishes `DeskOrbit v1.4.0` with tag `v1.4.0`; subsequent incremental commits automatically receive build-incremented tags `v1.4.0.<run_number>`.
  - Extracts formatted release notes directly from `CHANGELOG.md`.
  - Builds `DeskOrbit.app` on `macos-14` runner, injects `CFBundleShortVersionString` into `Info.plist`, builds compressed `.dmg` and `.zip`, computes SHA256 checksums, and publishes assets via `softprops/action-gh-release@v2`.

---

## 2026-10-13: Smart Lighting Subsystem Launch (v1.2.0)
- Introduced initial smart lighting support for Philips WiZ A60 bulbs via cloud REST API.
- Integrated native macOS `ColorPicker` alongside rapid preset swatches with live HEX preview and 200ms debouncing.
- Fixed continuous slider freezing with atomic command queues.
- Pushed in commit `2df2b25` and `37d20f6`.

---

## 2026-09-15: Battery & Power Subsystem & UI Redesign (v1.1.0)
- Integrated IOKit `AppleSmartBattery` for real-time power tracking.
- Calculated live input wattage (`IPDInputPower`), voltage, and current from USB-C/MagSafe power adapters.
- Computed maximum battery capacity against factory design capacity (`DesignCapacity` mAh).
- Redesigned menu bar popover into a 590px widescreen dual-column layout (controllers on left, power telemetry on right).
- Pushed in commit `4b71e89`.

---

## 2026-09-14: DeskOrbit Public Launch (v1.0.0)
- Implemented Apple Silicon DDC/CI brightness control via `IOAVService` over I²C bus `0x37`.
- Implemented GPU Gamma LUT scaling fallback via CoreGraphics `CGSetDisplayTransferByTable`.
- Implemented zero-latency CoreAudio HAL volume scalar control.
- Implemented Bluetooth peripheral battery monitoring and external disk safe ejection.
- Established CI/CD release automation and published project landing page.
- Pushed inaugural commit `26f7d99`.
