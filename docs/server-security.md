# 🔓 Windows Server 安全策略优化

此工具用于优化 Windows Server 的安全策略设置，特别适用于开发、测试或内部服务器环境。

> [!CAUTION]
> **警告**: 此脚本会降低系统的安全性。请仅在受信任的网络环境中使用，不建议在生产服务器上使用！

---

## 📋 功能说明

此脚本将执行以下三项优化：

| 优化项 | 说明 |
|:---|:---|
| 禁用密码过期 | 所有本地用户的密码将永不过期 |
| 禁用密码复杂度 | 取消密码必须包含大小写、数字、特殊字符的要求 |
| 禁用 Ctrl+Alt+Delete | 登录时无需按 Ctrl+Alt+Delete 组合键 |

---

## 🚀 使用方法

### 通过工具箱运行
在 Windows LTSC 工具箱中选择"服务器安全策略优化"选项。

### 通过 PowerShell 直接运行
```powershell
# 交互式运行 (需要管理员权限)
.\scripts\ps1\Optimize-ServerSecurity.ps1

# 无头模式 (自动化脚本)
.\scripts\ps1\Optimize-ServerSecurity.ps1 -Headless -Silent
```

---

## ⚙️ 命令行参数

| 参数 | 说明 |
|:---|:---|
| `-Headless` | 无头模式，禁用交互式提示 |
| `-Silent` | 静默模式，减少输出信息 |
| `-NoAdmin` | 跳过管理员权限检查（仅限内部使用） |

---

## 🔧 技术实现

1. **密码过期禁用**
   - 使用 `Set-LocalUser -PasswordNeverExpires $true` 设置所有用户
   - 使用 `net accounts /maxpwage:unlimited` 设置系统策略

2. **密码复杂度禁用**
   - 通过 `secedit` 导出并修改安全策略
   - 设置 `PasswordComplexity = 0`
   - 设置 `MinimumPasswordLength = 0`

3. **Ctrl+Alt+Delete 禁用**
   - 修改注册表项 `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`
   - 设置 `DisableCAD = 1`

---

## ⚠️ 注意事项

- 部分设置可能需要**重启计算机**后才能完全生效
- 此脚本主要针对 Windows Server 系统设计
- 执行后会自动刷新组策略 (`gpupdate /force`)
