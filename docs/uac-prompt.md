# 禁用 UAC 提升提示

禁用 Windows 用户账户控制 (UAC) 的弹窗提示，适用于服务器自动化管理场景。

> ⚠️ **安全警告**: 禁用 UAC 提示会降低系统安全性，仅建议在受信任的服务器环境中使用。

## 功能

- **禁用 UAC 提升提示**: 管理员操作无需确认弹窗
- **禁用安全桌面**: 不切换到安全桌面进行提示
- **可选完全禁用 UAC**: 通过 `-DisableUAC` 开关彻底关闭 UAC

## 参数

| 参数 | 说明 |
|------|------|
| `-Headless` | 无头模式，禁用交互式提示 |
| `-Silent` | 静默模式，减少输出 |
| `-NoAdmin` | 跳过管理员权限检查 |
| `-DisableUAC` | 完全禁用 UAC (需要重启) |

## 使用示例

```powershell
# 禁用 UAC 提升提示 (推荐)
.\scripts\ps1\Disable-UACPrompt.ps1

# 完全禁用 UAC (需要重启)
.\scripts\ps1\Disable-UACPrompt.ps1 -DisableUAC

# 静默模式运行
.\scripts\ps1\Disable-UACPrompt.ps1 -Silent -Headless
```

## 技术细节

修改以下注册表值 (`HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System`):

| 值名称 | 设置 | 说明 |
|--------|------|------|
| `ConsentPromptBehaviorAdmin` | 0 | 不提示直接提升 |
| `PromptOnSecureDesktop` | 0 | 不切换安全桌面 |
| `EnableLUA` | 0 | 完全禁用 UAC (仅 `-DisableUAC`) |

## 恢复默认设置

如需恢复 UAC 默认行为：

```powershell
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 5
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Value 1
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -Value 1
# 如果修改了 EnableLUA，需要重启计算机
```
