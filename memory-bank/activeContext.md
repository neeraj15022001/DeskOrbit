# Active Context: DeskOrbit

## Current State & Recent Milestones
DeskOrbit has reached version **v1.4.0**, achieving full local-first autonomy by transitioning all smart lighting controls from cloud APIs to direct WiZ v2 signed UDP local network control.

### Live Hardware Verification (Completed)
- **Target Bulb:** Philips WiZ A60 Smart Bulb.
- **MAC Address:** `9877d5e9d336`.
- **IP Address:** `192.168.1.6:38899`.
- **Home ID:** `21840859`.
- **Signing Key:** `f1890f8362f76dc92dda2e76ff9e916c`.
- **Verification Result:** Physical bulb verified responding live to power toggles, brightness dimming, 16M RGB color changes, and dynamic scenes over authenticated UDP with `{"success": true}` responses.

---

## Recent Critical Architecture Decisions

### 1. Total Severance of Samsung SmartThings Cloud Integration
- **Rationale:** Samsung SmartThings REST API introduced network latency (300ms–1500ms), required personal access tokens, and imposed strict rate limits that froze slider interactions.
- **Action:** Completely purged all SmartThings endpoints, token storage, and UI elements. DeskOrbit is now 100% private, local-first, and zero-cloud.

### 2. WiZ v2 HMAC-SHA256 Signing & Dynamic Timestamp Sync
- **Discovery:** WiZ firmware &ge;1.38.0 silently drops or rejects standard unauthenticated `setPilot` packets.
- **Solution:** DeskOrbit extracts the 16-byte `udp_signing_key` from home structure configuration exports, alphabetically sorts JSON payload keys, tracks the bulb's monotonic 32-bit counter (`ts`), and attaches an HMAC-SHA256 base64 envelope (`env`) to every command.

### 3. Darwin BSD Socket `sin_len` Alignment
- **Discovery:** On macOS Darwin kernels, calling POSIX `sendto()` with an uninitialized `sin_len` field in `struct sockaddr_in` caused silent UDP packet drops.
- **Solution:** Explicitly set `sin_len = UInt8(MemoryLayout<sockaddr_in>.size)` across all unicast and broadcast socket transmissions.

### 4. Automatic Dashboard Presentation on Launch
- **UX Improvement:** DeskOrbit now auto-presents and focuses the full Home-style Dashboard window on launch, while maintaining its lightweight menu bar presence. Clicking the Dock or Spotlight icon also brings the Dashboard to the front.

---

## Active Focus & Next Steps
1. **Multi-Bulb Sync:** Expand signed UDP broadcast commands to synchronize color and power states across all bulbs in a room simultaneously.
2. **Periodic State Polling:** Implement low-frequency background UDP polling (every 10s) to keep DeskOrbit in sync when bulbs are adjusted via physical wall switches or the WiZ mobile app.
3. **Release Packaging:** Update automated GitHub Release tag to `v1.4.0` with the latest universal `.dmg`.
