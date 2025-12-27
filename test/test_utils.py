import os
import sys
import unittest
import shutil
from unittest.mock import MagicMock, patch

# 将父目录添加到路径以便导入 toolbox
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import toolbox

class TestWindowsToolsUtils(unittest.TestCase):
    def setUp(self):
        # 创建一个测试用的临时脚本目录
        self.test_dir = os.path.dirname(os.path.abspath(__file__))
        self.mock_scripts_dir = os.path.join(self.test_dir, "mock_scripts")
        if not os.path.exists(self.mock_scripts_dir):
            os.makedirs(self.mock_scripts_dir)
            
    def tearDown(self):
        # 清理测试目录
        if os.path.exists(self.mock_scripts_dir):
            shutil.rmtree(self.mock_scripts_dir)
        # 清理 toolbox 产生的临时目录
        toolbox.cleanup_tmp_dir()

    # ==================== parse_script_metadata 测试 ====================
    
    def test_parse_script_metadata_bat(self):
        """测试解析 .bat 脚本的标题和描述（:: 注释）"""
        bat_path = os.path.join(self.mock_scripts_dir, "test.bat")
        with open(bat_path, "w", encoding="utf-8") as f:
            f.write("@echo off\n")
            f.write(":: 测试标题\n")
            f.write(":: 测试描述内容\n")
            f.write("echo Hello\n")
            
        title, desc = toolbox.parse_script_metadata(bat_path)
        self.assertEqual(title, "测试标题")
        self.assertEqual(desc, "测试描述内容")

    def test_parse_script_metadata_bat_rem(self):
        """测试解析 .bat 脚本的标题和描述（REM 注释）"""
        bat_path = os.path.join(self.mock_scripts_dir, "test_rem.bat")
        with open(bat_path, "w", encoding="utf-8") as f:
            f.write("@echo off\n")
            f.write("REM 这是REM标题\n")
            f.write("REM 这是REM描述\n")
            f.write("echo Hello\n")
            
        title, desc = toolbox.parse_script_metadata(bat_path)
        self.assertEqual(title, "这是REM标题")
        self.assertEqual(desc, "这是REM描述")
        
    def test_parse_script_metadata_bat_rem_lowercase(self):
        """测试解析 .bat 脚本（小写 rem）"""
        bat_path = os.path.join(self.mock_scripts_dir, "test_rem_lower.bat")
        with open(bat_path, "w", encoding="utf-8") as f:
            f.write("@echo off\n")
            f.write("rem 小写rem标题\n")
            f.write("rem 小写rem描述\n")
            
        title, desc = toolbox.parse_script_metadata(bat_path)
        self.assertEqual(title, "小写rem标题")
        self.assertEqual(desc, "小写rem描述")

    def test_parse_script_metadata_ps1(self):
        """测试解析 .ps1 脚本的标题和描述"""
        ps1_path = os.path.join(self.mock_scripts_dir, "test.ps1")
        with open(ps1_path, "w", encoding="utf-8") as f:
            f.write("# 测试标题 PS1\n")
            f.write("# 这是描述内容\n")
            f.write("Write-Host 'Hello'\n")
            
        title, desc = toolbox.parse_script_metadata(ps1_path)
        self.assertEqual(title, "测试标题 PS1")
        self.assertEqual(desc, "这是描述内容")
        
    def test_parse_script_metadata_ps1_shebang(self):
        """测试解析 .ps1 脚本时跳过 shebang"""
        ps1_path = os.path.join(self.mock_scripts_dir, "test_shebang.ps1")
        with open(ps1_path, "w", encoding="utf-8") as f:
            f.write("#!/usr/bin/env pwsh\n")
            f.write("# 真正的标题\n")
            f.write("# 真正的描述\n")
            
        title, desc = toolbox.parse_script_metadata(ps1_path)
        self.assertEqual(title, "真正的标题")
        self.assertEqual(desc, "真正的描述")

    def test_parse_script_metadata_no_comments(self):
        """测试没有注释的脚本返回文件名"""
        bat_path = os.path.join(self.mock_scripts_dir, "no_comment.bat")
        with open(bat_path, "w", encoding="utf-8") as f:
            f.write("@echo off\n")
            f.write("echo Hello\n")
            
        title, desc = toolbox.parse_script_metadata(bat_path)
        self.assertEqual(title, "no_comment")
        self.assertEqual(desc, "")
        
    def test_parse_script_metadata_only_title(self):
        """测试只有标题没有描述"""
        bat_path = os.path.join(self.mock_scripts_dir, "only_title.bat")
        with open(bat_path, "w", encoding="utf-8") as f:
            f.write(":: 只有标题\n")
            f.write("echo Hello\n")
            
        title, desc = toolbox.parse_script_metadata(bat_path)
        self.assertEqual(title, "只有标题")
        self.assertEqual(desc, "")
        
    def test_parse_script_metadata_skip_separator(self):
        """测试跳过分隔符行（以=开头）"""
        bat_path = os.path.join(self.mock_scripts_dir, "with_separator.bat")
        with open(bat_path, "w", encoding="utf-8") as f:
            f.write(":: ===============\n")
            f.write(":: 真正的标题\n")
            f.write(":: ===============\n")
            f.write(":: 真正的描述\n")
            
        title, desc = toolbox.parse_script_metadata(bat_path)
        self.assertEqual(title, "真正的标题")
        self.assertEqual(desc, "真正的描述")
        
    def test_parse_script_metadata_empty_file(self):
        """测试空文件"""
        bat_path = os.path.join(self.mock_scripts_dir, "empty.bat")
        with open(bat_path, "w", encoding="utf-8") as f:
            f.write("")
            
        title, desc = toolbox.parse_script_metadata(bat_path)
        self.assertEqual(title, "empty")
        self.assertEqual(desc, "")

    # ==================== 目录函数测试 ====================
    
    def test_get_base_dir(self):
        """测试获取基础目录"""
        base_dir = toolbox.get_base_dir()
        self.assertTrue(os.path.exists(base_dir))
        
    def test_get_base_dir_meipass(self):
        """测试 PyInstaller 打包环境下的基础目录"""
        with patch.object(sys, '_MEIPASS', '/fake/meipass', create=True):
            base_dir = toolbox.get_base_dir()
            self.assertEqual(base_dir, '/fake/meipass')
        
    def test_get_scripts_dir(self):
        """测试获取脚本目录"""
        scripts_dir = toolbox.get_scripts_dir()
        self.assertIn("scripts", scripts_dir)
        
    def test_tmp_dir_creation_and_cleanup(self):
        """测试缓存目录创建和清理"""
        tmp_dir = toolbox.get_tmp_dir()
        self.assertTrue(os.path.exists(tmp_dir))
        self.assertTrue(os.path.isdir(tmp_dir))
        
        # 创建一个临时文件
        test_file = os.path.join(tmp_dir, "test.txt")
        with open(test_file, "w") as f:
            f.write("test")
        
        self.assertTrue(os.path.exists(test_file))
        
        # 清理
        toolbox.cleanup_tmp_dir()
        self.assertFalse(os.path.exists(tmp_dir))
        
    def test_cleanup_tmp_dir_not_exist(self):
        """测试清理不存在的临时目录"""
        # 确保临时目录不存在
        toolbox.cleanup_tmp_dir()
        # 再次调用不应该报错
        toolbox.cleanup_tmp_dir()  # Should not raise
        
    def test_cleanup_tmp_dir_error_handling(self):
        """测试清理临时目录时的错误处理"""
        tmp_dir = toolbox.get_tmp_dir()
        
        with patch('shutil.rmtree', side_effect=PermissionError("Cannot delete")):
            # 不应该抛出异常，而是打印错误信息
            toolbox.cleanup_tmp_dir()  # Should not raise

    # ==================== is_admin 测试 ====================
    
    def test_is_admin_true(self):
        """测试管理员权限为真"""
        with patch('ctypes.windll.shell32.IsUserAnAdmin', return_value=1):
            self.assertTrue(toolbox.is_admin())
            
    def test_is_admin_false(self):
        """测试管理员权限为假"""
        with patch('ctypes.windll.shell32.IsUserAnAdmin', return_value=0):
            self.assertFalse(toolbox.is_admin())
            
    def test_is_admin_exception(self):
        """测试管理员权限检查异常"""
        with patch('ctypes.windll.shell32.IsUserAnAdmin', side_effect=Exception("Error")):
            self.assertFalse(toolbox.is_admin())

    # ==================== scan_scripts 测试 ====================
    
    def test_scan_scripts(self):
        """测试扫描脚本功能"""
        # 准备模拟脚本
        bat_path = os.path.join(self.mock_scripts_dir, "script1.bat")
        with open(bat_path, "w", encoding="utf-8") as f:
            f.write(":: Script One\n:: Desc One")
            
        with patch('toolbox.get_scripts_dir', return_value=self.mock_scripts_dir):
            scripts = toolbox.scan_scripts()
            self.assertTrue(len(scripts) >= 1)
            # 找到我们的模拟脚本
            target = next((s for s in scripts if "script1.bat" in s[0]), None)
            self.assertIsNotNone(target)
            self.assertEqual(target[1], "Script One")
            self.assertEqual(target[2], "Desc One")
            
    def test_scan_scripts_skip_ps1_with_bat(self):
        """测试扫描时跳过有对应 bat 的 ps1 文件"""
        # 创建同名的 bat 和 ps1
        bat_path = os.path.join(self.mock_scripts_dir, "dual.bat")
        ps1_path = os.path.join(self.mock_scripts_dir, "dual.ps1")
        
        with open(bat_path, "w", encoding="utf-8") as f:
            f.write(":: BAT Script\n")
        with open(ps1_path, "w", encoding="utf-8") as f:
            f.write("# PS1 Script\n")
            
        with patch('toolbox.get_scripts_dir', return_value=self.mock_scripts_dir):
            scripts = toolbox.scan_scripts()
            # 应该只有 bat，没有 ps1
            paths = [s[0] for s in scripts]
            self.assertTrue(any("dual.bat" in p for p in paths))
            self.assertFalse(any("dual.ps1" in p for p in paths))
            
    def test_scan_scripts_cmd(self):
        """测试扫描 .cmd 文件"""
        cmd_path = os.path.join(self.mock_scripts_dir, "test.cmd")
        with open(cmd_path, "w", encoding="utf-8") as f:
            f.write(":: CMD Script\n:: CMD Desc")
            
        with patch('toolbox.get_scripts_dir', return_value=self.mock_scripts_dir):
            scripts = toolbox.scan_scripts()
            target = next((s for s in scripts if "test.cmd" in s[0]), None)
            self.assertIsNotNone(target)
            self.assertEqual(target[1], "CMD Script")
            
    def test_scan_scripts_empty_dir(self):
        """测试扫描空目录"""
        empty_dir = os.path.join(self.test_dir, "empty_scripts")
        os.makedirs(empty_dir, exist_ok=True)
        try:
            with patch('toolbox.get_scripts_dir', return_value=empty_dir):
                scripts = toolbox.scan_scripts()
                self.assertEqual(len(scripts), 0)
        finally:
            shutil.rmtree(empty_dir)
            
    def test_scan_scripts_sorted(self):
        """测试扫描结果按标题排序"""
        # 创建多个脚本
        for name, title in [("z_script.bat", "Zebra"), ("a_script.bat", "Apple"), ("m_script.bat", "Mango")]:
            path = os.path.join(self.mock_scripts_dir, name)
            with open(path, "w", encoding="utf-8") as f:
                f.write(f":: {title}\n")
                
        with patch('toolbox.get_scripts_dir', return_value=self.mock_scripts_dir):
            scripts = toolbox.scan_scripts()
            titles = [s[1] for s in scripts]
            self.assertEqual(titles, sorted(titles))

    # ==================== run_as_admin 测试 ====================
    
    def test_run_as_admin(self):
        """测试以管理员权限运行"""
        with patch('ctypes.windll.shell32.ShellExecuteW') as mock_shell:
            toolbox.run_as_admin()
            mock_shell.assert_called_once()


