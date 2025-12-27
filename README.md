# Windows LTSC工具集

本项目包含一组用于 Windows LTSC 系统优化和工具安装的脚本，集成在图形化工具箱中。

> 基于 `PySide6` 和 `Fluent Widgets` 开发的图形化界面，方便一键调用各项工具。

## 系统要求
- Windows 10 LTSC / Windows 11 LTSC / Windows Server 2019+
- 管理员权限
- 网络连接（部分功能）

> 对于非 LTSC/Server 系统，脚本不一定生效。

## 快速使用

1. 从[Releases](https://github.com/GamblerIX/WindowsTools/releases)下载已打包好的工具箱
2. 双击下载的 `WindowsTools.exe` 

---

## 从源码运行

### 运行环境
- Python 3.9+

### 克隆源码并运行

```
git clone https://github.com/GamblerIX/WindowsTools.git
pip install -r requirements.txt
python toolbox.py
```

### 缓存管理
- 下载文件缓存在 `WindowsTools/tmp` 目录下
- 如果缓存中已有完整的下载文件，将直接使用，无需重复下载
- GUI 正常关闭时自动清理缓存目录

---

## 工具详细介绍

您可以点击下方链接查看各工具的详细功能及工作原理：

- 🚀 [**PowerShell 7 安装工具**](docs/powershell7.md)
- 🛍️ [**Microsoft Store 安装工具**](docs/microsoft-store.md)
- 💻 [**Windows Terminal 安装工具**](docs/windows-terminal.md)

---

## 开发与测试

本项目包含自动化测试脚本，支持输出代码覆盖率：

- **运行测试并输出覆盖率**: 双击运行 `test/run_tests.bat` 或在终端运行 `python -m coverage run --rcfile=test/.coveragerc -m unittest discover -s test`
- **查看覆盖率报告**: 
  - 命令行：`python -m coverage report --rcfile=test/.coveragerc`
  - HTML 报告：查看 `test/htmlcov/index.html`
- **单元测试**: `python test/test_utils.py` (验证元数据解析、目录管理等核心逻辑，已实现 100% 覆盖率)
- **模拟脚本**: `test/mock_script.bat` (用于手动验证 UI 显示和环境传递)

---

## 许可证

本项目采用 [GNU AGPL v3](LICENSE) 许可证。