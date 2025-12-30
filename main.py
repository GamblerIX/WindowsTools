# Windows 工具箱 - 主入口点
# 模块化重构后的简化入口

import sys
import os
import signal

# 添加模块路径
_scripts_python_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scripts', 'python')
if _scripts_python_dir not in sys.path:
    sys.path.insert(0, _scripts_python_dir)

from PySide6.QtCore import Qt
from PySide6.QtWidgets import QApplication

from toolbox import (
    is_admin,
    run_as_admin,
    log_error,
    cleanup_tmp_dir,
    parse_arguments,
    list_scripts,
    run_script_headless,
    Window,
)


def main():
    """主入口函数"""
    try:
        # Handle Ctrl+C gracefully
        signal.signal(signal.SIGINT, signal.SIG_DFL)
        
        # 解析命令行参数
        args = parse_arguments()
        
        # 处理 --list 参数
        if args.list:
            list_scripts()
            sys.exit(0)
        
        # 处理 --run 参数 (无头模式)
        if args.run:
            if not args.no_admin and not is_admin():
                print("[INFO] 正在请求管理员权限...")
                # 重新以管理员身份运行
                run_as_admin()
                sys.exit(0)
            
            exit_code = run_script_headless(
                args.run,
                headless=args.headless,
                silent=args.silent,
                force=args.force,
                no_admin=True  # 已经提权或跳过
            )
            sys.exit(exit_code)
        
        # 默认启动 GUI
        if not is_admin():
            run_as_admin()
            sys.exit()
        
        QApplication.setHighDpiScaleFactorRoundingPolicy(Qt.HighDpiScaleFactorRoundingPolicy.PassThrough)
        app = QApplication(sys.argv)
        
        # Check for qfluentwidgets resources
        try:
            from qfluentwidgets import Theme
        except Exception as e:
            log_error(f"Failed to import qfluentwidgets resources: {e}")
            raise
            
        Window().show()
        sys.exit(app.exec())
    except Exception as e:
        import traceback
        log_error(f"Uncaught exception: {e}\n{traceback.format_exc()}")
        raise


if __name__ == '__main__':
    main()
