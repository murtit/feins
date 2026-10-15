import AVFoundation
import Observation
import Speech

/// Spracheingabe auf dem Gerät (Apple Speech Framework). Erkennt Schweizer Hochdeutsch, sonst Deutsch.
@MainActor
@Observable
final class SpeechRecognizer {
    enum State: Equatable {
        case idle
        case requesting
        case listening
        case denied
        case unavailable(String)
    }

    private(set) var transcript = ""
    private(set) var state: State = .idle

    @ObservationIgnored private var audioEngine: AVAudioEngine?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-CH"))
        ?? SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))

    var isListening: Bool { state == .listening }

    var message: String? {
        switch state {
        case .denied: "Bitte erlaube Mikrofon und Spracherkennung in den Einstellungen."
        case .unavailable(let reason): reason
        default: nil
        }
    }

    func toggle() async {
        if isListening || state == .requesting {
            stop()
        } else {
            await start()
        }
    }

    func start() async {
        transcript = ""
        state = .requesting
        guard await Self.authorize() else {
            state = .denied
            return
        }
        guard state == .requesting else { return }
        guard let recognizer, recognizer.isAvailable else {
            state = .unavailable("Spracherkennung ist gerade nicht verfügbar.")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.addsPunctuation = false
            if recognizer.supportsOnDeviceRecognition {
                request.requiresOnDeviceRecognition = true
            }

            let engine = AVAudioEngine()
            let input = engine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0), block: Self.tapBlock(for: request))
            engine.prepare()
            try engine.start()

            audioEngine = engine
            self.request = request
            task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler(for: self))
            state = .listening
        } catch {
            AppLog.speech.error("Audio-Start fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
            stop()
            state = .unavailable("Das Mikrofon konnte nicht gestartet werden.")
        }
    }

    func stop() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        request?.endAudio()
        request = nil
        task?.finish()
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if state == .listening || state == .requesting {
            state = .idle
        }
    }

    fileprivate func receive(text: String?, isFinal: Bool, failed: Bool) {
        if let text, !text.isEmpty { transcript = text }
        if isFinal || failed { stop() }
    }

    // Die Audio- und Erkennungs-Callbacks laufen auf Hintergrund-Threads, darum werden sie
    // ausserhalb des MainActors gebaut und springen erst für UI-Updates zurück.
    nonisolated private static func tapBlock(for request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in request.append(buffer) }
    }

    nonisolated private static func resultHandler(for recognizer: SpeechRecognizer) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak recognizer] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let failed = error != nil
            Task { @MainActor in
                recognizer?.receive(text: text, isFinal: isFinal, failed: failed)
            }
        }
    }

    nonisolated private static func authorize() async -> Bool {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}
