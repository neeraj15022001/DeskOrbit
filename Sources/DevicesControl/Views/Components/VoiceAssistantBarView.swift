import SwiftUI

public struct VoiceAssistantBarView: View {
    @ObservedObject var assistant: VoiceAssistantService = .shared
    @ObservedObject var manager: DeviceManager = .shared

    public init() {}

    public var body: some View {
        HStack(spacing: 10) {
            // Siri / Mic Orb Button
            Button(action: {
                assistant.toggleListening(manager: manager)
            }) {
                ZStack {
                    Circle()
                        .fill(assistant.state == .listening ?
                            LinearGradient(colors: [Color.pink, Color.purple, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing) :
                            LinearGradient(colors: [Color.accentColor.opacity(0.8), Color.accentColor], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 30, height: 30)
                        .shadow(color: assistant.state == .listening ? Color.pink.opacity(0.6) : Color.clear, radius: 6)

                    Image(systemName: assistant.state == .listening ? "waveform" : "mic.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .help(assistant.state == .listening ? "Click to stop listening and execute" : "Click to speak voice command with Apple Foundation Model")

            // Real-time voice prompt or transcription
            VStack(alignment: .leading, spacing: 2) {
                if assistant.state == .listening {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 6, height: 6)

                        Text(assistant.liveTranscript.isEmpty ? "Listening... (say 'make light cyan' or 'volume 50%')" : assistant.liveTranscript)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                } else if assistant.state == .processing {
                    HStack(spacing: 5) {
                        ProgressView().controlSize(.mini)
                        Text("Processing with Apple Intelligence...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                } else if let feedback = assistant.lastFeedbackMessage {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 11))
                        Text(feedback)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Apple Intelligence Voice Assistant • Click mic or ask Siri")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if assistant.state == .listening {
                Button("Done") {
                    assistant.stopListening(executeAction: true, manager: manager)
                }
                .font(.system(size: 11, weight: .semibold))
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(assistant.state == .listening ? Color.pink.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
