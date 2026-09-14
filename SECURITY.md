# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Security Considerations

DeskOrbit interfaces directly with low-level macOS subsystems:
* **Audio:** `CoreAudio` HAL hardware properties
* **Display:** `IOAVService` DDC/CI I2C channels and CoreGraphics gamma tables
* **Bluetooth:** `IOBluetooth` and IOKit power source registries
* **Storage:** `DiskArbitration` and `NSWorkspace` unmounting hooks

DeskOrbit does not collect telemetry, make outbound network requests, or transmit any device identifiers or telemetry to external servers.

## Reporting a Vulnerability

If you discover a potential security issue or vulnerability in DeskOrbit:
1. Please **do not** report security vulnerabilities through public GitHub issues.
2. Open a private GitHub Security Advisory in the repository, or contact the maintainers directly.
3. Include details of the macOS version, hardware architecture (Apple Silicon / Intel), and steps to reproduce.
4. We will acknowledge receipt within 48 hours and work on a prompt patch.
