import sys
import os
import ctypes
import glob
import signal
import shutil
from datetime import datetime
from PySide6.QtCore import Qt, QProcess, Signal, QProcessEnvironment
from PySide6.QtGui import QTextCursor, QColor, QTextCharFormat
from PySide6.QtWidgets import QApplication, QWidget, QHBoxLayout, QVBoxLayout, QTextEdit

from qfluentwidgets import (setTheme, Theme, FluentWindow, SubtitleLabel, CaptionLabel,
                            PrimaryPushButton, PushButton, FluentIcon as FIF, CardWidget, IconWidget,
                            BodyLabel, InfoBar, SmoothScrollArea, NavigationItemPosition)

# ==================== Utility Functions ====================

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def run_as_admin():
    ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, " ".join(sys.argv), None, 1)

def get_base_dir():
    """Get the base directory of the application."""
    try:
        return sys._MEIPASS
    except:
        return os.path.dirname(os.path.abspath(__file__))

def get_scripts_dir():
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
            lines = f.readlines()[:20]  # 只检查前 20 行
        
        # 查找 batch 文件中的 :: 或 REM 注释，或 ps1 中的 # 注释
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
    """Scan scripts directory and return list of (path, title, description)."""
    scripts_dir = get_scripts_dir()
    scripts = []
    
    for ext in ['*.bat', '*.ps1', '*.cmd']:
        for filepath in glob.glob(os.path.join(scripts_dir, ext)):
            # Skip helper scripts (those called by main scripts)
            basename = os.path.basename(filepath).lower()
            if basename.endswith('.ps1') and os.path.exists(filepath.replace('.ps1', '.bat')):
                continue  # Skip ps1 if matching bat exists
            
            title, desc = parse_script_metadata(filepath)
            scripts.append((filepath, title, desc))
    
    return sorted(scripts, key=lambda x: x[1])

# ==================== Terminal Widget ====================

class TerminalTextEdit(QTextEdit):
    """Terminal-style text edit with color support."""
    
    COLORS = {
        '31': '#f38ba8', '32': '#a6e3a1', '33': '#f9e2af', '34': '#89b4fa',
        '35': '#cba6f7', '36': '#94e2d5', '91': '#f38ba8', '92': '#a6e3a1',
    }
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setReadOnly(True)
        self.setStyleSheet("""
            QTextEdit {
                background-color: #1e1e2e;
                color: #cdd6f4;
                font-family: 'Cascadia Code', 'Consolas', monospace;
                font-size: 13px;
                border: none;
                border-radius: 8px;
                padding: 12px;
            }
        """)

    def append_text(self, text, color=None):
        cursor = self.textCursor()
        cursor.movePosition(QTextCursor.End)
        fmt = QTextCharFormat()
        fmt.setForeground(QColor(color or '#cdd6f4'))
        cursor.insertText(text, fmt)
        self.setTextCursor(cursor)
        self.ensureCursorVisible()

# ==================== Task Interface ====================

class TaskInterface(QWidget):
    task_finished = Signal(str, bool)
    
    def __init__(self, task_id, title, script_path, parent=None):
        super().__init__(parent)
        self.task_id = task_id
        self.title = title
        self.script_path = script_path
        self.setObjectName(task_id)
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        
        # Header
        header = QHBoxLayout()
        self.titleLabel = SubtitleLabel(title, self)
        self.statusLabel = CaptionLabel('准备中...', self)
        
        # 复制按钮
        self.copyBtn = PushButton(FIF.COPY, '复制', self)
        self.copyBtn.setFixedWidth(85)
        self.copyBtn.clicked.connect(self._copy_log)
        
        header.addWidget(self.titleLabel)
        header.addStretch()
        header.addWidget(self.copyBtn)
        header.addSpacing(15)
        header.addWidget(self.statusLabel)
        layout.addLayout(header)
        
        # Terminal
        self.terminal = TerminalTextEdit(self)
        layout.addWidget(self.terminal)
        
        # Process
        self.process = QProcess(self)
        self.process.setProcessChannelMode(QProcess.MergedChannels)
        self.process.readyReadStandardOutput.connect(self._on_output)
        self.process.finished.connect(self._on_finished)
        
    def start(self):
        self.statusLabel.setText('运行中...')
        self.terminal.append_text(f'[{datetime.now():%H:%M:%S}] 启动: {self.title}\n\n', '#89b4fa')
        
        # Set environment variable for tmp directory
        env = QProcessEnvironment.systemEnvironment()
        env.insert('TOOLBOX_TMP_DIR', get_tmp_dir())
        self.process.setProcessEnvironment(env)
        
        # Start process based on script type
        if self.script_path.lower().endswith('.ps1'):
            self.process.start('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', self.script_path])
        else:
            self.process.start('cmd', ['/c', 'chcp 65001 >nul &&', self.script_path])
        
    def _on_output(self):
        data = self.process.readAllStandardOutput().data()
        try:
            text = data.decode('utf-8')
        except:
            text = data.decode('gbk', errors='replace')
        self.terminal.append_text(text)

    def _on_finished(self, exit_code, exit_status):
        if exit_code == 0:
            self.statusLabel.setText('✅ 完成')
            self.terminal.append_text(f'\n[{datetime.now():%H:%M:%S}] ✅ 成功\n', '#a6e3a1')
        else:
            self.statusLabel.setText('❌ 失败')
            self.terminal.append_text(f'\n[{datetime.now():%H:%M:%S}] ❌ 失败 (code={exit_code})\n', '#f38ba8')
        self.task_finished.emit(self.task_id, exit_code == 0)

    def _copy_log(self):
        """将终端日志复制到剪贴板。"""
        log_text = self.terminal.toPlainText()
        if log_text:
            QApplication.clipboard().setText(log_text)
            InfoBar.success('成功', '日志已复制到剪贴板', duration=2000, parent=self.window())
        else:
            InfoBar.warning('提示', '当前日志为空', duration=2000, parent=self.window())

