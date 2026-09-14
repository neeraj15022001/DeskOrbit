import Foundation
import AppKit

public final class StorageService: @unchecked Sendable {
    public var onStorageChanged: (() -> Void)?

    private var observers: [NSObjectProtocol] = []

    public init() {
        setupObservers()
    }

    deinit {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func setupObservers() {
        let center = NSWorkspace.shared.notificationCenter

        let mountObs = center.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onStorageChanged?()
        }

        let unmountObs = center.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onStorageChanged?()
        }

        observers = [mountObs, unmountObs]
    }

    public func fetchStorageDevices() -> [StorageItem] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsInternalKey
        ]

        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else {
            return []
        }

        return urls.compactMap { url -> StorageItem? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else {
                return nil
            }

            let isInternal = values.volumeIsInternal ?? true
            let isRemovable = values.volumeIsRemovable ?? false
            let isEjectable = values.volumeIsEjectable ?? false

            // Include external or ejectable disks
            guard !isInternal || isRemovable || isEjectable else {
                return nil
            }

            let name = values.volumeName ?? url.lastPathComponent
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = Int64(values.volumeAvailableCapacity ?? 0)

            return StorageItem(
                id: url.path,
                name: name,
                mountPoint: url,
                totalBytes: total,
                freeBytes: free,
                isRemovable: isRemovable,
                isEjectable: isEjectable
            )
        }
    }

    public func ejectVolume(at url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
