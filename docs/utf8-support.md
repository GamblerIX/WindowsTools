# 🌍 UTF-8 支持启用工具

## 简介

此工具用于为 Windows 系统全局开启 **Beta: UTF-8** 编码支持。启用后，系统将使用 UTF-8 (Code Page 65001) 作为默认代码页，能够有效解决许多旧脚本、程序在处理非英文字符时的乱码问题。

## 功能特性

- **系统级配置**：修改注册表 `ACP` / `OEMCP` 项，开启系统区域设置中的“使用 Unicode UTF-8 提供全球语言支持”。
- **控制台配置**：自动为 CMD (`cmd.exe`) 配置启动时运行 `chcp 65001`。
- **PowerShell 配置**：自动修改 Windows PowerShell 和 PowerShell 7 的全局配置文件（`$PROFILE`），将输入/输出编码统一设置为 UTF-8。
- **智能兼容**：自动识别系统版本，对于不支持系统级 UTF-8 的旧版系统（Build < 18362），仅应用终端级别的配置。

## 工作原理

1. **注册表修改**：
   - 设置 `HKLM\SYSTEM\CurrentControlSet\Control\Nls\CodePage\ACP` 为 `65001`。
   - 配置 `HKLM\SOFTWARE\Microsoft\Command Processor\AutoRun` 以自动执行代码页切换。
2. **配置文件注入**：
   - 在 `$env:ProgramData\PowerShell\profile.ps1` 和 `$PROFILE.AllUsersAllHosts` 中添加编码设置脚本。

## 注意事项

1. **需要重启**：更改系统代码页后，**必须重启计算机**才能让所有应用程序完全生效。
2. **潜在风险**：极少数非常古老的程序（不支持 Unicode 的 16 位/早期 32 位程序）在 UTF-8 模式下可能会出现界面乱码。
3. **强制配置**：如果系统已是 UTF-8 状态，脚本默认跳过。可使用 `-Force` 参数强制重新应用。

## 验证方法

在 CMD 或 PowerShell 中运行以下命令，输出应为 `65001`：

```powershell
[Console]::OutputEncoding.CodePage
```
