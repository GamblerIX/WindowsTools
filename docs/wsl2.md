# WSL2 安装工具

## 简介

一键在 Windows 系统上安装并配置 WSL2 (Windows Subsystem for Linux)。该工具会自动启用必要的系统特性，并从 GitHub Releases 获取最新版本的 WSL 进行安装。

## 特性

- **GitHub 源安装**：始终从 [microsoft/WSL Releases](https://github.com/microsoft/WSL/releases/latest) 获取最新版本。
- **备选下载**：若 GitHub API 无法连接，自动使用预设的备选下载地址。
- **自动开启特性**：自动开启"适用于 Linux 的 Windows 子系统"和"虚拟机平台"可选功能。
- **默认版本设置**：自动将 WSL 的默认版本设置为 2。
- **发行版一键安装**：默认安装 **Debian 12**（如果系统支持）。
- **智能兼容**：自动识别系统版本。Build 18362+ 支持 WSL2，较低版本（如 LTSC 2019）将仅尝试开启 WSL1。

## 使用方法

1. 从工具箱点击 **"运行"**。
2. 脚本会检测您的系统版本和当前的 WSL 状态。
3. 按照提示执行，期间可能需要重启计算机以完成特性开启。
4. 重启后再次运行脚本，它将继续完成 WSL 安装和版本配置。

## 工作原理

1. **功能启用**：使用 `Enable-WindowsOptionalFeature` 开启 `Microsoft-Windows-Subsystem-Linux` 和 `VirtualMachinePlatform`。
1. **功能启用**：使用 `Enable-WindowsOptionalFeature` 开启 `Microsoft-Windows-Subsystem-Linux` 和 `VirtualMachinePlatform`。
2. **WSL 安装**：优先从 GitHub Releases 获取最新版。若 GitHub API 连接失败，自动切换至**微软官方备选方案**（Blob 存储地址）进行下载安装。
3. **版本切换**：运行 `wsl --set-default-version 2`。
4. **发行版安装**：运行 `wsl --install -d Debian`。

## 验证安装

在 PowerShell 中运行以下命令查看版本：

```powershell
wsl --list --verbose
```

## 常见问题

- **错误 0x8007019e**：通常是因为没有开启"适用于 Linux 的 Windows 子系统"特性。
- **错误 0x80370102**：通常是因为没有在 BIOS/UEFI 中开启硬件虚拟化支持。
- **需要重启**：首次启用 WSL 特性后必须重启，否则后续安装会失败。
