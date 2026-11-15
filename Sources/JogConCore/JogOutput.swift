public enum JogOutput: Equatable {
    case none, frame(Int), midi(Int)
    public static func resolve(ticks: Int, continuous: Bool, audio: Bool, keyboardAvailable: Bool) -> JogOutput {
        guard ticks != 0 else { return .none }
        if continuous { return audio ? .none : .midi(ticks) }
        return keyboardAvailable ? .frame(ticks > 0 ? 1 : -1) : .midi(ticks)
    }
}
