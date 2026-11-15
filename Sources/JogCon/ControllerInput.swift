import Foundation
import GameController

final class ControllerInput {
    private(set) var controller: GCController?
    private var observers: [NSObjectProtocol] = []
    var onInputChange: (() -> Void)?
    var onConnectionChange: (() -> Void)?
    init() {
        GCController.shouldMonitorBackgroundEvents = true
        for name in [Notification.Name.GCControllerDidConnect, .GCControllerDidDisconnect] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.refresh() })
        }
        refresh()
    }
    func refresh() {
        controller?.physicalInputProfile.valueDidChangeHandler = nil
        // Never bind an unrelated controller automatically.
        controller = GCController.controllers().first { controller in
            let name = (controller.vendorName ?? "").lowercased()
            return name.contains("joy-con (l)") || name.contains("joy-con l") || name.contains("joy-con (l/r)")
        }
        controller?.handlerQueue = .main
        controller?.physicalInputProfile.valueDidChangeHandler = { [weak self] _, _ in self?.onInputChange?() }
        onConnectionChange?()
    }
    static let stickPressBinding = "jogcon::stickPress"
    // Single Joy-Con profiles can use the generic alias instead of Left Thumbstick.
    private var stickPress: GCControllerButtonInput? {
        guard let controller else { return nil }
        let profile = controller.physicalInputProfile
        if #available(macOS 26.0, *), let button = profile.buttons[__GCInputButtonName.thumbstickButton.rawValue] { return button }
        if let button = profile.buttons[GCInputLeftThumbstickButton] { return button }
        if let button = controller.extendedGamepad?.leftThumbstickButton { return button }
        return profile.allButtons.first { button in
            button.aliases.contains { alias in
                let name = alias.lowercased()
                return name.contains("thumbstick") && name.contains("button") && !name.contains("right")
            }
        }
    }
    var hasStickPress: Bool { stickPress != nil }
    static func title(for binding: String) -> String {
        binding == stickPressBinding ? "按下摇杆（L3）" : binding
    }
    var pads: [String] { controller?.physicalInputProfile.dpads.keys.sorted() ?? [] }
    var buttons: [String] { controller?.physicalInputProfile.buttons.keys.sorted() ?? [] }
    func axis(pad: String, vertical: Bool) -> Double {
        guard let value = controller?.physicalInputProfile.dpads[pad] else { return 0 }
        return Double(vertical ? value.yAxis.value : value.xAxis.value)
    }
    func pressed(_ binding: String) -> Bool {
        if binding == Self.stickPressBinding { return stickPress?.isPressed ?? false }
        guard let profile = controller?.physicalInputProfile else { return false }
        let parts = binding.components(separatedBy: "::")
        if parts.count == 2, let pad = profile.dpads[parts[0]] {
            switch parts[1] {
            case "up": return pad.up.isPressed
            case "down": return pad.down.isPressed
            case "left": return pad.left.isPressed
            case "right": return pad.right.isPressed
            default: return false
            }
        }
        return profile.buttons[binding]?.isPressed ?? false
    }
    var bindings: [String] {
        ["无"] + (hasStickPress ? [Self.stickPressBinding] : []) + buttons + pads.flatMap { pad in ["up", "down", "left", "right"].map { "\(pad)::\($0)" } }
    }
    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }
}
