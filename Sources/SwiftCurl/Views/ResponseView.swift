import AppKit
import AVFoundation
import SwiftUI

struct ResponseView: View {
    let response: ResponseRecord?
    let isSending: Bool
    @State private var selectedTab = ResponseTab.body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Response")
                    .font(.headline)

                Spacer()

                if let response, response.errorMessage == nil, !response.bodyData.isEmpty {
                    Button {
                        saveResponse(response)
                    } label: {
                        Label("Save Response", systemImage: "square.and.arrow.down")
                    }
                }

                if isSending {
                    ProgressView()
                        .controlSize(.small)
                } else if let response {
                    Text(statusText(response))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(response.errorMessage == nil ? Color.secondary : Color.red)
                }
            }
            .padding()

            Divider()

            VStack(spacing: 0) {
                Picker("Response View", selection: $selectedTab) {
                    ForEach(ResponseTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)
                .padding(.vertical, 8)

                Divider()

                responseContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var responseContent: some View {
        if let response {
            if let error = response.errorMessage {
                ResponseMessageView(
                    title: "Request Failed",
                    message: error,
                    systemImage: "exclamationmark.triangle"
                )
            } else {
                switch selectedTab {
                case .body:
                    if response.isAudio {
                        AudioResponseView(response: response)
                    } else {
                        ResponseBodyTextView(text: response.body.isEmpty ? "No response body" : response.body)
                            .overlay(alignment: .topTrailing) {
                                Text(ByteCountFormatter.string(fromByteCount: Int64(response.bodyByteCount), countStyle: .file))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(8)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                                    .padding(10)
                            }
                    }
                case .headers:
                    List(response.headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        VStack(alignment: .leading) {
                            Text(key)
                                .font(.headline)
                            Text(value)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        } else {
            ResponseMessageView(
                title: "No Response Yet",
                message: "Send a request to inspect status, headers, and body.",
                systemImage: "paperplane"
            )
        }
    }

    private func statusText(_ response: ResponseRecord) -> String {
        let code = response.statusCode.map(String.init) ?? "Error"
        return "\(code) / \(Int(response.duration * 1000)) ms"
    }

    private func saveResponse(_ response: ResponseRecord) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "response.\(response.suggestedFileExtension)"
        panel.canCreateDirectories = true

        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }

            do {
                try response.bodyData.write(to: url, options: [.atomic])
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}

private struct ResponseMessageView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title3.weight(.semibold))

            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(28)
    }
}

private enum ResponseTab: String, CaseIterable, Identifiable {
    case body
    case headers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .body: "Body"
        case .headers: "Headers"
        }
    }
}

private struct AudioResponseView: View {
    let response: ResponseRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Audio Response")
                        .font(.headline)

                    Text("\(response.contentType ?? "audio") · \(ByteCountFormatter.string(fromByteCount: Int64(response.bodyByteCount), countStyle: .file))")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            AudioPlayerControls(data: response.bodyData)

            Text("Use Save Response to write the original audio bytes to disk.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct AudioPlayerControls: View {
    @State private var model: AudioPlaybackModel

    init(data: Data) {
        _model = State(initialValue: AudioPlaybackModel(data: data))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    model.togglePlayback()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())

                Text(model.elapsedText)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 54, alignment: .trailing)

                Slider(
                    value: Binding(
                        get: { model.currentTime },
                        set: { model.seek(to: $0) }
                    ),
                    in: 0...max(model.duration, 0.1)
                )

                Text(model.durationText)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 54, alignment: .leading)
            }

            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.secondary)

                Slider(value: $model.volume, in: 0...1)
                    .frame(maxWidth: 180)

                Spacer()
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator)
        }
        .frame(maxWidth: 720)
        .onDisappear {
            model.pause()
        }
    }
}

@Observable
private final class AudioPlaybackModel {
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var isPlaying = false
    var volume: Float = 1 {
        didSet { player?.volume = volume }
    }

    private var player: AVAudioPlayer?
    private var timer: Timer?

    init(data: Data) {
        do {
            player = try AVAudioPlayer(data: data)
            player?.prepareToPlay()
            player?.volume = volume
            duration = player?.duration ?? 0
        } catch {
            player = nil
        }
    }

    deinit {
        timer?.invalidate()
    }

    var elapsedText: String {
        formatTime(currentTime)
    }

    var durationText: String {
        formatTime(duration)
    }

    func togglePlayback() {
        guard let player else { return }

        if player.isPlaying {
            pause()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func seek(to time: TimeInterval) {
        currentTime = min(max(time, 0), duration)
        player?.currentTime = currentTime
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPlaybackState()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func refreshPlaybackState() {
        guard let player else { return }
        currentTime = player.currentTime

        if !player.isPlaying {
            isPlaying = false
            stopTimer()
        }
    }

    private func formatTime(_ value: TimeInterval) -> String {
        guard value.isFinite else { return "00:00" }
        let totalSeconds = Int(value.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct ResponseBodyTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.drawsBackground = false
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = .textColor
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.string = text

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
}
