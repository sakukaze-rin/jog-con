import XCTest
@testable import JogConCore

final class ShuttleEngineTests: XCTestCase {
    func testAudioOffAlwaysRoutesContinuousTicksToMIDIAndShortTapToFrame() {
        XCTAssertEqual(JogOutput.resolve(ticks: 3, continuous: true, audio: false, keyboardAvailable: true), .midi(3))
        XCTAssertEqual(JogOutput.resolve(ticks: -3, continuous: true, audio: false, keyboardAvailable: false), .midi(-3))
        XCTAssertEqual(JogOutput.resolve(ticks: 3, continuous: true, audio: true, keyboardAvailable: true), .none)
        for audio in [true, false] {
            XCTAssertEqual(JogOutput.resolve(ticks: 1, continuous: false, audio: audio, keyboardAvailable: true), .frame(1))
            XCTAssertEqual(JogOutput.resolve(ticks: -1, continuous: false, audio: audio, keyboardAvailable: true), .frame(-1))
            XCTAssertEqual(JogOutput.resolve(ticks: 1, continuous: false, audio: audio, keyboardAvailable: false), .midi(1))
        }
    }
    func testTimedAccelerationCapsAndReversalRestartsAtFirstLevel() {
        var engine = ShuttleEngine()
        XCTAssertEqual(engine.update(continuous: true, direction: 1, allowed: true), [.stop, .forward])
        for level in 2...4 {
            for _ in 0..<9 { XCTAssertEqual(engine.update(continuous: true, direction: 1, allowed: true, elapsed: 0.1, interval: 1), []) }
            XCTAssertEqual(engine.update(continuous: true, direction: 1, allowed: true, elapsed: 0.1, interval: 1), [.forward])
            XCTAssertEqual(engine.level, level)
        }
        for _ in 0..<30 { XCTAssertEqual(engine.update(continuous: true, direction: 1, allowed: true, elapsed: 0.1, interval: 1), []) }
        XCTAssertEqual(engine.update(continuous: true, direction: -1, allowed: true), [.stop, .reverse])
        XCTAssertEqual(engine.level, 1)
        XCTAssertEqual(engine.update(continuous: false, direction: 0, allowed: true), [.stop])
        XCTAssertEqual(engine.level, 0)
    }
    func testAccelerationRequiresFullPushAndIgnoresTimingGaps() {
        var engine = ShuttleEngine()
        _ = engine.update(continuous: true, direction: -1, allowed: true)
        for _ in 0..<20 { XCTAssertEqual(engine.update(continuous: true, direction: -1, allowed: true, elapsed: 0.1, accelerate: false), []) }
        XCTAssertEqual(engine.level, 1)
        XCTAssertEqual(engine.update(continuous: true, direction: -1, allowed: true, elapsed: 10), [])
        for _ in 0..<7 { XCTAssertEqual(engine.update(continuous: true, direction: -1, allowed: true, elapsed: 0.1), []) }
        XCTAssertEqual(engine.update(continuous: true, direction: -1, allowed: true, elapsed: 0.1), [.reverse])
    }
    func testStartHoldReverseAndRelease() {
        var engine = ShuttleEngine()
        XCTAssertEqual(engine.update(continuous: false, direction: 1, allowed: true), [])
        XCTAssertEqual(engine.update(continuous: true, direction: 1, allowed: true), [.stop, .forward])
        for _ in 0..<240 { XCTAssertEqual(engine.update(continuous: true, direction: 1, allowed: true), []) }
        XCTAssertEqual(engine.update(continuous: true, direction: -1, allowed: true), [.stop, .reverse])
        XCTAssertEqual(engine.update(continuous: false, direction: 0, allowed: true), [.stop])
        XCTAssertEqual(engine.update(continuous: false, direction: 0, allowed: true), [])
    }
    func testFocusLossDisableAndMissingPermissionStopOnce() {
        var engine = ShuttleEngine()
        XCTAssertEqual(engine.update(continuous: true, direction: 1, allowed: false), [])
        _ = engine.update(continuous: true, direction: 1, allowed: true)
        XCTAssertEqual(engine.update(continuous: true, direction: 1, allowed: false), [.stop])
        XCTAssertEqual(engine.update(continuous: true, direction: 1, allowed: false), [])
        XCTAssertEqual(engine.direction, 0)
    }
}
