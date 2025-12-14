# Windows 工具集

## 1. PowerShell 7 一键静默安装

### 简介

一键静默安装 PowerShell 7，自动下载最新稳定版。

### 使用方法

1. 双击运行 `Install-PowerShell7.bat`
2. 如弹出 UAC 提示，点击"是"允许
3. 等待自动下载并安装完成

### 安装选项

仅启用 `ADD_PATH`（将 PowerShell 添加到系统 PATH）

### 验证安装

```cmd
pwsh --version
```

---

## 2. Microsoft Store 安装工具

### 简介

为 Windows 11 LTSC 2024 安装 Microsoft Store（LTSC 版本默认不包含商店）。

### 使用方法

1. 双击运行 `Install-MicrosoftStore.bat`
2. 如弹出 UAC 提示，点击"是"允许
3. 等待安装完成

### 工作原理

1. 使用 `wsreset.exe -i` 命令安装 Microsoft Store（Windows 11 LTSC 内置方法）
2. 通过 `Add-AppxPackage` 重新注册商店应用，确保在开始菜单显示

### 验证安装

- 在开始菜单搜索 "Store" 或 "商店"
- 或按 `Win + R`，输入 `ms-windows-store:` 回车

### 故障排除

如果商店无法打开，尝试：

```cmd
wsreset.exe
```

如仍有问题，重启电脑后再试。

---

## 3. Windows Terminal 安装工具

### 简介

一键下载安装 Windows Terminal 最新稳定版，自动识别 Windows 10/11 并下载对应版本。

### 使用方法

1. 双击运行 `Install-WindowsTerminal.bat`
2. 如弹出 UAC 提示，点击"是"允许
3. 等待自动下载并安装完成

### 工作原理

1. 检测系统版本（Build >= 22000 为 Windows 11）
2. 从 GitHub API 获取最新稳定版
3. Windows 11 下载 `.msixbundle`，Windows 10 下载 `Win10` 专用包
4. 使用 `Add-AppxPackage` 安装

### 验证安装

- 在开始菜单搜索 "Terminal"
- 或在资源管理器右键选择 "在终端中打开"

---

## 系统要求

- Windows 10 / Windows 11 / Windows Server 2016+
- 管理员权限
- 网络连接

## 参考文档

- [PowerShell 官方安装文档](https://learn.microsoft.com/zh-cn/powershell/scripting/install/install-powershell-on-windows)
- [PowerShell GitHub Releases](https://github.com/PowerShell/PowerShell/releases)
