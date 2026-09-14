import Foundation
import AppKit
import CoreGraphics
import IOKit

// Dynamic C function signatures for Apple DisplayServices
private typealias DisplayServicesGetBrightnessFunc = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
private typealias DisplayServicesSetBrightnessFunc = @convention(c) (CGDirectDisplayID, Float) -> Int32

// Dynamic C function signatures for Apple Silicon DDC/CI (IOAVService) - as used in MonitorControl (Arm64DDC)
private typealias IOAVServiceCreateFunc = @convention(c) (CFAllocator?) -> UnsafeMutableRawPointer?
private typealias IOAVServiceCreateWithServiceFunc = @convention(c) (CFAllocator?, io_service_t) -> UnsafeMutableRawPointer?
private typealias IOAVServiceWriteI2CFunc = @convention(c) (UnsafeMutableRawPointer?, UInt32, UInt32, UnsafePointer<UInt8>?, UInt32) -> Int32

public final class DisplayService: @unchecked Sendable {
    // Dynamic symbols
    private var getBrightnessPtr: DisplayServicesGetBrightnessFunc?
    private var setBrightnessPtr: DisplayServicesSetBrightnessFunc?
    private var ioavCreatePtr: IOAVServiceCreateFunc?
    private var ioavCreateWithServicePtr: IOAVServiceCreateWithServiceFunc?
    private var ioavWriteI2CPtr: IOAVServiceWriteI2CFunc?

    // Active services & cache
    private var avServices: [UnsafeMutableRawPointer] = []
    private var softwareBrightnessMap: [UInt32: Float] = [:]
    private var overlayWindows: [UInt32: NSWindow] = [:]
    private var screenObserver: NSObjectProtocol?

    public init() {
        loadDynamicSymbols()
        discoverAVServices()
        setupScreenObserver()
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        restoreGamma()
        DispatchQueue.main.async { [overlayWindows] in
            for (_, window) in overlayWindows {
                window.orderOut(nil)
                window.close()
            }
        }
    }

    private func loadDynamicSymbols() {
        // 1. DisplayServices (for Apple internal/Studio displays)
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY) {
            if let getSym = dlsym(handle, "DisplayServicesGetBrightness") {
                getBrightnessPtr = unsafeBitCast(getSym, to: DisplayServicesGetBrightnessFunc.self)
            }
            if let setSym = dlsym(handle, "DisplayServicesSetBrightness") {
                setBrightnessPtr = unsafeBitCast(setSym, to: DisplayServicesSetBrightnessFunc.self)
            }
        }

