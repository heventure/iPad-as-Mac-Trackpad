# iPad as Mac Trackpad Demo

一个最小可运行的双端 Swift Demo：

- **iPadTrackpad**：把 iPad 作为 Mac 的触控板，也可切换到「触控板 + 键盘」组合模式。
- **MacReceiver**：运行在 Mac 上，接收 iPad 的触控、键盘事件，并通过 CGEvent 控制鼠标与键盘。

## 已实现

### 触控板

- 单指滑动：移动鼠标
- 单指轻点：左键
- 双指轻点：右键
- 双指滑动：滚动
- iPad 灵敏度调节
- 指针移动使用 UDP 实时通道，其余控制消息使用 MultipeerConnectivity

### 键盘与布局

- 「触控板 + 键盘」模式，提供 Mac 风格键盘布局
- 横屏/竖屏下可拖动中间分割线，调整触控板与键盘占比
- 可交换触控板与键盘的位置
- 方向键可在传统倒 T 布局和八向摇杆之间切换
- 八向摇杆支持上下左右与四个斜向组合；拖住时保持真实 keyDown 状态，松开/回到死区时发送 keyUp
- 普通按键使用 keyDown/keyUp 生命周期；Mac 端在持续按住时发送带 autorepeat 标记的重复 keyDown，松开时只发送一次最终 keyUp
- Shift / Control / Option / Command 为粘滞修饰键，便于触屏组合输入

### 连接与权限

- 基于 MultipeerConnectivity 的局域网自动发现与加密连接
- Mac 端辅助功能权限提示
- iPad 与 Mac 断开连接时，MacReceiver 会主动释放仍处于按下状态的键，避免“卡键”

## 运行

1. 用 Xcode 打开 iPadTrackpadDemo.xcodeproj。
2. 选择 **MacReceiver** Scheme，在 Mac 上运行。
3. 第一次运行时，在 **系统设置 → 隐私与安全性 → 辅助功能** 中允许 MacReceiver 控制电脑。
4. 选择 **iPadTrackpad** Scheme，运行到 iPad 真机。
5. iPad 首次请求“本地网络”权限时选择允许。
6. 两台设备位于同一局域网时会自动发现并连接。
7. 在 iPad 顶部切换到「触控板 + 键盘」即可使用键盘；顶部「摇杆」按钮可切换方向键/八向摇杆。

> 当前 Demo 主要用于验证局域网输入链路与交互，不包含账号认证或设备配对确认，请只在可信局域网中测试。
