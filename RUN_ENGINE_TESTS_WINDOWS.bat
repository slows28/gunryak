@echo off
setlocal
cd /d "%~dp0"
if not "%GODOT_BIN%"=="" (
  py -3 tools_run_engine_tests.py --godot "%GODOT_BIN%" --project "%CD%"
) else (
  py -3 tools_run_engine_tests.py --project "%CD%"
)
echo.
echo Test result file: test_results\engine_test_report.json
pause
