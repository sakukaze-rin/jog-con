import XCTest
@testable import JogConCore

final class JogEngineTests: XCTestCase {
    func testHybridTapOnlyOnReleaseAndCancelOnDisable() {
        var engine = JogEngine()
        let settings = JogSettings(mode: .hybrid)
        func move(_ input: Double, enabled: Bool = true) -> Int {
            engine.advance(input: input, elapsed: 0.01, enabled: enabled, settings: settings)
        }
        XCTAssertEqual(move(1), 0)
        XCTAssertEqual(move(0), 0)
        for _ in 0..<15 { XCTAssertEqual(move(1), 0) }
        XCTAssertEqual(move(0), 1)
        XCTAssertEqual(move(0), 0)
        XCTAssertEqual(move(-0.5), 0)
        XCTAssertEqual(move(0), -1)
        XCTAssertEqual(move(0.3), 0)
        XCTAssertEqual(move(0), 0)
        XCTAssertEqual(move(1), 0)
        XCTAssertEqual(move(0, enabled: false), 0)
        XCTAssertEqual(move(0), 0)
    }
    func testHybridHoldWithoutExtraReleaseStep() {
        var engine = JogEngine()
        let settings = JogSettings(mode: .hybrid)
        func move(_ input: Double) -> Int {
            engine.advance(input: input, elapsed: 0.01, enabled: true, settings: settings)
        }
        _ = move(0)
        for _ in 0..<30 { XCTAssertEqual(move(1), 0) }
        XCTAssertEqual(move(1), 1)
        XCTAssertTrue(engine.isContinuous)
        var count = 0
        for _ in 0..<20 { count += move(1) }
        XCTAssertGreaterThan(count, 20)
        XCTAssertEqual(move(0), 0)
        XCTAssertFalse(engine.isContinuous)
        XCTAssertEqual(move(-1), 0)
        XCTAssertEqual(move(0), -1)
    }
    func testHybridHoldTimerResetsOnPartialPushAndReverse() {
        var engine = JogEngine()
        let settings = JogSettings(inverted: true, mode: .hybrid)
        func move(_ input: Double) -> Int {
            engine.advance(input: input, elapsed: 0.01, enabled: true, settings: settings)
        }
        _ = move(0)
        for _ in 0..<25 { XCTAssertEqual(move(1), 0) }
        XCTAssertEqual(move(0.7), 0)
        for _ in 0..<25 { XCTAssertEqual(move(1), 0) }
        for _ in 0..<30 { XCTAssertEqual(move(-1), 0) }
        XCTAssertEqual(move(-1), 1)
        XCTAssertEqual(move(0), 0)
    }
    func testSingleStepRequiresCenterAndDoesNotRepeatWhileHeld() {
        var engine = JogEngine()
        let settings = JogSettings(mode: .singleStep)
        func advance(_ input: Double) -> Int {
            engine.advance(input: input, elapsed: 1.0 / 120, enabled: true, settings: settings)
        }
        XCTAssertEqual(advance(1), 0)
        XCTAssertEqual(advance(0), 0)
        XCTAssertEqual(advance(0.44), 0)
        XCTAssertEqual(advance(0.45), 1)
        for _ in 0..<240 { XCTAssertEqual(advance(1), 0) }
        XCTAssertEqual(advance(0.2), 0)
        XCTAssertEqual(advance(-1), 0) // No second step until a sampled neutral state.
        XCTAssertEqual(advance(0.12), 0)
        XCTAssertEqual(advance(-0.45), -1)
        XCTAssertEqual(advance(-1), 0)
        XCTAssertEqual(advance(0), 0)
        XCTAssertEqual(advance(1), 1)
    }
    func testSingleStepInversionDisableAndTimingGap() {
        var engine = JogEngine()
        let settings = JogSettings(inverted: true, mode: .singleStep)
        func advance(_ input: Double, enabled: Bool = true, elapsed: Double = 0.01) -> Int {
            engine.advance(input: input, elapsed: elapsed, enabled: enabled, settings: settings)
        }
        XCTAssertEqual(advance(0), 0)
        XCTAssertEqual(advance(1), -1)
        XCTAssertEqual(advance(0, enabled: false), 0)
        XCTAssertEqual(advance(-1), 0)
        XCTAssertEqual(advance(0), 0)
        XCTAssertEqual(advance(-1), 1)
        XCTAssertEqual(advance(0, elapsed: 2), 0)
        XCTAssertEqual(advance(1), 0)
        XCTAssertEqual(advance(.nan), 0)
        XCTAssertFalse(engine.ready)
    }
    func testDeadzoneAndCurve() {
        let settings = JogSettings()
        XCTAssertEqual(settings.rate(for: 0.12), 0)
        XCTAssertEqual(settings.rate(for: -0.1), 0)
        XCTAssertEqual(settings.rate(for: 1), 120)
        XCTAssertEqual(settings.rate(for: -1), -120)
        XCTAssertEqual(settings.rate(for: 0.56), 30, accuracy: 0.0001)
        XCTAssertEqual(JogSettings(inverted: true).rate(for: 1), -120)
        XCTAssertEqual(settings.rate(for: .nan), 0)
    }
    func testMustCenterAndNoBacklogAfterPause() {
        var engine = JogEngine()
        XCTAssertEqual(engine.advance(input: 1, elapsed: 0.01, enabled: true, settings: .init()), 0)
        _ = engine.advance(input: 0, elapsed: 0.01, enabled: true, settings: .init())
        XCTAssertEqual(engine.advance(input: 1, elapsed: 0.05, enabled: true, settings: .init()), 6)
        XCTAssertEqual(engine.advance(input: 1, elapsed: 2, enabled: true, settings: .init()), 0)
        XCTAssertFalse(engine.ready)
        XCTAssertEqual(engine.advance(input: 1, elapsed: 0.01, enabled: true, settings: .init()), 0)
        _ = engine.advance(input: 0, elapsed: 0.01, enabled: true, settings: .init())
        _ = engine.advance(input: 0, elapsed: 0.01, enabled: false, settings: .init())
        XCTAssertFalse(engine.ready)
    }
    func testFractionalRateAndReverse() {
        var engine = JogEngine()
        let settings = JogSettings(deadzone: 0, exponent: 1, maximumRate: 10)
        _ = engine.advance(input: 0, elapsed: 0.01, enabled: true, settings: settings)
        var count = 0
        for _ in 0..<100 { count += engine.advance(input: 1, elapsed: 0.01, enabled: true, settings: settings) }
        XCTAssertTrue((9...10).contains(count)) // floating point accumulation may retain one fractional tick
        XCTAssertEqual(engine.advance(input: -1, elapsed: 0.01, enabled: true, settings: settings), 0)
    }
    func testContinuousSurvivesTimerDelaysWithoutBacklog() {
        for direction in [-1.0, 1.0] {
            var engine = JogEngine()
            var shuttle = ShuttleEngine()
            let settings = JogSettings(mode: .hybrid)
            _ = engine.advance(input: 0, elapsed: 0.01, enabled: true, settings: settings)
            for _ in 0..<32 { _ = engine.advance(input: direction, elapsed: 0.01, enabled: true, settings: settings) }
            XCTAssertTrue(engine.isContinuous)
            _ = shuttle.update(continuous: true, direction: Int(direction), allowed: true)
            for _ in 0..<100 {
                XCTAssertEqual(engine.advance(input: direction, elapsed: 0.25, enabled: true, settings: settings), 0)
                XCTAssertTrue(engine.ready)
                XCTAssertTrue(engine.isContinuous)
                XCTAssertEqual(shuttle.update(continuous: engine.isContinuous, direction: Int(direction), allowed: true, elapsed: 0.25), [])
                let tick = engine.advance(input: direction, elapsed: 0.01, enabled: true, settings: settings)
                XCTAssertEqual(tick.signum(), Int(direction))
            }
            XCTAssertEqual(engine.advance(input: 0, elapsed: 0.25, enabled: true, settings: settings), 0)
            XCTAssertFalse(engine.isContinuous)
            XCTAssertEqual(shuttle.update(continuous: false, direction: 0, allowed: true), [.stop])
        }
    }
    func testDelayDoesNotInventHoldOrLoseTap() {
        var engine = JogEngine()
        let settings = JogSettings(mode: .hybrid)
        _ = engine.advance(input: 0, elapsed: 0.01, enabled: true, settings: settings)
        _ = engine.advance(input: 1, elapsed: 0.01, enabled: true, settings: settings)
        XCTAssertEqual(engine.advance(input: 1, elapsed: 0.8, enabled: true, settings: settings), 0)
        XCTAssertFalse(engine.isContinuous)
        XCTAssertEqual(engine.advance(input: 0, elapsed: 0.01, enabled: true, settings: settings), 1)
        _ = engine.advance(input: 1, elapsed: 0.01, enabled: true, settings: settings)
        _ = engine.advance(input: 1, elapsed: 2, enabled: true, settings: settings)
        XCTAssertFalse(engine.ready)
        XCTAssertEqual(engine.advance(input: 0, elapsed: 0.01, enabled: true, settings: settings), 0)
    }
    func testMCUEncoding() {
        XCTAssertEqual(Mackie.jog(2), [[0xB0, 0x3C, 1], [0xB0, 0x3C, 1]])
        XCTAssertEqual(Mackie.jog(-1), [[0xB0, 0x3C, 0x41]])
        XCTAssertEqual(Mackie.jog(0), [])
        XCTAssertEqual(Mackie.jog(Int.min).count, 60)
        XCTAssertEqual(Mackie.play, [[0x90, 0x5E, 0x7F], [0x90, 0x5E, 0]])
        XCTAssertEqual(Mackie.stop, [[0x90, 0x5D, 0x7F], [0x90, 0x5D, 0]])
    }
}
