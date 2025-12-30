# toolbox - Windows 工具箱核心模块
# 重新导出所有公共 API，保持向后兼容性

from .utils import (
    is_admin,
    run_as_admin,
    get_base_dir,
    log_error,
    get_scripts_dir,
    get_tmp_dir,
    cleanup_tmp_dir,
    parse_script_metadata,
    scan_scripts,
)

from .cli import (
    parse_arguments,
    list_scripts,
    run_script_headless,
)

from .gui.widgets import (
    TerminalTextEdit,
    TaskInterface,
)

from .gui.main_window import (
    ToolCard,
    ToolsInterface,
    Window,
)

__all__ = [
    # utils
    'is_admin',
    'run_as_admin',
    'get_base_dir',
    'log_error',
    'get_scripts_dir',
    'get_tmp_dir',
    'cleanup_tmp_dir',
    'parse_script_metadata',
    'scan_scripts',
    # cli
    'parse_arguments',
    'list_scripts',
    'run_script_headless',
    # gui
    'TerminalTextEdit',
    'TaskInterface',
    'ToolCard',
    'ToolsInterface',
    'Window',
]
