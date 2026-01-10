# 📝 Typora 右键新建菜单

脚本: `Add-TyporaContextMenu.ps1`

## 简介
此脚本会在 Windows 文件资源管理器的右键 "新建" 菜单中添加 "Markdown 文件" 选项，默认关联 Typora 打开。

## 功能特性
- **注册表注入**: 自动添加必要的 `.md` ShellNew 注册表项。
- **智能路径检测**: 尝试自动检测 Typora 安装路径，以设置正确的图标和打开命令。
- **自定义图标**: 如果找到 Typora，新建菜单项将显示 Typora 的图标。

## 使用方法
在工具箱列表中选择 "Add-TyporaContextMenu" 运行即可。

> **注意**: 如果右键菜单没有立即生效，尝试重启电脑或注销重新登录。