# ==================== GUI 组件测试 ====================

# 创建全局 QApplication 实例（GUI 测试必需）
_app = None

def get_app():
    """获取或创建 QApplication 实例"""
    global _app
    if _app is None:
        from PySide6.QtWidgets import QApplication
        _app = QApplication.instance() or QApplication([])
    return _app


class TestTerminalTextEdit(unittest.TestCase):
    """测试终端文本控件"""
    
    @classmethod
    def setUpClass(cls):
        cls.app = get_app()
        
    def test_terminal_readonly(self):
        """测试终端是只读的"""
        terminal = toolbox.TerminalTextEdit()
        self.assertTrue(terminal.isReadOnly())
        
    def test_terminal_append_text_default_color(self):
        """测试追加文本（默认颜色）"""
        terminal = toolbox.TerminalTextEdit()
        terminal.append_text("Hello World")
        self.assertIn("Hello World", terminal.toPlainText())
        
    def test_terminal_append_text_custom_color(self):
        """测试追加文本（自定义颜色）"""
        terminal = toolbox.TerminalTextEdit()
        terminal.append_text("Colored Text", "#ff0000")
        self.assertIn("Colored Text", terminal.toPlainText())
        
    def test_terminal_colors_dict(self):
        """测试终端颜色字典存在"""
        self.assertIn('31', toolbox.TerminalTextEdit.COLORS)
        self.assertIn('32', toolbox.TerminalTextEdit.COLORS)


