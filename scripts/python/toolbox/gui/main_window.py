# toolbox.gui.main_window - 主窗口和工具界面
# 主窗口、工具卡片、工具列表界面

import os
from PySide6.QtCore import Qt, QProcess, Signal
from PySide6.QtWidgets import QApplication, QWidget, QHBoxLayout, QVBoxLayout

from qfluentwidgets import (
    setTheme, Theme, FluentWindow, SubtitleLabel, CaptionLabel,
    PrimaryPushButton, FluentIcon as FIF, CardWidget, IconWidget,
    BodyLabel, InfoBar, SmoothScrollArea, NavigationItemPosition
)

from ..utils import scan_scripts, cleanup_tmp_dir
from .widgets import TaskInterface


class ToolCard(CardWidget):
    """工具卡片，显示单个脚本信息和运行按钮"""
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


class ToolsInterface(QWidget):
    """工具列表界面，展示所有可用脚本"""
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

        for path, title, desc in scan_scripts():
            card = ToolCard(path, title, desc, content)
            card.task_created.connect(lambda t: self.task_created.emit(t))
            layout.addWidget(card)

        scroll.setWidget(content)
        main_layout.addWidget(scroll)


class Window(FluentWindow):
    """主窗口"""
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

        screen = QApplication.primaryScreen().availableGeometry()
        self.move((screen.width() - self.width()) // 2, (screen.height() - self.height()) // 2)

    def closeEvent(self, event):
        """Clean up tmp directory on normal close."""
        for task in self._running_tasks:
            if task.process.state() == QProcess.Running:
                task.process.terminate()
                task.process.waitForFinished(2000)

        cleanup_tmp_dir()
        super().closeEvent(event)

    def _add_task(self, task):
        self._task_count += 1
        self._running_tasks.append(task)
        task.setParent(self)
        self.addSubInterface(task, FIF.PLAY, f'任务 {self._task_count}', NavigationItemPosition.SCROLL)
        self.switchTo(task)
        task.start()
