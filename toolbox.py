# toolbox.py - 兼容性导入模块
# 此文件重新导出 scripts.python.toolbox 模块的所有内容
# 确保现有测试和代码继续正常工作

import sys
import os

# 添加 scripts/python 到路径
_scripts_python_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scripts', 'python')
if _scripts_python_dir not in sys.path:
    sys.path.insert(0, _scripts_python_dir)

# 重新导出所有公共 API
from toolbox import (
    # utils
    is_admin,
    run_as_admin,
    get_base_dir,
    log_error,
    get_scripts_dir,
    get_tmp_dir,
    cleanup_tmp_dir,
    parse_script_metadata,
    scan_scripts,
    # cli
    parse_arguments,
    list_scripts,
    run_script_headless,
    # gui
    TerminalTextEdit,
    TaskInterface,
    ToolCard,
    ToolsInterface,
    Window,
)

__all__ = [
    'is_admin',
    'run_as_admin',
    'get_base_dir',
    'log_error',
    'get_scripts_dir',
    'get_tmp_dir',
    'cleanup_tmp_dir',
    'parse_script_metadata',
    'scan_scripts',
    'parse_arguments',
    'list_scripts',
    'run_script_headless',
    'TerminalTextEdit',
    'TaskInterface',
    'ToolCard',
    'ToolsInterface',
    'Window',
]
