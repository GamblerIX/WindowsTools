# toolbox - Windows 工具箱核心模块
# 基础工具函数模块

import sys
import os
import ctypes
import glob
import shutil
from datetime import datetime


def is_admin():
    """检查当前进程是否具有管理员权限"""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False


def run_as_admin():
    """以管理员权限重新启动当前脚本"""
    ctypes.windll.shell32.ShellExecuteW(
        None, "runas", sys.executable, " ".join(sys.argv), None, 1
    )


def get_base_dir():
    """Get the base directory of the application."""
    # For PyInstaller
    if hasattr(sys, '_MEIPASS'):
        return sys._MEIPASS
    # For Nuitka or source
    return os.path.dirname(os.path.abspath(sys.argv[0] if sys.argv[0] else __file__))


def log_error(error):
    """Log error to a file for debugging."""
    with open(os.path.join(get_base_dir(), 'crash_log.txt'), 'a', encoding='utf-8') as f:
        f.write(f"[{datetime.now()}] {error}\n")


def get_scripts_dir():
    """获取脚本目录路径"""
    return os.path.join(get_base_dir(), 'scripts')


def get_tmp_dir():
    """Get the tmp directory for caching downloads."""
    tmp_dir = os.path.join(get_base_dir(), 'tmp')
    if not os.path.exists(tmp_dir):
        os.makedirs(tmp_dir, exist_ok=True)
    return tmp_dir


def cleanup_tmp_dir():
    """Clean up the tmp directory."""
    tmp_dir = os.path.join(get_base_dir(), 'tmp')
    if os.path.exists(tmp_dir):
        try:
            shutil.rmtree(tmp_dir)
        except Exception as e:
            print(f"Failed to cleanup tmp directory: {e}")


def parse_script_metadata(filepath):
    """解析脚本中的标题和描述。"""
    original_title = os.path.splitext(os.path.basename(filepath))[0]
    description = ""

    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()[:20]

        comments = []
        for line in lines:
            line_upper = line.upper().strip()
            if line.startswith('::'):
                text = line[2:].strip()
                if text and not text.startswith('='):
                    comments.append(text)
            elif line_upper.startswith('REM '):
                text = line[4:].strip()
                if text and not text.startswith('='):
                    comments.append(text)
            elif line.startswith('#') and not line.startswith('#!'):
                text = line[1:].strip()
                if text and not text.startswith('='):
                    comments.append(text)

        if comments:
            title = comments[0]
            if len(comments) > 1:
                description = comments[1]
            return title, description
    except Exception as e:
        print(f"解析元数据失败 {filepath}: {e}")

    return original_title, ""


def scan_scripts():
    """Scan scripts directory and subdirectories for supported scripts."""
    scripts_dir = get_scripts_dir()
    scripts = []

    # 扫描所有子目录下的脚本
    search_patterns = [
        os.path.join(scripts_dir, '*.ps1'),
        os.path.join(scripts_dir, '*', '*.ps1'),
        os.path.join(scripts_dir, '*.bat'),
        os.path.join(scripts_dir, '*', '*.bat'),
        os.path.join(scripts_dir, '*.cmd'),
        os.path.join(scripts_dir, '*', '*.cmd'),
    ]

    found_files = []
    for pattern in search_patterns:
        found_files.extend(glob.glob(pattern))

    # 去重并过滤
    unique_files = list(set(os.path.abspath(f) for f in found_files))

    for filepath in unique_files:
        basename = os.path.basename(filepath).lower()
        
        # 排除副本（同名的 .ps1 和 .bat，优先保留 .ps1）
        if basename.endswith('.ps1') and os.path.exists(filepath.replace('.ps1', '.bat')):
            continue
        if basename.endswith('.bat') and os.path.exists(filepath.replace('.bat', '.ps1')):
            continue

        title, desc = parse_script_metadata(filepath)
        scripts.append((filepath, title, desc))

    return sorted(scripts, key=lambda x: x[1])
