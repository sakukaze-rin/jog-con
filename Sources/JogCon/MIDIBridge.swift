import Foundation
import CoreMIDI

final class MIDIBridge {
    private var client: MIDIClientRef = 0
    private var source: MIDIEndpointRef = 0
    private var destination: MIDIEndpointRef = 0
    private var initialized = false
    static let inputID: MIDIUniqueID = 0x4A430101
    static let outputID: MIDIUniqueID = 0x4A430102
    private(set) var identity = ""
    private(set) var receivedPackets = 0
    private(set) var status = "未初始化"
    var available: Bool { initialized }
    init() {
        var result = MIDIClientCreateWithBlock("Jog-con" as CFString, &client, nil)
        guard result == noErr else { status = "MIDI client: \(result)"; return }
        result = MIDISourceCreate(client, "Jog-con Input" as CFString, &source)
        guard result == noErr else { status = "MIDI source: \(result)"; return }
        result = MIDIDestinationCreateWithBlock(client, "Jog-con Output" as CFString, &destination) { [weak self] _, _ in
            DispatchQueue.main.async { self?.receivedPackets += 1 }
        }
        guard result == noErr else { status = "MIDI destination: \(result)"; return }
        for (endpoint, identifier) in [(source, Self.inputID), (destination, Self.outputID)] {
            result = MIDIObjectSetIntegerProperty(endpoint, kMIDIPropertyUniqueID, identifier)
            var actual: Int32 = 0
            let readResult = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &actual)
            guard result == noErr, readResult == noErr, actual == identifier else {
                status = "MIDI 固定 ID 失败：\(result)/\(readResult)。请退出其他 Jog-con 实例后重开。"
                return
            }
            MIDIObjectSetStringProperty(endpoint, kMIDIPropertyManufacturer, "Jog-con" as CFString)
            MIDIObjectSetStringProperty(endpoint, kMIDIPropertyModel, "Jog-con MCU" as CFString)
        }
        identity = "Input ID \(Self.inputID) · Output ID \(Self.outputID)"
        initialized = true
        status = "虚拟 MIDI 端口已就绪"
    }
    @discardableResult func send(_ messages: [[UInt8]]) -> Bool {
        guard available else { return false }
        for message in messages {
            var list = MIDIPacketList()
            let result: OSStatus = withUnsafeMutablePointer(to: &list) { pointer in
                let first = MIDIPacketListInit(pointer)
                return message.withUnsafeBufferPointer { bytes in
                    guard let base = bytes.baseAddress, bytes.count == 3 else { return -1 }
                    MIDIPacketListAdd(pointer, MemoryLayout<MIDIPacketList>.size, first, 0, bytes.count, base)
                    return MIDIReceived(source, pointer)
                }
            }
            if result != noErr { status = "MIDI send: \(result)"; return false }
        }
        return true
    }
    /// Verifies virtual source publication and byte delivery without touching Premiere.
    func loopbackCheck() -> Bool {
        guard available else { return false }
        let lock = NSLock()
        var received: [[UInt8]] = []
        var port: MIDIPortRef = 0
        guard MIDIInputPortCreateWithBlock(client, "Jog-con diagnostic" as CFString, &port, { list, _ in
            let bytes = withUnsafeBytes(of: list.pointee.packet.data) { Array($0.prefix(Int(list.pointee.packet.length))) }
            lock.lock(); received.append(bytes); lock.unlock()
        }) == noErr else { return false }
        defer { MIDIPortDisconnectSource(port, source); MIDIPortDispose(port) }
        guard MIDIPortConnectSource(port, source, nil) == noErr else { return false }
        let expected: [[UInt8]] = [[0xB0, 0x3C, 0x01], [0xB0, 0x3C, 0x41]]
        guard send(expected) else { return false }
        let deadline = Date().addingTimeInterval(1)
        repeat {
            lock.lock(); let matched = received == expected; lock.unlock()
            if matched { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        } while Date() < deadline
        return false
    }
    deinit {
        if source != 0 { MIDIEndpointDispose(source) }
        if destination != 0 { MIDIEndpointDispose(destination) }
        if client != 0 { MIDIClientDispose(client) }
    }
}
