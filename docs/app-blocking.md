# 🚫 全面禁用 Windows 应用拦截

解决 Windows Server 环境中"管理员已阻止你运行此应用"红色警告弹窗，特别针对签名证书被吊销导致的应用拦截问题。

> ⚠️ **安全警告**: 此工具会显著降低系统安全性，仅建议在受信任的服务器环境中使用。

## 功能

此工具通过多层次的系统配置修改，全面禁用 Windows 应用拦截机制：

### 核心功能 (8 步)

1. **禁用 SmartScreen** - 关闭 Explorer 和系统级 SmartScreen 策略
2. **禁用代码签名验证** - 禁用管理员代码签名验证 (ValidateAdminCodeSignatures)
3. **禁用软件限制策略 (SRP)** - 设置默认级别为"不受限制"
4. **解除附件管理器限制** - 禁用 Zone 信息保存
5. **禁用 AppLocker 服务** - 停止并禁用 AppIDSvc 服务
6. **批量解除文件锁定** - 使用 Unblock-File 解锁文件
7. **禁用证书吊销检查** ⭐ - 禁用 CRL 检查，解决签名证书被吊销问题
8. **重置文件权限** ⭐ - 使用 takeown/icacls 获取所有权并重置权限

### 证书吊销检查禁用 (步骤 7)

- 用户级证书吊销检查 (`CertificateRevocation`)
- 证书填充检查 (`EnableCertPaddingCheck`)
- 用户模式代码完整性检查 (`UMCIDisabled`)
- SmartScreen 应用安装控制
- 根证书自动更新
- 系统级 Internet 证书吊销检查

### 权限重置 (步骤 8)

自动搜索以下 Python 安装路径：
- `%USERPROFILE%\Python*`
- `%LOCALAPPDATA%\Programs\Python*`
- `C:\Python*`
- `%ProgramFiles%\Python*`
- `%ProgramFiles(x86)%\Python*`

对每个路径执行：
- `takeown /F /R /A /D Y` - 获取文件所有权
- `icacls /reset /T /C /Q` - 重置权限
- 授予 Administrators、当前用户和 SYSTEM 完全控制权限
- 移除 Zone.Identifier 备用数据流 (ADS)

## 参数

| 参数 | 说明 |
|------|------|
| `-Headless` | 无头模式，禁用交互式提示 |
| `-Silent` | 静默模式，减少输出 |
| `-NoAdmin` | 跳过管理员权限检查 |
| `-UnblockPath` | 指定批量解锁的目录路径 |

## 使用示例

```powershell
# 基本用法 (自动处理常见 Python 安装路径)
.\scripts\ps1\Disable-AppBlocking.ps1

# 指定需要解锁的目录
.\scripts\ps1\Disable-AppBlocking.ps1 -UnblockPath "C:\MyApps"

# 静默模式运行
.\scripts\ps1\Disable-AppBlocking.ps1 -Silent -Headless
```

## 技术细节

### 注册表修改

| 路径 | 值名称 | 设置 |
|------|--------|------|
| `HKLM:\...\Explorer` | `SmartScreenEnabled` | "Off" |
| `HKLM:\...\Policies\System` | `ValidateAdminCodeSignatures` | 0 |
| `HKLM:\...\safer\codeidentifiers` | `DefaultLevel` | 262144 |
| `HKCU:\...\Internet Settings` | `CertificateRevocation` | 0 |
| `HKLM:\...\CI` | `UMCIDisabled` | 1 |

### 服务修改

- `AppIDSvc` (AppLocker) - 停止并禁用

## 适用场景

- 阿里云/腾讯云等云服务器 Windows Server 环境
- Python 签名证书被吊销导致无法运行的情况
- 需要运行未签名或自签名应用的开发环境

## 注意事项

1. **需要管理员权限**: 脚本会自动请求提升权限
2. **部分设置需重启**: 某些深度系统设置可能需要重启生效
3. **安全风险**: 禁用证书检查会使系统更容易受到恶意软件攻击
4. **仅限服务器**: 不建议在个人电脑上使用此脚本