        // 2. IOAVService (MonitorControl Apple Silicon DDC/CI)
        let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        if let createSym = dlsym(defaultHandle, "IOAVServiceCreate") {
            ioavCreatePtr = unsafeBitCast(createSym, to: IOAVServiceCreateFunc.self)
        }
        if let createWithServiceSym = dlsym(defaultHandle, "IOAVServiceCreateWithService") {
            ioavCreateWithServicePtr = unsafeBitCast(createWithServiceSym, to: IOAVServiceCreateWithServiceFunc.self)
        }
        if let writeI2CSym = dlsym(defaultHandle, "IOAVServiceWriteI2C") {
            ioavWriteI2CPtr = unsafeBitCast(writeI2CSym, to: IOAVServiceWriteI2CFunc.self)
        }
    }

    private func discoverAVServices() {
        avServices.removeAll()

        // Discover through IOKit DCPAVServiceProxy as in MonitorControl
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("DCPAVServiceProxy")
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess {
            var serviceEntry = IOIteratorNext(iterator)
            while serviceEntry != 0 {
                if let createWithService = ioavCreateWithServicePtr,
                   let avService = createWithService(kCFAllocatorDefault, serviceEntry) {
                    avServices.append(avService)
                }
                IOObjectRelease(serviceEntry)
                serviceEntry = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }

        // Fallback to default IOAVServiceCreate if no proxy matched
        if avServices.isEmpty, let create = ioavCreatePtr, let defaultService = create(kCFAllocatorDefault) {
            avServices.append(defaultService)
        }
    }

    private func setupScreenObserver() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.discoverAVServices()
            self?.repositionOverlays()
        }
    }

    private func repositionOverlays() {
        for (displayID, window) in overlayWindows {
            if let screen = findScreen(for: displayID) {
                window.setFrame(screen.frame, display: true)
            } else {
                window.orderOut(nil)
                overlayWindows.removeValue(forKey: displayID)
            }
        }
    }

    public func fetchDisplays() -> [DisplayItem] {
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0

        let result = CGGetActiveDisplayList(16, &activeDisplays, &displayCount)
        guard result == .success, displayCount > 0 else {
            return []
        }

        let screens = NSScreen.screens

        return (0..<Int(displayCount)).compactMap { index -> DisplayItem? in
            let displayID = activeDisplays[index]
            let isMain = CGDisplayIsMain(displayID) != 0
            let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0

            let matchingScreen = screens.first { screen in
                if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                    return num.uint32Value == displayID
                }
                return false
            }

            var displayName = matchingScreen?.localizedName ?? (isBuiltIn ? "Built-in Retina Display" : "External Display \(index + 1)")
            if displayName.isEmpty {
                displayName = "Display \(index + 1)"
            }

            let width = CGDisplayPixelsWide(displayID)
            let height = CGDisplayPixelsHigh(displayID)
            let resolution = "\(width) × \(height)"

            let brightness = getBrightness(for: displayID)

            return DisplayItem(
                id: displayID,
                name: displayName,
                isMain: isMain,
                isBuiltIn: isBuiltIn,
                brightness: brightness,
                resolution: resolution
            )
        }
    }

    public func getBrightness(for displayID: UInt32) -> Float {
        let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0

        if isBuiltIn, let getFunc = getBrightnessPtr {
            var val: Float = 0.5
            let res = getFunc(displayID, &val)
            if res == 0 {
                return max(0.0, min(1.0, val))
            }
        }

        return softwareBrightnessMap[displayID] ?? 1.0
    }

    public func setBrightness(for displayID: UInt32, brightness: Float) {
        let clamped = max(0.0, min(1.0, brightness))
        softwareBrightnessMap[displayID] = clamped

        let isBuiltIn = CGDisplayIsBuiltin(displayID) != 0

        if isBuiltIn {
            // Built-in screen: Apple native backlight
            if let setFunc = setBrightnessPtr {
                _ = setFunc(displayID, clamped)
            }
            return
        }

        // External Display: Implement MonitorControl's multi-protocol strategy
        
        // Protocol 1: DDC/CI hardware command via IOAVService (Arm64DDC)
        writeDDCBrightness(brightness: clamped)

        // Protocol 2: Gamma Table manipulation (MonitorControl's primary software dimming)
        setGammaBrightness(displayID: displayID, brightness: clamped)

        // Protocol 3: Software overlay shading (MonitorControl's shade dimming)
        updateSoftwareOverlay(for: displayID, brightness: clamped)

        // Protocol 4: DisplayServices fallback (for Apple Studio Display / LG UltraFine)
        if let setFunc = setBrightnessPtr {
            _ = setFunc(displayID, clamped)
        }
    }

    // MARK: - MonitorControl Protocol 1: DDC/CI (Apple Silicon IOAVService)
    private func writeDDCBrightness(brightness: Float) {
        guard let writeFunc = ioavWriteI2CPtr, !avServices.isEmpty else { return }

        // VCP 0x10 is Luminance / Brightness (range 0–100)
        let intVal = UInt8(max(0, min(100, Int(round(brightness * 100.0)))))

        // Standard DDC/CI packet format:
        // [length | 0x80, command (0x03 = Set VCP), opcode (0x10 = Brightness), highByte, lowByte, checksum]
        var data = [UInt8](repeating: 0, count: 6)
        data[0] = 0x84
        data[1] = 0x03
        data[2] = 0x10 // VCP Luminance
        data[3] = 0x00 // High byte
        data[4] = intVal // Low byte
        // DDC/CI XOR checksum including destination address (0x6E) and source (0x51)
        data[5] = 0x6E ^ 0x51 ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4]

        for service in avServices {
            _ = writeFunc(service, 0x37, 0x51, data, 6)
        }
    }

    // MARK: - MonitorControl Protocol 2: Gamma Table Dimming
    private func setGammaBrightness(displayID: CGDirectDisplayID, brightness: Float) {
        let clamped = max(0.0, min(1.0, brightness))

        // 1. Formula method
        CGSetDisplayTransferByFormula(
            displayID,
            0.0, clamped, 1.0,
            0.0, clamped, 1.0,
            0.0, clamped, 1.0
        )

        // 2. Table-based method
        var redTable = [CGGammaValue](repeating: 0, count: 256)
        var greenTable = [CGGammaValue](repeating: 0, count: 256)
        var blueTable = [CGGammaValue](repeating: 0, count: 256)

        for i in 0..<256 {
            let normalized = Float(i) / 255.0
            let dimmed = normalized * clamped
            redTable[i] = dimmed
            greenTable[i] = dimmed
            blueTable[i] = dimmed
        }

        CGSetDisplayTransferByTable(displayID, 256, &redTable, &greenTable, &blueTable)
    }

    private func restoreGamma() {
        CGDisplayRestoreColorSyncSettings()
    }

    // MARK: - MonitorControl Protocol 3: Software Overlay Shading
    private func updateSoftwareOverlay(for displayID: UInt32, brightness: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let clamped = max(0.0, min(1.0, brightness))
            let alpha = CGFloat(1.0 - clamped)

            // If 100% brightness, remove overlay
            if alpha <= 0.001 {
                if let window = self.overlayWindows[displayID] {
                    window.orderOut(nil)
                }
                return
            }

            guard let targetScreen = self.findScreen(for: displayID) else { return }

            let window: NSWindow
            if let existing = self.overlayWindows[displayID] {
                window = existing
                window.setFrame(targetScreen.frame, display: true)
            } else {
                let newWindow = NSWindow(
                    contentRect: targetScreen.frame,
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false,
                    screen: targetScreen
                )
                newWindow.level = .screenSaver
                newWindow.ignoresMouseEvents = true
                newWindow.isOpaque = false
                newWindow.hasShadow = false
                newWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
                self.overlayWindows[displayID] = newWindow
                window = newWindow
            }

            window.backgroundColor = NSColor.black.withAlphaComponent(alpha)
            window.orderFrontRegardless()
        }
    }

    private func findScreen(for displayID: UInt32) -> NSScreen? {
        return NSScreen.screens.first { screen in
            if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                return num.uint32Value == displayID
            }
            return false
        }
    }
}
