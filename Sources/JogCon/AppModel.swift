import AppKit
import Combine
import JogConCore

final class AppModel: ObservableObject {
    @Published var armed = false { didSet { updateActivity(); resetGesture() } }
    @Published var audioShuttle = UserDefaults.standard.object(forKey: "audioShuttle") as? Bool ?? true { didSet { save(); resetGesture() } }
    let mode = JogMode.hybrid
    @Published var holdThreshold = UserDefaults.standard.object(forKey: "holdThreshold") as? Double ?? 0.85 { didSet { save(); resetGesture() } }
    @Published var holdDelay = UserDefaults.standard.object(forKey: "holdDelay") as? Double ?? 0.30 { didSet { save(); resetGesture() } }
    @Published var stepThreshold = UserDefaults.standard.object(forKey: "stepThreshold") as? Double ?? 0.45 { didSet { save(); resetGesture() } }
    @Published var deadzone = UserDefaults.standard.object(forKey: "deadzone") as? Double ?? 0.12 { didSet { save(); resetGesture() } }
    @Published var exponent = UserDefaults.standard.object(forKey: "exponent") as? Double ?? 2 { didSet { save() } }
    @Published var maximumRate = UserDefaults.standard.object(forKey: "maximumRate") as? Double ?? 120 { didSet { save() } }
    @Published var inverted = UserDefaults.standard.bool(forKey: "inverted") { didSet { save(); resetGesture() } }
    @Published var vertical = UserDefaults.standard.bool(forKey: "vertical") { didSet { save(); resetGesture() } }
    @Published var selectedPad = UserDefaults.standard.string(forKey: "selectedPad") ?? "" { didSet { save(); resetGesture() } }
    @Published var buttonMappings: [ButtonMapping] = [] { didSet { save(); resetGesture() } }
    @Published var accelerationInterval = UserDefaults.standard.object(forKey: "accelerationInterval") as? Double ?? 0.8 { didSet { save(); resetGesture() } }
    @Published var playbackLevel = 0
    @Published var learningID: UUID?
    @Published var axis: Double = 0
    @Published var sentCount = 0
    @Published var status = "输出默认关闭；请先确认输入映射。"
    @Published var deviceName = "未检测到 Joy-Con (L)"
    @Published var padNames: [String] = []
    @Published var bindingNames: [String] = ["无"]
    @Published var inputDescription = "等待手柄"
    @Published var keyboardDiagnostic = ""
    let input = ControllerInput()
    let midi = MIDIBridge()
    private var engine = JogEngine()
    private var shuttle = ShuttleEngine()
    private var terminationObserver: NSObjectProtocol?
    private var timer: Timer?
    private var activity: NSObjectProtocol?
    private var lastDisplayTime: TimeInterval = 0
    private var maximumPollGap: TimeInterval = 0
    private var midiCount = 0
    private var lastTime = ProcessInfo.processInfo.systemUptime
    private var previouslyPressed = Set<String>()
    private var wasAllowed = false
    init() {
        if let data = UserDefaults.standard.data(forKey: "buttonMappingsV1"), let decoded = try? JSONDecoder().decode([ButtonMapping].self, from: data) {
            buttonMappings = decoded
        } else {
            buttonMappings = ButtonMapping.migrate(UserDefaults.standard.stringArray(forKey: "mappings") ?? Array(repeating: "无", count: 6))
        }
        input.onInputChange = { [weak self] in self?.tick() }
        input.onConnectionChange = { [weak self] in self?.refreshDevice() }
        refreshDevice()
        terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in self?.resetGesture() }
        timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
    }
    var settings: JogSettings { JogSettings(deadzone: deadzone, exponent: exponent, maximumRate: maximumRate, inverted: inverted, mode: mode, stepThreshold: stepThreshold, holdThreshold: holdThreshold, holdDelay: holdDelay) }
    var rate: Double { settings.rate(for: axis) }
    var midiStatus: String { midi.status }
    var midiIdentity: String { midi.identity }
    var hasController: Bool { input.controller != nil }
    func refreshDevice() {
        armed = false; previouslyPressed.removeAll()
        deviceName = input.controller?.vendorName ?? "未检测到 Joy-Con (L)"
        padNames = input.pads; bindingNames = input.bindings
        if !padNames.contains(selectedPad) { selectedPad = padNames.first(where: { $0.lowercased().contains("thumbstick") }) ?? padNames.first ?? "" }
        status = hasController ? "手柄已连接，请观察输入并确认轴和按键。" : "请唤醒 Joy-Con (L)，再点击重新检测。"
    }
    func rescan() { input.refresh() }
    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(audioShuttle, forKey: "audioShuttle")
        defaults.set(mode.rawValue, forKey: "jogMode"); defaults.set(stepThreshold, forKey: "stepThreshold")
        defaults.set(holdThreshold, forKey: "holdThreshold"); defaults.set(holdDelay, forKey: "holdDelay")
        defaults.set(deadzone, forKey: "deadzone"); defaults.set(exponent, forKey: "exponent")
        defaults.set(maximumRate, forKey: "maximumRate"); defaults.set(inverted, forKey: "inverted")
        defaults.set(vertical, forKey: "vertical"); defaults.set(selectedPad, forKey: "selectedPad")
        defaults.set(accelerationInterval, forKey: "accelerationInterval")
        if let data = try? JSONEncoder().encode(buttonMappings) { defaults.set(data, forKey: "buttonMappingsV1") }
    }
    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastTime; lastTime = now
        let axis = input.axis(pad: selectedPad, vertical: vertical)
        maximumPollGap = max(maximumPollGap, elapsed)
        if now - lastDisplayTime >= 1.0 / 30 {
            lastDisplayTime = now
            if self.axis != axis { self.axis = axis }
            let diagnostic = "辅助功能：" + (PremiereBridge.accessibilityGranted ? "已授权" : "未授权") + " · " + PremiereBridge.diagnostic + " · 轮询峰值 " + String(Int(maximumPollGap * 1000)) + " ms"
            if keyboardDiagnostic != diagnostic { keyboardDiagnostic = diagnostic }
            if sentCount != midiCount { sentCount = midiCount }
        }
        let pressed = Set(bindingNames.filter { input.pressed($0) })
        let description = pressed.isEmpty ? "无按键按下" : pressed.sorted().joined(separator: ", ")
        if inputDescription != description { inputDescription = description }
        let newlyPressed = pressed.subtracting(previouslyPressed)
        let learnedInput = newlyPressed.contains(ControllerInput.stickPressBinding) ? ControllerInput.stickPressBinding : newlyPressed.sorted().first
        if let id = learningID, let name = learnedInput, let index = buttonMappings.firstIndex(where: { $0.id == id }) {
            buttonMappings[index].input = name; learningID = nil
            previouslyPressed = pressed
            status = "已学习按钮：\(name)"
        }
        let allowed = armed && learningID == nil && hasController && padNames.contains(selectedPad) && PremiereBridge.isFrontmost
        if !allowed { engine.reset() }
        if allowed && !wasAllowed { previouslyPressed = pressed }
        wasAllowed = allowed
        let ticks = engine.advance(input: axis, elapsed: elapsed, enabled: allowed, settings: settings)
        if audioShuttle {
            let direction = settings.rate(for: axis) < 0 ? -1 : 1
            let commands = shuttle.update(continuous: engine.isContinuous, direction: direction, allowed: allowed && PremiereBridge.accessibilityGranted, elapsed: elapsed, accelerate: abs(axis) >= holdThreshold, interval: accelerationInterval)
            for command in commands {
                if !sendTransport(command) {
                    resetGesture(); status = "有声长推发送失败；请授权辅助功能并将焦点放在 Premiere 时间线。"
                    break
                }
            }
            if allowed && engine.isContinuous && !PremiereBridge.accessibilityGranted {
                status = "有声长推需要辅助功能权限；请点击授权按钮并在系统设置中允许 Jog-con。"
            }
        }
        if playbackLevel != shuttle.level { playbackLevel = shuttle.level }
        switch JogOutput.resolve(ticks: ticks, continuous: engine.isContinuous, audio: audioShuttle, keyboardAvailable: PremiereBridge.accessibilityGranted) {
            case .frame(let direction):
                // Explicit frame commands avoid relying on the MCU Jog interpretation.
                _ = PremiereBridge.transportKey(40)
                let action: ButtonAction = direction > 0 ? .nextFrame : .previousFrame
                if let shortcut = action.shortcut, PremiereBridge.shortcut(shortcut) { status = "短推：已发送\(action.title)" }
            case .midi(let count):
                let messages = Mackie.jog(count)
                if midi.send(messages) {
                    midiCount += messages.count
                    let message = engine.isContinuous ? "连续 MIDI Jog；回中停止" : "短推：发送 1 个 MIDI Jog"
                    if status != message { status = message }
                } else { status = "MIDI 不可用：\(midi.status)" }
            case .none: break
        }
        if allowed {
            // The first mapping for a physical button wins; never fire conflicting actions.
            var handled = Set<String>()
            for mapping in buttonMappings where mapping.input != "无" && pressed.contains(mapping.input) && !previouslyPressed.contains(mapping.input) {
                if handled.insert(mapping.input).inserted { perform(mapping) }
            }
        }
        previouslyPressed = pressed
        if armed {
            if !PremiereBridge.isFrontmost { if status != "等待 Premiere 位于前台（输出暂停）" { status = "等待 Premiere 位于前台（输出暂停）" } }
            else if !engine.ready { if status != "请松开摇杆回中，再开始控制" { status = "请松开摇杆回中，再开始控制" } }
        }
    }
    @discardableResult private func sendTransport(_ command: ShuttleEngine.Command) -> Bool {
        switch command {
        case .stop:
            PremiereBridge.cancelTransportKeys()
            // MIDI stop is also sent on focus loss, without typing into another app.
            let stopped = midi.send(Mackie.stop)
            if stopped { midiCount += Mackie.stop.count }
            let keyed = PremiereBridge.transportKey(40) // K
            return stopped || keyed
        case .forward, .reverse:
            let sent = PremiereBridge.transportKey(command == .forward ? 37 : 38) // L / J
            if sent { status = command == .forward ? "有声正放：持续到底自动加速" : "有声倒放：持续到底自动加速" }
            return sent
        }
    }
    func learn(_ id: UUID) {
        armed = false; learningID = id
        status = "请按一下要映射的实体按钮"
    }
    private func perform(_ mapping: ButtonMapping) {
        resetGesture()
        if let note = mapping.action.mcuNote {
            let messages = Mackie.button(note: note)
            if midi.send(messages) { midiCount += messages.count; status = "已发送 \(mapping.action.title)" }
            else { status = midi.status }
        } else if let shortcut = mapping.action == .custom ? mapping.shortcut : mapping.action.shortcut {
            status = PremiereBridge.shortcut(shortcut) ? "已发送 \(shortcut.display)" : "快捷键需要辅助功能权限和 Premiere 前台"
        } else { status = "请先录制快捷键" }
    }
    private func resetGesture() {
        for command in shuttle.update(continuous: false, direction: 0, allowed: false) { _ = sendTransport(command) }
        engine.reset(); playbackLevel = 0
    }
    private func updateActivity() {
        if let activity { ProcessInfo.processInfo.endActivity(activity); self.activity = nil }
        if armed {
            maximumPollGap = 0
            lastTime = ProcessInfo.processInfo.systemUptime
            activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Joy-Con timeline control")
        }
    }
    deinit {
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
        timer?.invalidate()
        if let observer = terminationObserver { NotificationCenter.default.removeObserver(observer) }
    }
}
