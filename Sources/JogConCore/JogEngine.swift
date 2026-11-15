import Foundation

public enum JogMode: String, CaseIterable {
    case hybrid
    case continuous
    case singleStep
}

public struct JogSettings: Equatable {
    public var mode: JogMode
    public var stepThreshold: Double
    public var holdThreshold: Double
    public var holdDelay: Double
    public var deadzone: Double
    public var exponent: Double
    public var maximumRate: Double
    public var inverted: Bool
    public init(deadzone: Double = 0.12, exponent: Double = 2, maximumRate: Double = 120, inverted: Bool = false, mode: JogMode = .continuous, stepThreshold: Double = 0.45, holdThreshold: Double = 0.85, holdDelay: Double = 0.30) {
        self.mode = mode; self.stepThreshold = stepThreshold
        self.holdThreshold = holdThreshold; self.holdDelay = holdDelay
        self.deadzone = deadzone; self.exponent = exponent
        self.maximumRate = maximumRate; self.inverted = inverted
    }
    public func rate(for input: Double) -> Double {
        guard input.isFinite, deadzone.isFinite, exponent.isFinite, maximumRate.isFinite else { return 0 }
        let dz = min(0.95, max(0, deadzone))
        let magnitude = min(1, abs(input))
        guard magnitude > dz else { return 0 }
        let sign = (input < 0 ? -1.0 : 1.0) * (inverted ? -1 : 1)
        return sign * pow((magnitude - dz) / (1 - dz), max(0.1, exponent)) * min(600, max(1, maximumRate))
    }
}

/// Accumulates fractional detents. Disabled states discard backlog; direction changes discard residue.
public struct JogEngine {
    private var remainder: Double = 0
    private var previousSign: Double = 0
    private var stepLatched = false
    private var pendingStep = 0
    private var holdTime: Double = 0
    private var holdDirection = 0
    public private(set) var isContinuous = false
    public private(set) var ready = false
    public init() {}
    public mutating func reset() {
        remainder = 0; previousSign = 0; ready = false; stepLatched = false
        pendingStep = 0; holdTime = 0; holdDirection = 0; isContinuous = false
    }
    public mutating func advance(input: Double, elapsed: Double, enabled: Bool, settings: JogSettings) -> Int {
        guard enabled, input.isFinite, elapsed.isFinite, elapsed > 0, elapsed <= 1 else { reset(); return 0 }
        // Delayed UI timers preserve gestures without replaying missed pulses
        // or counting unobserved time toward long-hold activation.
        let sampleElapsed = elapsed <= 0.1 ? elapsed : 0
        if settings.mode == .hybrid {
            guard settings.deadzone.isFinite, settings.stepThreshold.isFinite, settings.holdThreshold.isFinite, settings.holdDelay.isFinite else { reset(); return 0 }
            let deadzone = min(0.95, max(0, settings.deadzone))
            let stepThreshold = min(1, max(deadzone + 0.01, settings.stepThreshold))
            let holdThreshold = min(1, max(stepThreshold, settings.holdThreshold))
            let delay = min(2, max(0.1, settings.holdDelay))
            if abs(input) <= deadzone {
                let step = ready && !isContinuous ? pendingStep : 0
                pendingStep = 0; holdTime = 0; holdDirection = 0; isContinuous = false
                remainder = 0; previousSign = 0; ready = true
                return step
            }
            guard ready else { return 0 }
            let direction = (input < 0 ? -1 : 1) * (settings.inverted ? -1 : 1)
            if !isContinuous {
                if abs(input) >= stepThreshold { pendingStep = direction }
                if abs(input) >= holdThreshold {
                    if holdDirection == direction { holdTime += sampleElapsed }
                    else { holdDirection = direction; holdTime = 0 }
                } else { holdDirection = 0; holdTime = 0 }
                guard holdTime + 1e-9 >= delay else { return 0 }
                isContinuous = true; pendingStep = 0
                previousSign = Double(direction); remainder = 0
                return direction // Start immediately; no extra step on release.
            }
        }
        if settings.mode == .singleStep {
            guard settings.deadzone.isFinite, settings.stepThreshold.isFinite else { reset(); return 0 }
            let deadzone = min(0.95, max(0, settings.deadzone))
            let threshold = min(1, max(deadzone + 0.01, settings.stepThreshold))
            if abs(input) <= deadzone {
                ready = true; stepLatched = false; remainder = 0; previousSign = 0
                return 0
            }
            guard ready, !stepLatched, abs(input) >= threshold else { return 0 }
            stepLatched = true
            return (input < 0 ? -1 : 1) * (settings.inverted ? -1 : 1)
        }
        let rate = settings.rate(for: input)
        if rate == 0 { ready = true; remainder = 0; previousSign = 0; return 0 }
        guard ready else { return 0 } // Require centering after arming, focus change, or disconnect.
        let sign = rate < 0 ? -1.0 : 1.0
        if sign != previousSign { remainder = 0 }
        previousSign = sign
        remainder += rate * sampleElapsed
        let ticks = Int(remainder.rounded(.towardZero))
        remainder -= Double(ticks)
        return ticks
    }
}

public enum Mackie {
    /// CC 0x3C (decimal 60), sign/magnitude relative: clockwise 01, counterclockwise 41.
    public static func jog(_ ticks: Int) -> [[UInt8]] {
        guard ticks != 0 else { return [] }
        return Array(repeating: [0xB0, 0x3C, ticks < 0 ? 0x41 : 0x01], count: Int(min(60, ticks.magnitude)))
    }
    public static func button(note: UInt8) -> [[UInt8]] {
        [[0x90, note & 0x7F, 0x7F], [0x90, note & 0x7F, 0x00]]
    }
    public static var play: [[UInt8]] { button(note: 0x5E) }
    public static var stop: [[UInt8]] { button(note: 0x5D) }
}
