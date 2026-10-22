import Foundation
import Speech
import AVFoundation

public enum SpeechListeningState: Equatable {
    case idle
    case listening
    case processing
    case error(String)
}

public final class VoiceAssistantService: NSObject, ObservableObject, SFSpeechRecognizerDelegate, @unchecked Sendable {
    public static let shared = VoiceAssistantService()

    @Published public var state: SpeechListeningState = .idle
    @Published public var liveTranscript: String = ""
    @Published public var lastFeedbackMessage: String?
    @Published public var isAvailable: Bool = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let parser = OrbitNaturalLanguageParser.shared

    private var silenceTimer: Timer?

    public override init() {
        super.init()
        speechRecognizer?.delegate = self
        checkAvailability()
    }

    public func checkAvailability() {
        let auth = SFSpeechRecognizer.authorizationStatus()
        DispatchQueue.main.async {
            self.isAvailable = (auth == .authorized)
        }
    }

    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                let granted = (status == .authorized)
                self.isAvailable = granted
                completion(granted)
            }
        }
    }

    public func toggleListening(manager: DeviceManager = .shared) {
        if state == .listening {
            stopListening(executeAction: true, manager: manager)
        } else {
            startListening(manager: manager)
        }
    }

    public func startListening(manager: DeviceManager = .shared) {
        if state == .listening { return }

        // Cancel previous task if active
        recognitionTask?.cancel()
        recognitionTask = nil

        let auth = SFSpeechRecognizer.authorizationStatus()
        if auth != .authorized {
            requestAuthorization { [weak self] granted in
                if granted {
                    self?.startListening(manager: manager)
                } else {
                    self?.state = .error("Speech recognition permission denied.")
                }
            }
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            state = .error("Unable to create speech recognition request.")
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        // On-device Apple Foundation model speech recognition
        if speechRecognizer?.supportsOnDeviceRecognition == true {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            state = .error("Audio engine failed to start: \(error.localizedDescription)")
            return
        }

        state = .listening
        liveTranscript = ""
        lastFeedbackMessage = nil

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                DispatchQueue.main.async {
                    self.liveTranscript = result.bestTranscription.formattedString
                    self.resetSilenceTimer(manager: manager)
                }
            }

            if error != nil || (result?.isFinal == true) {
                self.stopListening(executeAction: true, manager: manager)
            }
        }
    }

    private func resetSilenceTimer(manager: DeviceManager) {
        silenceTimer?.invalidate()
        // Automatically finalize and execute when user stops speaking for 1.2s
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            self?.stopListening(executeAction: true, manager: manager)
        }
    }

    public func stopListening(executeAction: Bool = true, manager: DeviceManager = .shared) {
        silenceTimer?.invalidate()
        silenceTimer = nil

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        let query = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

        if executeAction && !query.isEmpty {
            state = .processing
            executeVoiceCommand(query: query, manager: manager)
        } else {
            state = .idle
        }
    }

    public func executeVoiceCommand(query: String, manager: DeviceManager = .shared) {
        Task {
            let result = await parser.parseAsync(query: query)

            await MainActor.run {
                switch result.action {
                case .setBulbPower(let isOn):
                    if let light = manager.smartLights.first {
                        manager.setLightPower(light: light, isOn: isOn)
                    }
                    manager.statusMessage = result.feedback

                case .setBulbBrightness(let percent):
                    if let light = manager.smartLights.first {
                        manager.setLightBrightness(light: light, brightness: percent)
                    }
                    manager.statusMessage = result.feedback

                case .setBulbColor(let red, let green, let blue, _):
                    if let light = manager.smartLights.first {
                        manager.setLightRGBColor(light: light, red: red, green: green, blue: blue)
                    }
                    manager.statusMessage = result.feedback

                case .setBulbTemperature(let kelvin):
                    if let light = manager.smartLights.first {
                        manager.setLightTemperature(light: light, kelvin: kelvin)
                    }
                    manager.statusMessage = result.feedback

                case .setBulbScene(let sceneId, _):
                    if let light = manager.smartLights.first {
                        manager.setLightScene(light: light, sceneId: sceneId)
                    }
                    manager.statusMessage = result.feedback

                case .setThematicPreset(let red, let green, let blue, let brightness, let kelvin, _):
                    if let light = manager.smartLights.first {
                        if let k = kelvin {
                            manager.setLightTemperature(light: light, kelvin: k)
                        } else {
                            manager.setLightRGBColor(light: light, red: red, green: green, blue: blue)
                        }
                        if brightness != light.brightness {
                            manager.setLightBrightness(light: light, brightness: brightness)
                        }
                    }
                    manager.statusMessage = result.feedback

                case .setAudioVolume(let percent, let deviceName):
                    let targetDev: AudioItem?
                    if let name = deviceName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                        targetDev = manager.audioDevices.first(where: {
                            !$0.isInput && ($0.name.lowercased() == name || $0.name.lowercased().contains(name) || name.contains($0.name.lowercased()))
                        }) ?? manager.defaultAudioOutput ?? manager.audioDevices.first(where: { !$0.isInput })
                    } else {
                        targetDev = manager.defaultAudioOutput ?? manager.audioDevices.first(where: { !$0.isInput })
                    }

                    if let dev = targetDev {
                        manager.setAudioVolume(deviceID: dev.id, volume: Float(percent) / 100.0)
                        manager.statusMessage = "Set \(dev.name) volume to \(percent)%"
                    } else {
                        manager.statusMessage = result.feedback
                    }

                case .setAudioMute(let isMuted, let deviceName):
                    let targetDev: AudioItem?
                    if let name = deviceName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                        targetDev = manager.audioDevices.first(where: {
                            !$0.isInput && ($0.name.lowercased() == name || $0.name.lowercased().contains(name) || name.contains($0.name.lowercased()))
                        }) ?? manager.defaultAudioOutput ?? manager.audioDevices.first(where: { !$0.isInput })
                    } else {
                        targetDev = manager.defaultAudioOutput ?? manager.audioDevices.first(where: { !$0.isInput })
                    }

                    if let dev = targetDev {
                        if dev.isMuted != isMuted {
                            manager.toggleAudioMute(device: dev)
                        }
                        manager.statusMessage = "\(isMuted ? "Muted" : "Unmuted") \(dev.name)"
                    } else {
                        manager.statusMessage = result.feedback
                    }

                case .setDisplayBrightness(let percent, let displayName):
                    let targetDisp: DisplayItem?
                    if let name = displayName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                        targetDisp = manager.displays.first(where: {
                            $0.name.lowercased() == name || $0.name.lowercased().contains(name) || name.contains($0.name.lowercased())
                        }) ?? manager.mainDisplay ?? manager.displays.first
                    } else {
                        targetDisp = manager.mainDisplay ?? manager.displays.first
                    }

                    if let disp = targetDisp {
                        manager.setDisplayBrightness(displayID: disp.id, brightness: Float(percent) / 100.0)
                        manager.statusMessage = "Set \(disp.name) brightness to \(percent)%"
                    } else {
                        manager.statusMessage = result.feedback
                    }

                case .unknown:
                    manager.statusMessage = result.feedback
                }

                self.lastFeedbackMessage = result.feedback
                self.state = .idle

                // Clear status message after 4 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    if manager.statusMessage == result.feedback {
                        manager.statusMessage = nil
                    }
                }
            }
        }
    }

    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            self.isAvailable = available
        }
    }
}
