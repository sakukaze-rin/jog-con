import AppKit
import SwiftUI
import JogConCore

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: KeyShortcut?
    func makeNSView(context: Context) -> RecorderButton {
        let view = RecorderButton(); view.onRecord = { shortcut = $0 }; return view
    }
    func updateNSView(_ view: RecorderButton, context: Context) {
        view.recordedTitle = shortcut?.display ?? "录制快捷键…"
        view.onRecord = { shortcut = $0 }
        if !view.recording { view.title = view.recordedTitle }
    }
}

final class RecorderButton: NSButton {
    var onRecord: ((KeyShortcut) -> Void)?
    var recordedTitle = "录制快捷键…"
    var recording = false
    private var monitor: Any?
    override var acceptsFirstResponder: Bool { true }
    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded; title = recordedTitle; target = self; action = #selector(beginRecording)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func beginRecording() {
        stopRecording(); window?.makeFirstResponder(self)
        recording = true; title = "请按组合键（Esc 取消）"
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            guard self.window?.isKeyWindow == true, self.window?.firstResponder === self else { self.stopRecording(); return event }
            if event.keyCode == 53 { self.stopRecording(); return nil }
            guard !event.isARepeat else { return nil }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let special: [UInt16: String] = [49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 117: "Forward Delete", 123: "←", 124: "→", 125: "↓", 126: "↑"]
            let shortcut = KeyShortcut(keyCode: event.keyCode, label: special[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)", command: flags.contains(.command), shift: flags.contains(.shift), option: flags.contains(.option), control: flags.contains(.control))
            self.stopRecording(); self.onRecord?(shortcut); return nil
        }
    }
    private func stopRecording() {
        if let monitor = monitor { NSEvent.removeMonitor(monitor) }; monitor = nil
        recording = false; title = recordedTitle
    }
    override func resignFirstResponder() -> Bool { stopRecording(); return super.resignFirstResponder() }
    deinit { if let monitor = monitor { NSEvent.removeMonitor(monitor) } }
}
