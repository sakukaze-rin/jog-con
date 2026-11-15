import Foundation

public struct KeyShortcut: Codable, Equatable {
    public var keyCode: UInt16
    public var label: String
    public var command: Bool
    public var shift: Bool
    public var option: Bool
    public var control: Bool
    public init(keyCode: UInt16, label: String, command: Bool = false, shift: Bool = false, option: Bool = false, control: Bool = false) {
        self.keyCode = keyCode; self.label = label; self.command = command
        self.shift = shift; self.option = option; self.control = control
    }
    public var display: String { (control ? "⌃" : "") + (option ? "⌥" : "") + (shift ? "⇧" : "") + (command ? "⌘" : "") + label }
}

public enum ButtonAction: String, Codable, CaseIterable {
    case custom, project, source, timeline, program, playPause, pause, forward, reverse, nextFrame, previousFrame, marker, markIn, markOut, undo, redo, addEdit, mcuPlay, mcuStop, mcuRewind, mcuFastForward
    public var title: String {
        switch self {
        case .custom: return "自定义快捷键"
        case .project: return "项目面板 · ⇧1"
        case .source: return "源监视器 · ⇧2"
        case .timeline: return "时间线 · ⇧3"
        case .program: return "节目监视器 · ⇧4"
        case .playPause: return "播放 / 暂停 · 空格"
        case .pause: return "停止播放 · K"
        case .forward: return "正放 / 加速 · L"
        case .reverse: return "倒放 / 加速 · J"
        case .nextFrame: return "下一帧 · →"
        case .previousFrame: return "上一帧 · ←"
        case .marker: return "添加标记 · M"
        case .markIn: return "标记入点 · I"
        case .markOut: return "标记出点 · O"
        case .undo: return "撤销 · ⌘Z"
        case .redo: return "重做 · ⇧⌘Z"
        case .addEdit: return "添加编辑点 · ⌘K"
        case .mcuPlay: return "控制面板 · MCU Play"
        case .mcuStop: return "控制面板 · MCU Stop"
        case .mcuRewind: return "控制面板 · MCU Rewind"
        case .mcuFastForward: return "控制面板 · MCU Fast Forward"
        }
    }
    public var shortcut: KeyShortcut? {
        switch self {
        case .project: return .init(keyCode: 18, label: "1", shift: true)
        case .source: return .init(keyCode: 19, label: "2", shift: true)
        case .timeline: return .init(keyCode: 20, label: "3", shift: true)
        case .program: return .init(keyCode: 21, label: "4", shift: true)
        case .playPause: return .init(keyCode: 49, label: "Space")
        case .pause: return .init(keyCode: 40, label: "K")
        case .forward: return .init(keyCode: 37, label: "L")
        case .reverse: return .init(keyCode: 38, label: "J")
        case .nextFrame: return .init(keyCode: 124, label: "→")
        case .previousFrame: return .init(keyCode: 123, label: "←")
        case .marker: return .init(keyCode: 46, label: "M")
        case .markIn: return .init(keyCode: 34, label: "I")
        case .markOut: return .init(keyCode: 31, label: "O")
        case .undo: return .init(keyCode: 6, label: "Z", command: true)
        case .redo: return .init(keyCode: 6, label: "Z", command: true, shift: true)
        case .addEdit: return .init(keyCode: 40, label: "K", command: true)
        default: return nil
        }
    }
    public var mcuNote: UInt8? {
        switch self {
        case .mcuPlay: return 0x5E
        case .mcuStop: return 0x5D
        case .mcuRewind: return 0x5B
        case .mcuFastForward: return 0x5C
        default: return nil
        }
    }
}

public struct ButtonMapping: Codable, Identifiable, Equatable {
    public var id: UUID
    public var input: String
    public var action: ButtonAction
    public var shortcut: KeyShortcut?
    public init(id: UUID = UUID(), input: String = "无", action: ButtonAction = .custom, shortcut: KeyShortcut? = nil) {
        self.id = id; self.input = input; self.action = action; self.shortcut = shortcut
    }
    public static func migrate(_ legacy: [String]) -> [ButtonMapping] {
        let actions: [ButtonAction] = [.project, .source, .timeline, .program, .mcuPlay, .mcuStop]
        return zip(legacy, actions).map { .init(input: $0.0, action: $0.1) }
    }
}
