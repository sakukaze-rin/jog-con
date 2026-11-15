import Foundation

/// Serializes key pairs independently of UI work. The delivery closure presses
/// a key and returns its matching release, which is never cancelled.
public final class ShortcutDeliveryQueue {
    public struct Metrics {
        public fileprivate(set) var posted = 0
        public fileprivate(set) var waiting = 0
        public fileprivate(set) var lastWaitMS = 0.0
        public fileprivate(set) var maximumWaitMS = 0.0
        public fileprivate(set) var releaseDelayMS = 0.0
        public fileprivate(set) var status = "尚未发送按键"
    }
    private struct Pending {
        let shortcut: KeyShortcut
        let enqueued: TimeInterval
    }
    private let queue = DispatchQueue(label: "dev.jog-con.keys", qos: .userInteractive)
    private let lock = NSLock()
    private var metrics = Metrics()
    private var pending: [Pending] = []
    private var busy = false
    private let pressDuration: TimeInterval
    private let gapDuration: TimeInterval
    private let deliver: (KeyShortcut) -> (() -> Void)?
    public init(pressDuration: TimeInterval = 0.04, gapDuration: TimeInterval = 0.008, deliver: @escaping (KeyShortcut) -> (() -> Void)?) {
        self.pressDuration = pressDuration
        self.gapDuration = gapDuration
        self.deliver = deliver
    }
    public var snapshot: Metrics {
        lock.lock(); defer { lock.unlock() }
        return metrics
    }
    public func setStatus(_ status: String) {
        lock.lock(); metrics.status = status; lock.unlock()
    }
    public func enqueue(_ shortcut: KeyShortcut) {
        let item = Pending(shortcut: shortcut, enqueued: ProcessInfo.processInfo.systemUptime)
        queue.async {
            self.pending.append(item)
            self.updateDepth()
            self.drain()
        }
    }
    public func cancelPending() {
        queue.async {
            self.pending.removeAll()
            self.updateDepth()
        }
    }
    private func updateDepth() {
        lock.lock(); metrics.waiting = pending.count; lock.unlock()
    }
    private func drain() {
        guard !busy, !pending.isEmpty else { return }
        let item = pending.removeFirst()
        updateDepth()
        guard let release = deliver(item.shortcut) else {
            pending.removeAll(); updateDepth()
            return
        }
        busy = true
        let posted = ProcessInfo.processInfo.systemUptime
        lock.lock()
        metrics.lastWaitMS = (posted - item.enqueued) * 1000
        metrics.maximumWaitMS = max(metrics.maximumWaitMS, metrics.lastWaitMS)
        lock.unlock()
        queue.asyncAfter(deadline: .now() + pressDuration) {
            release()
            self.lock.lock()
            self.metrics.posted += 1
            self.metrics.releaseDelayMS = max(0, (ProcessInfo.processInfo.systemUptime - posted - self.pressDuration) * 1000)
            self.metrics.status = "已投递 " + item.shortcut.display + "（未确认 Premiere 执行）"
            self.lock.unlock()
            self.queue.asyncAfter(deadline: .now() + self.gapDuration) {
                self.busy = false
                self.drain()
            }
        }
    }
}
