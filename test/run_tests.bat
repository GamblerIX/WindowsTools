@echo off
pushd %~dp0..
echo ============================================
echo   Running Tests with Coverage
echo ============================================

:: 运行测试并收集覆盖率数据
python -m coverage erase
python -m coverage run --rcfile=test/.coveragerc -m unittest test/test_utils.py

:: 生成控制台报告
echo.
echo Test Coverage Report:
python -m coverage report --rcfile=test/.coveragerc --include=toolbox.py -m

python -m coverage html --rcfile=test/.coveragerc

echo.
echo ============================================
echo   Coverage report generated in 'htmlcov' folder.
echo ============================================
popd