class TestTaskInterface(unittest.TestCase):
    """测试任务界面"""
    
    @classmethod
    def setUpClass(cls):
        cls.app = get_app()
        cls.test_dir = os.path.dirname(os.path.abspath(__file__))
        
    def setUp(self):
        # 使用 mock 脚本进行测试
        self.mock_script = os.path.join(self.test_dir, "mock_script.bat")
        
    def test_task_interface_creation(self):
        """测试任务界面创建"""
        task = toolbox.TaskInterface("test_id", "Test Title", self.mock_script)
        self.assertEqual(task.task_id, "test_id")
        self.assertEqual(task.title, "Test Title")
        self.assertEqual(task.script_path, self.mock_script)
        
    def test_task_interface_initial_status(self):
        """测试任务界面初始状态"""
        task = toolbox.TaskInterface("test_id", "Test Title", self.mock_script)
        self.assertEqual(task.statusLabel.text(), "准备中...")
        
    def test_task_interface_copy_log_empty(self):
        """测试复制空日志"""
        task = toolbox.TaskInterface("test_id", "Test Title", self.mock_script)
        # 不应该抛出异常
        task._copy_log()
        
    def test_task_interface_on_output_utf8(self):
        """测试 UTF-8 输出处理"""
        task = toolbox.TaskInterface("test_id", "Test Title", self.mock_script)
        with patch.object(task.process, 'readAllStandardOutput') as mock_read:
            mock_read.return_value.data.return_value = "测试输出".encode('utf-8')
            task._on_output()
            self.assertIn("测试输出", task.terminal.toPlainText())
            
    def test_task_interface_on_output_gbk_fallback(self):
        """测试 GBK 编码回退"""
        task = toolbox.TaskInterface("test_id", "Test Title", self.mock_script)
        with patch.object(task.process, 'readAllStandardOutput') as mock_read:
            # 创建无效的 UTF-8 但有效的 GBK
            mock_read.return_value.data.return_value = "测试".encode('gbk')
            task._on_output()
            
    def test_task_interface_on_finished_success(self):
        """测试任务成功完成"""
        task = toolbox.TaskInterface("test_id", "Test Title", self.mock_script)
        task._on_finished(0, 0)  # exit_code=0
        self.assertIn("✅", task.statusLabel.text())
        
    def test_task_interface_on_finished_failure(self):
        """测试任务失败"""
        task = toolbox.TaskInterface("test_id", "Test Title", self.mock_script)
        task._on_finished(1, 0)  # exit_code=1
        self.assertIn("❌", task.statusLabel.text())
        
    def test_task_interface_start_bat(self):
        """测试启动 BAT 脚本"""
        task = toolbox.TaskInterface("test_id", "Test Title", self.mock_script)
        with patch.object(task.process, 'start') as mock_start:
            with patch.object(task.process, 'setProcessEnvironment'):
                task.start()
                mock_start.assert_called_once()
                # 验证是用 cmd 启动
                args = mock_start.call_args[0]
                self.assertEqual(args[0], 'cmd')
                
    def test_task_interface_start_ps1(self):
        """测试启动 PS1 脚本"""
        ps1_script = self.mock_script.replace('.bat', '.ps1')
        task = toolbox.TaskInterface("test_id", "Test Title", ps1_script)
        with patch.object(task.process, 'start') as mock_start:
            with patch.object(task.process, 'setProcessEnvironment'):
                task.start()
                mock_start.assert_called_once()
                # 验证是用 powershell 启动
                args = mock_start.call_args[0]
                self.assertEqual(args[0], 'powershell')


