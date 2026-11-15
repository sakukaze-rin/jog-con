# Contributing

使用 Swift Package Manager 开发，无第三方运行时依赖。

1. `swift test` 验证核心。
2. `sh scripts/build-app.sh` 构建 macOS App。
3. 参考 `docs/TESTING.md` 做真实手柄及 Premiere 验证。

保持协议编码和时序计算位于 `JogConCore`，平台 I/O 位于 `JogCon`。
修改控制行为应新增有意义的核心测试。兼容性报告需记录 macOS、Premiere、手柄及固件版本（如果已知），以及具体观察。

请勿提交 Premiere 工程、素材、蓝牙地址、签名证书、个人设置或 `.build` 目录。
