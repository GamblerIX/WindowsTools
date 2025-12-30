# toolbox.gui.widgets - GUI 基础控件
# 终端文本控件和任务界面

from datetime import datetime
from PySide6.QtCore import Qt, QProcess, Signal, QProcessEnvironment
from PySide6.QtGui import QTextCursor, QColor, QTextCharFormat
from PySide6.QtWidgets import QApplication, QWidget, QHBoxLayout, QVBoxLayout, QTextEdit

from qfluentwidgets import (
    SubtitleLabel, CaptionLabel, PushButton, FluentIcon as FIF, InfoBar
)

from ..utils import get_tmp_dir


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


class TaskInterface(QWidget):
    """任务执行界面，显示脚本运行输出"""
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

        env = QProcessEnvironment.systemEnvironment()
        env.insert('TOOLBOX_TMP_DIR', get_tmp_dir())
        self.process.setProcessEnvironment(env)

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