class TestToolCard(unittest.TestCase):
    """测试工具卡片"""
    
    @classmethod
    def setUpClass(cls):
        cls.app = get_app()
        cls.test_dir = os.path.dirname(os.path.abspath(__file__))
        
    def test_tool_card_creation(self):
        """测试工具卡片创建"""
        script_path = os.path.join(self.test_dir, "mock_script.bat")
        card = toolbox.ToolCard(script_path, "Test Tool", "Test Description")
        self.assertEqual(card.script_path, script_path)
        self.assertEqual(card.title, "Test Tool")
        
    def test_tool_card_creation_no_desc(self):
        """测试无描述的工具卡片"""
        script_path = os.path.join(self.test_dir, "mock_script.bat")
        card = toolbox.ToolCard(script_path, "Test Tool", "")
        self.assertEqual(card.title, "Test Tool")
        
    def test_tool_card_run_signal(self):
        """测试运行时发出信号"""
        script_path = os.path.join(self.test_dir, "mock_script.bat")
        card = toolbox.ToolCard(script_path, "Test Tool", "Desc")
        
        signal_received = []
        card.task_created.connect(lambda t: signal_received.append(t))
        card._run()
        
        self.assertEqual(len(signal_received), 1)
        self.assertIsInstance(signal_received[0], toolbox.TaskInterface)
        
    def test_tool_card_run_nonexistent_script(self):
        """测试运行不存在的脚本"""
        card = toolbox.ToolCard("/nonexistent/script.bat", "Test", "Desc")
        # Mock InfoBar.error 以避免需要有效的父窗口
        with patch('qfluentwidgets.InfoBar.error') as mock_error:
            with patch.object(card, 'window', return_value=MagicMock()):
                card._run()  # 不应该抛出异常
                mock_error.assert_called_once()
            

