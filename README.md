# 🛠️ Windows LTSC 工具箱

本项目是一个专为 **Windows LTSC** 及 **Server** 系列系统设计的开源工具集，旨在解决这些精简版系统中常见的组件缺失问题（如 Microsoft Store 和 Windows Terminal），并提供一键式系统优化。

> **✨ 特色**：基于 `PySide6` 和 `Fluent Widgets` 的现代化 UI，支持多任务并发执行，实时查看详细日志。

---

## 🖥️ 系统支持

本项目针对以下版本进行了适配：
- **Windows LTSC**: 2019, 2021, 2024
- **Windows Server**: 2019, 2022, 2025

| 组件 | LTSC 2019 | LTSC 2021 | LTSC 2024 | Server 2022/2025 |
| :--- | :---: | :---: | :---: | :---: |
| PowerShell 7 | ✅ | ✅ | ✅ | ✅ |
| Windows Terminal | ✅ | ✅ | ✅ | ✅ |
| Microsoft Store | ✅ | ✅ | ✅ | ✅ |
| 系统优化脚本 | ✅ | ✅ | ✅ | ✅ |

> **注意**：
> 系统优化脚本仅提供基础优化，不保证所有系统都能正常工作。
>
> 对于非 LTSC/Server 系统，脚本不一定生效。

---

## 🚀 核心工具

您可以点击相关文档了解更多细节：

1.  💻 [**Windows Terminal 安装**](docs/windows-terminal.md): 支持所有 LTSC 版本，**自动处理 Microsoft.UI.Xaml 依赖**。
2.  🛍️ [**Microsoft Store 安装**](docs/microsoft-store.md): 一键恢复 LTSC 系统缺失的应用商店。
3.  🐚 [**PowerShell 7 安装**](docs/powershell7.md): 自动获取最新稳定版本并配置环境。
4.  🌍 [**UTF-8 支持启用**](docs/utf8-support.md): 全局开启 Beta 版 UTF-8 编码支持，解决古老脚本乱码问题。
5.  🔕 [**安全通知禁用**](docs/security-notifications.md): 一键关闭 Windows Security Center 的烦人通知。
6.  🔓 [**服务器安全策略优化**](docs/server-security.md): 禁用密码过期、复杂度检查及 Ctrl+Alt+Delete 登录要求。
7.  🛡️ [**UAC 提示禁用**](docs/uac-prompt.md): 禁用管理员操作的 UAC 弹窗提示，适用于服务器自动化场景。
8.  🚫 [**应用拦截禁用**](docs/app-blocking.md): 全面禁用 SmartScreen、证书吊销检查等拦截机制，解决签名证书被吊销的问题。

---

## 🛠️ 从源码运行

### 运行环境
- Python 3.11+ (已验证兼容 Python 3.13)
- 管理员权限

### 快速启动
```powershell
# 克隆仓库
git clone https://github.com/GamblerIX/WindowsTools.git
cd WindowsTools

# 安装依赖
pip install -r requirements.txt

# 启动工具箱 (会自动申请管理员权限)
python main.py
```

---

## 🧪 开发与测试

本项目保持高质量的代码标准：
- **单元测试**: `python test/test_utils.py` (核心工具库 100% 覆盖率)。
- **代码覆盖率**:
  - 运行并生成报告：双击 `test/run_tests.bat`。
  - 查看网页版：打开 `test/htmlcov/index.html`。

---

## 🤖 GitHub 工作流

本项目配置了自动化流程：
- 🚀 **CI (持续集成)**: 每次提交自动运行单元测试并验证 Python 环境。

---

## ⚖️ 许可证

本项目采用 [GNU AGPL v3](LICENSE) 许可证。
