import AVFoundation
import Combine

/// Reads text aloud with the system speech synthesizer and reports when an utterance finishes.
public final class PDFPageSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published public private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    private var onFinish: (() -> Void)?

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Speaks `text`, replacing anything currently being spoken. `onFinish` runs only if speech completes (not when stopped).
    public func speak(_ text: String, onFinish: (() -> Void)? = nil) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        currentUtterance = utterance
        self.onFinish = onFinish
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    public func stop() {
        currentUtterance = nil
        onFinish = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.currentUtterance === utterance else { return }
            self.currentUtterance = nil
            self.isSpeaking = false
            let onFinish = self.onFinish
            self.onFinish = nil
            onFinish?()
        }
    }
}
