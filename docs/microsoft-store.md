# Microsoft Store 安装工具

## 简介

为 Windows 11 LTSC 2024 安装 Microsoft Store（LTSC 版本默认不包含商店）。

## 使用方法

1. 双击运行 `Install-MicrosoftStore.bat`
2. 如弹出 UAC 提示，点击"是"允许
3. 等待安装完成

## 工作原理

1. 使用 `wsreset.exe -i` 命令安装 Microsoft Store（Windows 11 LTSC 内置方法）
2. 通过 `Add-AppxPackage` 重新注册商店应用，确保在开始菜单显示

## 验证安装

- 在开始菜单搜索 "Store" 或 "商店"
- 或按 `Win + R`，输入 `ms-windows-store:` 回车

## 故障排除

如果商店无法打开，尝试：

```cmd
wsreset.exe
```

如仍有问题，重启电脑后再试。
