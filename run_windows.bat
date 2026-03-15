@echo off
chcp 65001 >nul
title PC验机工具 - PC Check Protocol

echo ============================================================
echo    PC 验机工具 v2.0  (PC Check Protocol)
echo    二手电脑交易验机 - 安全开源 不上传数据
echo ============================================================
echo.
echo 正在启动验机程序，请稍候...
echo.

:: Check if running from the right directory
if not exist "%~dp0scripts\run_windows.ps1" (
    echo [错误] 找不到 scripts\run_windows.ps1
    echo 请确保从项目根目录运行此脚本
    pause
    exit /b 1
)

:: Launch PowerShell with execution policy bypass
:: -NoProfile: don't load user profile (faster, more predictable)
:: -ExecutionPolicy Bypass: allow running unsigned local scripts
:: -File: run the specified script file
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\run_windows.ps1" -ScriptRoot "%~dp0"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [警告] 脚本退出时出现错误 (代码: %ERRORLEVEL%)
    echo 请查看 output\ 目录中的日志文件
)

echo.
echo 验机程序已完成，按任意键退出...
pause >nul