class TestToolsInterface(unittest.TestCase):
    """测试工具界面"""
    
    @classmethod
    def setUpClass(cls):
        cls.app = get_app()
        
    def test_tools_interface_creation(self):
        """测试工具界面创建"""
        with patch('toolbox.scan_scripts', return_value=[]):
            interface = toolbox.ToolsInterface()
            self.assertEqual(interface.objectName(), "ToolsInterface")
            
    def test_tools_interface_with_scripts(self):
        """测试有脚本时的工具界面"""
        test_dir = os.path.dirname(os.path.abspath(__file__))
        mock_script = os.path.join(test_dir, "mock_script.bat")
        
        with patch('toolbox.scan_scripts', return_value=[(mock_script, "Test", "Desc")]):
            interface = toolbox.ToolsInterface()
            self.assertEqual(interface.objectName(), "ToolsInterface")


class TestWindow(unittest.TestCase):
    """测试主窗口"""
    
    @classmethod
    def setUpClass(cls):
        cls.app = get_app()
        
    def test_window_creation(self):
        """测试主窗口创建"""
        with patch('toolbox.scan_scripts', return_value=[]):
            window = toolbox.Window()
            self.assertEqual(window.windowTitle(), "Windows 工具箱")
            self.assertEqual(window._task_count, 0)
            
    def test_window_add_task(self):
        """测试添加任务"""
        test_dir = os.path.dirname(os.path.abspath(__file__))
        mock_script = os.path.join(test_dir, "mock_script.bat")
        
        with patch('toolbox.scan_scripts', return_value=[]):
            window = toolbox.Window()
            
            task = toolbox.TaskInterface("test", "Test", mock_script)
            with patch.object(task, 'start'):  # 不实际启动进程
                window._add_task(task)
                
            self.assertEqual(window._task_count, 1)
            self.assertIn(task, window._running_tasks)
            
    def test_window_close_cleanup(self):
        """测试关闭窗口时清理"""
        with patch('toolbox.scan_scripts', return_value=[]):
            window = toolbox.Window()
            
            with patch('toolbox.cleanup_tmp_dir') as mock_cleanup:
                from PySide6.QtGui import QCloseEvent
                event = QCloseEvent()
                window.closeEvent(event)
                mock_cleanup.assert_called_once()
                
    def test_window_close_with_running_tasks(self):
        """测试关闭窗口时终止运行中的任务"""
        test_dir = os.path.dirname(os.path.abspath(__file__))
        mock_script = os.path.join(test_dir, "mock_script.bat")
        
        with patch('toolbox.scan_scripts', return_value=[]):
            window = toolbox.Window()
            
            # 添加一个任务
            task = toolbox.TaskInterface("test", "Test", mock_script)
            
            # Mock 进程为运行状态
            from PySide6.QtCore import QProcess
            with patch.object(task.process, 'state', return_value=QProcess.Running):
                with patch.object(task.process, 'terminate') as mock_terminate:
                    with patch.object(task.process, 'waitForFinished') as mock_wait:
                        with patch.object(task, 'start'):
                            window._add_task(task)
                        
                        with patch('toolbox.cleanup_tmp_dir'):
                            from PySide6.QtGui import QCloseEvent
                            event = QCloseEvent()
                            window.closeEvent(event)
                            
                        mock_terminate.assert_called_once()
                        mock_wait.assert_called_once_with(2000)


