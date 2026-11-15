import XCTest
@testable import JogConCore

final class ShortcutDeliveryQueueTests: XCTestCase {
    private final class Events {
        private let lock = NSLock()
        private var entries: [String] = []
        func add(_ value: String) { lock.lock(); entries.append(value); lock.unlock() }
        var values: [String] { lock.lock(); defer { lock.unlock() }; return entries }
    }
    func testRapidTogglesKeepPressReleaseOrderWhileCallingThreadWaits() {
        let events = Events()
        let completed = DispatchSemaphore(value: 0)
        let queue = ShortcutDeliveryQueue { shortcut in
            events.add("down " + shortcut.label)
            return {
                events.add("up " + shortcut.label)
                completed.signal()
            }
        }
        for label in ["1", "2", "3"] { queue.enqueue(.init(keyCode: 49, label: label)) }
        // Blocking the caller must not block delivery, unlike a main-queue timer.
        for _ in 0..<3 { XCTAssertEqual(completed.wait(timeout: .now() + 2), .success) }
        XCTAssertEqual(events.values, ["down 1", "up 1", "down 2", "up 2", "down 3", "up 3"])
        XCTAssertLessThan(queue.snapshot.maximumWaitMS, 500)
    }
    func testStopCancelsPendingButPreservesInFlightRelease() {
        let events = Events()
        let started = DispatchSemaphore(value: 0)
        let stopped = expectation(description: "stop released")
        let queue = ShortcutDeliveryQueue { shortcut in
            events.add("down " + shortcut.label)
            started.signal()
            return {
                events.add("up " + shortcut.label)
                if shortcut.label == "K" { stopped.fulfill() }
            }
        }
        queue.enqueue(.init(keyCode: 37, label: "L"))
        XCTAssertEqual(started.wait(timeout: .now() + 2), .success)
        queue.enqueue(.init(keyCode: 37, label: "obsolete L"))
        queue.cancelPending()
        queue.enqueue(.init(keyCode: 40, label: "K"))
        wait(for: [stopped], timeout: 2)
        XCTAssertEqual(events.values, ["down L", "up L", "down K", "up K"])
    }
    func testUnavailableTargetDiscardsPendingKeys() {
        let attempted = expectation(description: "delivery rejected")
        let queue = ShortcutDeliveryQueue { _ in attempted.fulfill(); return nil }
        queue.enqueue(.init(keyCode: 49, label: "Space"))
        wait(for: [attempted], timeout: 2)
        XCTAssertEqual(queue.snapshot.posted, 0)
    }
}
