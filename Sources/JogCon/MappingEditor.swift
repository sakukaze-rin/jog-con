import SwiftUI
import JogConCore

struct MappingEditor: View {
    @ObservedObject var model: AppModel
    var body: some View {
        GroupBox("Joy-Con 按钮映射 · 按下触发一次") {
            VStack(alignment: .leading, spacing: 12) {
                Text("选择或学习实体按钮，再指定 Premiere 动作或录制任意快捷键组合。预设快捷键以 Adobe 默认方案为准。").font(.caption).foregroundStyle(.secondary)
                ForEach($model.buttonMappings) { $mapping in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Picker("按钮", selection: $mapping.input) {
                                ForEach(Array(Set(model.bindingNames + [mapping.input])).sorted(), id: \.self) { Text(ControllerInput.title(for: $0)).tag($0) }
                            }
                            Button(model.learningID == mapping.id ? "取消学习" : "学习") {
                                if model.learningID == mapping.id { model.learningID = nil } else { model.learn(mapping.id) }
                            }
                            Button(role: .destructive) { model.buttonMappings.removeAll { $0.id == mapping.id } } label: { Image(systemName: "trash") }
                        }
                        Picker("执行", selection: $mapping.action) {
                            ForEach(ButtonAction.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        if mapping.action == .custom { ShortcutRecorder(shortcut: $mapping.shortcut).frame(height: 30) }
                        if mapping.input != "无" && model.buttonMappings.filter({ $0.input == mapping.input }).count > 1 {
                            Text("此按钮有重复绑定，仅执行最上面一条。").font(.caption).foregroundStyle(.orange)
                        }
                    }.padding(8).background(Color.secondary.opacity(0.06)).cornerRadius(8)
                }
                Button("＋ 添加映射") { model.buttonMappings.append(ButtonMapping()) }
                if !model.input.hasStickPress {
                    Text("当前手柄配置未报告摇杆按压；重新检测后可用「学习」确认实际输入名称。").font(.caption).foregroundStyle(.orange)
                }
                Text("当前输入：\(model.inputDescription)").font(.caption.monospaced()).textSelection(.enabled)
                Text("\(model.buttonMappings.count) 条映射自动保存。学习按钮时会关闭输出，完成后请重新启用。").font(.caption).foregroundStyle(.secondary)
                Button("授权播放与快捷键（辅助功能）") { PremiereBridge.requestAccessibility() }
            }.padding(6)
        }
    }
}
