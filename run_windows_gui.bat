@echo off
chcp 65001 >nul
title PC 验机工具
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\gui_launcher.ps1" -ScriptRoot "%~dp0scripts"
