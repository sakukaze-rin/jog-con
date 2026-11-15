/// Emits one initial J/L, then one acceleration press per interval, capped by level.
public struct ShuttleEngine {
    public enum Command: Equatable { case stop, forward, reverse }
    public private(set) var direction = 0
    public private(set) var level = 0
    private var held: Double = 0
    public init() {}
    public mutating func update(continuous: Bool, direction requested: Int, allowed: Bool, elapsed: Double = 0, accelerate: Bool = true, interval: Double = 0.8, maximumLevel: Int = 4) -> [Command] {
        let desired = allowed && continuous ? (requested < 0 ? -1 : requested > 0 ? 1 : 0) : 0
        if desired == direction {
            guard desired != 0 else { return [] }
            guard accelerate, elapsed.isFinite, elapsed > 0, elapsed <= 0.1 else { held = 0; return [] }
            held += elapsed
            let delay = interval.isFinite ? max(0.2, interval) : 0.8
            if held + 1e-9 >= delay && level < min(5, max(1, maximumLevel)) {
                held = 0; level += 1
                return [desired > 0 ? .forward : .reverse]
            }
            return []
        }
        let wasPlaying = direction != 0
        direction = desired
        held = 0; level = desired == 0 ? 0 : 1
        if desired == 0 { return wasPlaying ? [.stop] : [] }
        return [.stop, desired > 0 ? .forward : .reverse]
    }
}
