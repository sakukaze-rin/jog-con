import SwiftUI
import GameController
import JogConCore

@main
struct JogConApp: App {
    @StateObject private var model = AppModel()
    init() {
        if CommandLine.arguments.contains("--diagnose") {
            // CLI diagnostics run the loop for asynchronous GameController discovery.
            GCController.shouldMonitorBackgroundEvents = true
            RunLoop.current.run(until: Date().addingTimeInterval(2))
            let controllers = GCController.controllers().map { controller -> [String: Any] in
                let profile = controller.physicalInputProfile
                return ["name": controller.vendorName ?? "unknown", "category": controller.productCategory,
                        "pads": profile.dpads.keys.sorted(), "buttons": profile.buttons.keys.sorted()]
            }
            let bridge = MIDIBridge()
            let diagnostics: [String: Any] = ["controllers": controllers, "midi": bridge.status,
                "midiIdentity": bridge.identity,
                "midiLoopbackPassed": bridge.loopbackCheck(), "premiereFrontmost": PremiereBridge.isFrontmost,
                "accessibilityGranted": PremiereBridge.accessibilityGranted]
            if let data = try? JSONSerialization.data(withJSONObject: diagnostics, options: [.prettyPrinted, .sortedKeys]), let text = String(data: data, encoding: .utf8) { print(text) }
            exit(0)
        }
    }
    var body: some Scene {
        WindowGroup("Jog-con") { ContentView(model: model) }
            .defaultSize(width: 690, height: 800)
    }
}

struct ContentView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Jog-con").font(.largeTitle.bold())
                        Text("JOY-CON → PREMIERE PRO").font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("启用输出", isOn: $model.armed).toggleStyle(.switch).disabled(!model.hasController)
                }
                GroupBox("连接") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Image(systemName: "gamecontroller"); Text(model.deviceName); Spacer(); Button("重新检测") { model.rescan() } }
                        Text(model.midiStatus).font(.caption)
                        Text(model.midiIdentity).font(.caption.monospaced()).textSelection(.enabled)
                        Text("Premiere Mackie 输入：Jog-con Input ｜ 输出：Jog-con Output").font(.caption).textSelection(.enabled)
                    }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("摇杆 · 相对 Jog") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("短推一步 · 长推连续").font(.headline)
                        Toggle("有声长推（J/L 播放，K 停止）", isOn: $model.audioShuttle)
                        if model.audioShuttle {
                            Text("长推先以 1× 播放，持续到底按间隔逐级加速，最多 4 档；回中停止。需辅助功能权限及 Premiere 默认快捷键，请将焦点放在时间线。").font(.caption).foregroundStyle(.secondary)
                        }
                        Picker("输入控件", selection: $model.selectedPad) {
                            if model.padNames.isEmpty { Text("等待手柄").tag("") }
                            ForEach(model.padNames, id: \.self) { Text($0).tag($0) }
                        }
                        HStack {
                            Picker("轴", selection: $model.vertical) { Text("X 左右").tag(false); Text("Y 上下").tag(true) }.pickerStyle(.segmented)
                            Toggle("反向", isOn: $model.inverted)
                        }
                        HStack {
                            Text("轴值 \(model.axis, specifier: "%+.3f")")
                            Spacer()
                            if model.audioShuttle { Text("播放档位 \(model.playbackLevel) / 4") }
                            else { Text("连续速度 \(model.rate, specifier: "%+.1f") /s") }
                        }.font(.system(.body, design: .monospaced))
                        ProgressView(value: (model.axis + 1) / 2)
                        HStack { Text("死区"); Slider(value: $model.deadzone, in: 0.05...0.30); Text("\(model.deadzone * 100, specifier: "%.0f")%").frame(width: 45) }
                        HStack { Text("单步幅度"); Slider(value: $model.stepThreshold, in: 0.35...0.80); Text("\(model.stepThreshold * 100, specifier: "%.0f")%").frame(width: 45) }
                        HStack { Text("长推幅度"); Slider(value: $model.holdThreshold, in: 0.80...1.0); Text("\(model.holdThreshold * 100, specifier: "%.0f")%").frame(width: 45) }
                        HStack { Text("长推等待"); Slider(value: $model.holdDelay, in: 0.15...0.8); Text("\(model.holdDelay * 1000, specifier: "%.0f") ms").frame(width: 65) }
                        if model.audioShuttle {
                            HStack { Text("加速间隔"); Slider(value: $model.accelerationInterval, in: 0.3...2.0); Text("\(model.accelerationInterval, specifier: "%.1f") s").frame(width: 55) }
                        }
                        Group {
                            if !model.audioShuttle {
                            HStack { Text("曲线"); Slider(value: $model.exponent, in: 1...4); Text("\(model.exponent, specifier: "%.1f")").frame(width: 45) }
                            HStack { Text("上限"); Slider(value: $model.maximumRate, in: 10...300); Text("\(model.maximumRate, specifier: "%.0f") /s").frame(width: 55) }
                            }
                            Text("短推回中发送上一帧或下一帧快捷键；无权限时回退 MIDI Jog。长推达到幅度并等待后开始连续；关闭有声长推使用 MIDI Jog 幅度调速，需 Premiere 绑定 MIDI 端口。").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(6)
                }
                Text(model.keyboardDiagnostic).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                MappingEditor(model: model)
                HStack(alignment: .top) {
                    Image(systemName: model.armed ? "waveform.path" : "pause.circle")
                    Text(model.status).frame(maxWidth: .infinity, alignment: .leading)
                    Text("MIDI \(model.sentCount)").monospacedDigit()
                }.font(.caption)
                Text("仅 Premiere 前台时启动；回中后可操作。有声长推在回中、关闭输出、断连、切出 Premiere 或正常退出时发送停止。独立的 MCU Play 仍需显式停止。").font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.frame(minWidth: 620, minHeight: 700).tint(.teal)
    }
}
