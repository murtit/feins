import SwiftUI

/// Was eine Geste auf dem runden Knopf bedeutet. Eigene Logik, damit sie ohne UI testbar ist.
enum AddDishGesture: Equatable {
    case type
    case speak
    case none

    /// Ab so vielen Punkten nach oben wird aus dem Wischen ein Einsprechen.
    static let speakThreshold: CGFloat = 70
    static let tapTolerance: CGFloat = 12

    static func intent(translation: CGSize, predictedEnd: CGSize) -> AddDishGesture {
        let upward = -min(translation.height, predictedEnd.height)
        if upward >= speakThreshold { return .speak }
        if abs(translation.width) <= tapTolerance, abs(translation.height) <= tapTolerance { return .type }
        return .none
    }

    /// 0 bis 1: wie weit der Knopf schon Richtung Einsprechen gezogen ist.
    static func progress(translation: CGFloat) -> CGFloat {
        min(max(-translation / speakThreshold, 0), 1)
    }
}

/// Runder Knopf unten rechts: antippen zum Eintippen, nach oben ziehen zum Einsprechen.
struct AddDishButton: View {
    @Binding var text: String
    var speech: SpeechRecognizer
    var onSubmit: () -> Void

    @State private var isTyping = false
    @State private var drag: CGFloat = 0
    @FocusState private var focused: Bool
    @Namespace private var glass

    private var progress: CGFloat { AddDishGesture.progress(translation: drag) }
    private var armed: Bool { progress >= 1 }
    private var canSubmit: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if let bubble = bubbleText {
                Text(bubble)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .capsule)
                    .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
                    .accessibilityIdentifier("addDish.bubble")
            }
            GlassEffectContainer(spacing: 12) {
                if isTyping {
                    typingBar
                } else {
                    HStack {
                        Spacer(minLength: 0)
                        circle
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isTyping)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: bubbleText)
        .sensoryFeedback(.impact(weight: .medium), trigger: armed) { _, isArmed in isArmed }
        .sensoryFeedback(.start, trigger: speech.isListening) { _, listening in listening }
    }

    private var bubbleText: String? {
        if let message = speech.message { return message }
        if speech.isListening { return speech.transcript.isEmpty ? "Ich höre zu …" : speech.transcript }
        if armed { return "Loslassen und Gericht sagen" }
        return nil
    }

    // MARK: Kreis

    private var circle: some View {
        let symbol: String = speech.isListening ? "waveform" : (progress > 0.5 ? "mic.fill" : "plus")
        let scale: CGFloat = 1 + progress * 0.08
        let lift: CGFloat = drag * 0.45
        return ZStack {
            Image(systemName: symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.variableColor.iterative, isActive: speech.isListening)
        }
        .frame(width: 64, height: 64)
        .background(Theme.accent, in: Circle())
        .overlay {
            if speech.isListening {
                Circle()
                    .stroke(Theme.accent.opacity(0.35), lineWidth: 6)
                    .scaleEffect(1.18)
                    .phaseAnimator([false, true]) { ring, pulse in
                        ring.scaleEffect(pulse ? 1.12 : 0.95).opacity(pulse ? 0.2 : 0.8)
                    } animation: { _ in .easeInOut(duration: 0.8) }
            }
        }
        .overlay(alignment: .top) { micHint }
        .glassEffect(.regular.interactive(), in: Circle())
        .glassEffectID("add", in: glass)
        .scaleEffect(scale)
        .offset(y: lift)
        .shadow(color: Theme.accent.opacity(0.35), radius: 12, y: 6)
        .contentShape(Circle())
        .gesture(gesture)
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(speech.isListening ? "Aufnahme beenden" : "Gericht hinzufügen")
        .accessibilityHint("Antippen zum Eintippen, nach oben ziehen zum Einsprechen.")
        .accessibilityIdentifier("addDish.button")
        .accessibilityAction { speech.isListening ? speech.stop() : startTyping() }
        .accessibilityAction(named: "Gericht einsprechen") { startSpeaking() }
    }

    /// Kleines Mikrofon über dem Kreis: zeigt, dass man nach oben ziehen kann.
    private var micHint: some View {
        let p: CGFloat = progress
        let iconColor: Color = armed ? Color.white : Theme.ink
        let fill: Color = armed ? Theme.accent : Theme.card
        let scale: CGFloat = 0.75 + p * 0.35
        let lift: CGFloat = -30 - p * 40
        let alpha: Double = speech.isListening ? 0 : Double(0.55 + p * 0.45)
        return Image(systemName: "mic.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(iconColor)
            .frame(width: 28, height: 28)
            .background(fill, in: Circle())
            .overlay(Circle().stroke(Theme.ink.opacity(0.08)))
            .scaleEffect(scale)
            .offset(y: lift)
            .opacity(alpha)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var gesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                guard !speech.isListening else { return }
                drag = min(0, value.translation.height)
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { drag = 0 }
                let intent = AddDishGesture.intent(translation: value.translation, predictedEnd: value.predictedEndTranslation)
                if speech.isListening {
                    if intent == .type { speech.stop() }
                    return
                }
                switch intent {
                case .type: startTyping()
                case .speak: startSpeaking()
                case .none: break
                }
            }
    }

    // MARK: Eintippen

    private var typingBar: some View {
        HStack(spacing: 10) {
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(Theme.ink)
                    .background(Theme.ink.opacity(0.07), in: Circle())
            }
            .accessibilityLabel("Schliessen")
            .accessibilityIdentifier("quickAdd.close")

            TextField("Was ist dir eingefallen?", text: $text)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(submit)
                .accessibilityIdentifier("quickAdd.field")

            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.white)
                    .background(canSubmit ? Theme.accent : Theme.muted.opacity(0.4), in: Circle())
            }
            .disabled(!canSubmit)
            .accessibilityLabel("Gericht speichern")
            .accessibilityIdentifier("quickAdd.submit")
        }
        .padding(6)
        .glassEffect(.regular, in: .capsule)
        .glassEffectID("add", in: glass)
        .onAppear { focused = true }
    }

    private func startTyping() {
        isTyping = true
    }

    private func startSpeaking() {
        isTyping = false
        Task { await speech.start() }
    }

    private func submit() {
        guard canSubmit else { return }
        onSubmit()
        close()
    }

    private func close() {
        focused = false
        isTyping = false
    }
}