# ==================== Tool Card ====================

class ToolCard(CardWidget):
    task_created = Signal(object)
    
    def __init__(self, script_path, title, description, parent=None):
        super().__init__(parent)
        self.script_path = script_path
        self.title = title
        self._task_counter = 0
        
        layout = QHBoxLayout(self)
        layout.setContentsMargins(20, 15, 20, 15)
        layout.setSpacing(15)
        
        layout.addWidget(IconWidget(FIF.COMMAND_PROMPT))
        
        text_layout = QVBoxLayout()
        text_layout.setSpacing(4)
        text_layout.addWidget(SubtitleLabel(title, self))
        if description:
            desc = BodyLabel(description, self)
            desc.setTextColor(Qt.gray)
            text_layout.addWidget(desc)
        layout.addLayout(text_layout)
        
        layout.addStretch()
        
        btn = PrimaryPushButton('运行', self)
        btn.setFixedWidth(80)
        btn.clicked.connect(self._run)
        layout.addWidget(btn)
        
        self.setFixedHeight(80 if description else 60)

    def _run(self):
        if not os.path.exists(self.script_path):
            InfoBar.error('错误', f'脚本不存在: {self.script_path}', parent=self.window())
            return
        self._task_counter += 1
        task = TaskInterface(f'{self.title}_{self._task_counter}', self.title, self.script_path)
        self.task_created.emit(task)

# ==================== Main Interface ====================

class ToolsInterface(QWidget):
    task_created = Signal(object)
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setObjectName("ToolsInterface")
        
        main_layout = QVBoxLayout(self)
        scroll = SmoothScrollArea(self)
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")
        
        content = QWidget()
        layout = QVBoxLayout(content)
        layout.setContentsMargins(30, 20, 30, 30)
        layout.setSpacing(12)
        layout.setAlignment(Qt.AlignTop)
        
        layout.addWidget(SubtitleLabel('工具列表', self))
        layout.addWidget(CaptionLabel('点击运行按钮启动工具，支持并发执行多个任务', self))
        
        # Auto-load scripts
        for path, title, desc in scan_scripts():
            card = ToolCard(path, title, desc, content)
            card.task_created.connect(lambda t: self.task_created.emit(t))
            layout.addWidget(card)
        
        scroll.setWidget(content)
        main_layout.addWidget(scroll)

# ==================== Main Window ====================

class Window(FluentWindow):
    def __init__(self):
        super().__init__()
        setTheme(Theme.AUTO)
        self._task_count = 0
        self._running_tasks = []
        
        self.tools = ToolsInterface(self)
        self.tools.task_created.connect(self._add_task)
        
        self.addSubInterface(self.tools, FIF.HOME, '工具')
        self.navigationInterface.setExpandWidth(100)
        
        self.resize(900, 680)
        self.setMinimumSize(600, 400)
        self.setWindowTitle('Windows 工具箱')
        
        # Center window
        screen = QApplication.primaryScreen().availableGeometry()
        self.move((screen.width() - self.width()) // 2, (screen.height() - self.height()) // 2)
    
    def closeEvent(self, event):
        """Clean up tmp directory on normal close."""
        # Terminate all running tasks
        for task in self._running_tasks:
            if task.process.state() == QProcess.Running:
                task.process.terminate()
                task.process.waitForFinished(2000)
        
        # Clean up tmp directory
        cleanup_tmp_dir()
        super().closeEvent(event)

    def _add_task(self, task):
        self._task_count += 1
        self._running_tasks.append(task)
        task.setParent(self)
        self.addSubInterface(task, FIF.PLAY, f'任务 {self._task_count}', NavigationItemPosition.SCROLL)
        self.switchTo(task)
        task.start()

# ==================== Entry Point ====================

if __name__ == '__main__':
    # Handle Ctrl+C gracefully
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    
    if not is_admin():
        run_as_admin()
        sys.exit()
    
    QApplication.setHighDpiScaleFactorRoundingPolicy(Qt.HighDpiScaleFactorRoundingPolicy.PassThrough)
    app = QApplication(sys.argv)
    Window().show()
    app.exec()
