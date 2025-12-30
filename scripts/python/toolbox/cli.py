# toolbox - Windows 工具箱核心模块
# 命令行接口模块

import os
import subprocess
import argparse

from .utils import scan_scripts, get_tmp_dir, cleanup_tmp_dir


def parse_arguments():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(
        description='Windows 工具箱 - LTSC 系统优化工具集',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  main.py                      # 启动 GUI 界面
  main.py --list               # 列出所有可用脚本
  main.py --run Install-PowerShell7
  main.py --run Install-WindowsTerminal --silent
  main.py --run Enable-UTF8Support --headless
"""
    )
    parser.add_argument(
        '--list', '-l',
        action='store_true',
        help='列出所有可用的脚本'
    )
    parser.add_argument(
        '--run', '-r',
        metavar='SCRIPT',
        help='运行指定的脚本 (无需 .ps1 扩展名)'
    )
    parser.add_argument(
        '--headless',
        action='store_true',
        help='无头模式，禁用交互式提示'
    )
    parser.add_argument(
        '--silent', '-s',
        action='store_true',
        help='静默模式，减少输出'
    )
    parser.add_argument(
        '--force', '-f',
        action='store_true',
        help='强制执行 (跳过版本检查等)'
    )
    parser.add_argument(
        '--no-admin',
        action='store_true',
        help='跳过管理员权限检查 (用于已提权环境)'
    )
    return parser.parse_args()


def list_scripts():
    """列出所有可用脚本"""
    scripts = scan_scripts()
    if not scripts:
        print("未找到可用脚本。")
        return
    
    print("可用脚本列表:")
    print("=" * 50)
    for path, title, desc in scripts:
        basename = os.path.splitext(os.path.basename(path))[0]
        print(f"  {basename}")
        print(f"    标题: {title}")
        if desc:
            print(f"    描述: {desc}")
        print()


def run_script_headless(script_name, headless=False, silent=False, force=False, no_admin=False):
    """在无头模式下运行指定脚本"""
    scripts = scan_scripts()
    
    # 查找匹配的脚本
    target_script = None
    script_name_lower = script_name.lower()
    
    for path, title, desc in scripts:
        basename = os.path.splitext(os.path.basename(path))[0]
        if basename.lower() == script_name_lower:
            target_script = path
            break
    
    if not target_script:
        print(f"[ERROR] 未找到脚本: {script_name}")
        print("使用 --list 查看可用脚本列表。")
        return 1
    
    if not silent:
        print(f"运行脚本: {os.path.basename(target_script)}")
        print("=" * 50)
    
    # 构建 PowerShell 命令
    ps_args = [
        'powershell.exe',
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', target_script
    ]
    
    # 添加脚本参数
    if headless:
        ps_args.append('-Headless')
    if silent:
        ps_args.append('-Silent')
    if force:
        ps_args.append('-Force')
    if no_admin:
        ps_args.append('-NoAdmin')
    
    # 设置环境变量
    env = os.environ.copy()
    env['TOOLBOX_TMP_DIR'] = get_tmp_dir()
    
    try:
        # 运行脚本
        result = subprocess.run(
            ps_args,
            env=env,
            shell=False
        )
        return result.returncode
    except Exception as e:
        print(f"[ERROR] 执行脚本时发生错误: {e}")
        return 1
    finally:
        # 无头模式下清理临时目录
        if headless:
            cleanup_tmp_dir()