class TestParseMetadataException(unittest.TestCase):
    """测试元数据解析异常"""
    
    def setUp(self):
        self.test_dir = os.path.dirname(os.path.abspath(__file__))
        self.mock_scripts_dir = os.path.join(self.test_dir, "mock_scripts_exc")
        if not os.path.exists(self.mock_scripts_dir):
            os.makedirs(self.mock_scripts_dir)
            
    def tearDown(self):
        if os.path.exists(self.mock_scripts_dir):
            shutil.rmtree(self.mock_scripts_dir)
            
    def test_parse_script_metadata_exception(self):
        """测试解析元数据时发生异常"""
        # 创建一个文件然后 mock open 抛出异常
        bat_path = os.path.join(self.mock_scripts_dir, "error.bat")
        with open(bat_path, "w") as f:
            f.write(":: Test")
            
        with patch('builtins.open', side_effect=IOError("Test error")):
            title, desc = toolbox.parse_script_metadata(bat_path)
            # 应该返回文件名作为标题
            self.assertEqual(title, "error")
            self.assertEqual(desc, "")


class TestCopyLogWithContent(unittest.TestCase):
    """测试复制有内容的日志"""
    
    @classmethod  
    def setUpClass(cls):
        cls.app = get_app()
        
    def test_copy_log_with_content(self):
        """测试复制有内容的日志到剪贴板"""
        test_dir = os.path.dirname(os.path.abspath(__file__))
        mock_script = os.path.join(test_dir, "mock_script.bat")
        
        task = toolbox.TaskInterface("test", "Test", mock_script)
        # 添加一些文本到终端
        task.terminal.append_text("Some log content")
        
        # Mock InfoBar.success 和剪贴板
        with patch('qfluentwidgets.InfoBar.success') as mock_success:
            with patch.object(task, 'window', return_value=MagicMock()):
                task._copy_log()
                mock_success.assert_called_once()


if __name__ == "__main__":
    unittest.main()
