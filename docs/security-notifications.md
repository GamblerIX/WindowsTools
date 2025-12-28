# 🔕 Windows 安全中心通知禁用工具

## 简介

此工具旨在永久禁用 Windows 安全中心（Windows Security Center）发送的各类非关键通知、警告和托盘弹出消息。适用于需要纯净通知环境或在 Server/LTSC 系统中减少干扰的用户。

## 功能特性

- **一键禁用**：同时通过组策略注册表项和系统通知设置禁用安全中心。
- **永久生效**：修改 HKLM（本地机器）级别配置，对所有用户生效。
- **静默刷新**：操作后自动重启 `ShellExperienceHost` 和 `StartMenuExperienceHost` 以刷新通知系统，通常无需重启电脑即可见效。

## 工作原理

1. **组策略禁用**：
   - 在 `HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications` 下设置 `DisableNotifications = 1`。
2. **系统设置禁用**：
   - 禁用 `Windows.SystemToast.SecurityAndMaintenance` 通讯设置。
   - 在 `HKLM\SOFTWARE\Microsoft\Windows Defender\Reporting` 下设置 `DisableEnhancedNotifications = 1`。
3. **通知刷新**：
   - 强制结束相关外壳进程以应用更改。

## 注意事项

1. **不关闭引擎**：该工具**仅禁用通知**，并不会关闭 Windows Defender 的实时保护或扫描引擎。
2. **生效时间**：大部分通知设置会立即生效，但部分深度集成的通知可能需要注销或重启计算机。
3. **安全性**：虽然由于已应用安全策略而不再显示警告，但建议用户定期通过安全中心手动检查系统状态。

## 验证方法

1. 配置完成后，即便病毒库过期或未执行扫描，任务栏右侧通知中心也不再弹出安全中心相关的消息提示。
2. 检查注册表项确认值是否已正确设置。
