# iPad as Mac Trackpad Demo

一个最小可运行的双端 Swift Demo：

- **iPadTrackpad**：把 iPad 屏幕当作触摸板。
- **MacReceiver**：运行在 Mac 上，接收 iPad 的手势并通过 CGEvent 控制鼠标。

## 已实现

- 单指滑动：移动鼠标
- 单指轻点：左键
- 双指轻点：右键
- 双指滑动：滚动
- iPad 灵敏度调节
- 基于 MultipeerConnectivity 的局域网自动发现与加密连接
- Mac 端辅助功能权限提示

## 运行

1. 用 Xcode 打开 iPadTrackpadDemo.xcodeproj。
2. 选择 **MacReceiver** Scheme，在 Mac 上运行。
3. 第一次运行时，在 **系统设置 → 隐私与安全性 → 辅助功能** 中允许 MacReceiver 控制电脑。
4. 选择 **iPadTrackpad** Scheme，运行到 iPad 真机。
5. iPad 首次请求“本地网络”权限时选择允许。
6. 两台设备位于同一局域网时会自动发现并连接。

> 这是用于验证交互链路的 Demo，不包含账号认证或设备配对确认，请只在可信局域网中测试。
