import AppKit
import ApplicationServices
import JogConCore

enum PremiereBridge {
    private static let delivery = ShortcutDeliveryQueue { shortcut in
        prepareKey(shortcut)
    }
    static var diagnostic: String {
        let metrics = delivery.snapshot
        return String(format: "按键 %d · 排队 %d · 等待 %.0f ms / 峰值 %.0f ms · 释放超时 %.0f ms · %@", metrics.posted, metrics.waiting, metrics.lastWaitMS, metrics.maximumWaitMS, metrics.releaseDelayMS, metrics.status)
    }
    static var isFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier?.hasPrefix("com.adobe.PremierePro") == true
    }
    static var accessibilityGranted: Bool { AXIsProcessTrusted() }
    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    static func transportKey(_ key: CGKeyCode) -> Bool {
        return shortcut(.init(keyCode: key, label: key == 37 ? "L" : key == 38 ? "J" : "K"))
    }
    static func shortcut(_ shortcut: KeyShortcut) -> Bool {
        guard accessibilityGranted else { delivery.setStatus("缺少辅助功能权限（新版构建后请核对授权）"); return false }
        guard isFrontmost else { delivery.setStatus("未发送：Premiere 不在前台"); return false }
        delivery.enqueue(shortcut)
        return true
    }
    static func cancelTransportKeys() { delivery.cancelPending() }
    private static func prepareKey(_ shortcut: KeyShortcut) -> (() -> Void)? {
        guard isFrontmost, accessibilityGranted, let app = NSWorkspace.shared.frontmostApplication,
              let source = CGEventSource(stateID: .hidSystemState) else {
            delivery.setStatus("按键已取消：焦点或权限改变"); return nil
        }
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: shortcut.keyCode, keyDown: false) else {
            delivery.setStatus("无法建立键盘事件"); return nil
        }
        var flags: CGEventFlags = []
        if shortcut.command { flags.insert(.maskCommand) }; if shortcut.shift { flags.insert(.maskShift) }
        if shortcut.option { flags.insert(.maskAlternate) }; if shortcut.control { flags.insert(.maskControl) }
        down.flags = flags; up.flags = flags
        down.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
        down.post(tap: .cghidEventTap)
        return {
            // A focus change never prevents releasing the original app's key.
            if isFrontmost && NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier { up.post(tap: .cghidEventTap) }
            else { up.postToPid(app.processIdentifier) }
        }
    }
    static func focusPanel(index: Int) -> Bool {
        // Premiere's Adobe Default shortcuts: Shift+1/2/3/4. Custom layouts may differ.
        let keys: [CGKeyCode] = [18, 19, 20, 21]
        guard keys.indices.contains(index), isFrontmost, accessibilityGranted,
              let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: keys[index], keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keys[index], keyDown: false) else { return false }
        down.flags = .maskShift; up.flags = .maskShift
        down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap)
        return true
    }
}
