#Requires -Version 5.0
<#
.SYNOPSIS
    PC Check Protocol - Main Orchestrator
    二手电脑验机工具主脚本

.DESCRIPTION
    Interactive or non-interactive orchestration of the full PC verification
    workflow:
    1. Menu / -NonInteractive flag to select test items
    2. Create timestamped output directory
    3. Collect system information
    4. Check available tools
    5. Start HWiNFO sensor logging
    6. Run selected tests (GPU stress, VRAM, CPU stress, Memory, Disk SMART, Thermal)
    7. Stop HWiNFO logging
    8. Package results into zip

    SAFETY: This script only reads hardware data and runs benchmarks.
    It does NOT access personal files, upload data, or modify system settings.

.PARAMETER NonInteractive
    When set, skip all interactive menus and Read-Host prompts.
    Use -CustomTests to specify which tests to run.

.PARAMETER CustomTests
    Comma-separated list of test identifiers:
    "furmark", "vram", "cpu", "memory", "disk", "thermal"
    System info always runs. Example: -CustomTests "furmark,disk,cpu"

.NOTES
    Requires: PowerShell 5.0+, Windows 10/11
#>

param(
    [string]$ScriptRoot     = $PSScriptRoot,
    [switch]$NonInteractive,
    [string]$CustomTests    = ""   # comma-separated: "furmark,vram,cpu,memory,disk,thermal"
)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# Bootstrap: resolve paths
# ---------------------------------------------------------------------------
if (-not $ScriptRoot) { $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
$RepoRoot = Split-Path -Parent $ScriptRoot

# Load config
$ConfigPath = Join-Path $RepoRoot "config\benchmark_config.json"
if (-not (Test-Path $ConfigPath)) {
    Write-Host "[ERROR] Cannot find config\benchmark_config.json" -ForegroundColor Red
    exit 1
}
$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "Cyan" }
        "OK"      { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "STEP"    { "Magenta" }
        default   { "White" }
    }
    Write-Host "[$ts][$Level] $Message" -ForegroundColor $color
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor DarkCyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor DarkCyan
}

# ---------------------------------------------------------------------------
# Check admin privileges
# ---------------------------------------------------------------------------
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $IsAdmin) {
    Write-Log "Not running as Administrator. Some hardware readings may be limited." "WARN"
    Write-Log "For best results, right-click run_windows.bat and choose 'Run as Administrator'" "WARN"
    Write-Host ""
}

# ---------------------------------------------------------------------------
# Test flags
# ---------------------------------------------------------------------------
$RunFurmark       = $false
$RunOcctVram      = $false
$RunCpuStress     = $false
$RunMemoryTest    = $false
$RunDiskHealth    = $false
$RunThermalStress = $false

# ---------------------------------------------------------------------------
# Non-interactive mode: parse -CustomTests directly from GUI caller
# ---------------------------------------------------------------------------
if ($NonInteractive) {
    $MenuChoice = "custom"
    if ($CustomTests) {
        $selections = $CustomTests.ToLower() -split "," | ForEach-Object { $_.Trim() }
        if ($selections -contains "furmark")  { $RunFurmark       = $true }
        if ($selections -contains "vram")     { $RunOcctVram      = $true }
        if ($selections -contains "cpu")      { $RunCpuStress     = $true }
        if ($selections -contains "memory")   { $RunMemoryTest    = $true }
        if ($selections -contains "disk")     { $RunDiskHealth    = $true }
        if ($selections -contains "thermal")  { $RunThermalStress = $true }
    }
    Write-Log "非交互模式: CustomTests=$CustomTests" "INFO"

# ---------------------------------------------------------------------------
# Interactive menu (CLI mode — unchanged behavior)
# ---------------------------------------------------------------------------
} else {
    function Show-MainMenu {
        Clear-Host
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkCyan
        Write-Host "   PC 验机工具 v2.0  (PC Check Protocol)" -ForegroundColor Cyan
        Write-Host "   二手电脑交易验机 - 安全开源 不上传数据" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor DarkCyan
        Write-Host ""
        Write-Host "请选择要运行的测试项目 (输入编号，多选用逗号分隔，如: 2,3,5):" -ForegroundColor White
        Write-Host ""
        Write-Host "  [1] 电脑基本信息        (必选，自动包含)     约1分钟" -ForegroundColor Gray
        Write-Host "  [2] 硬盘健康度检查                          约1分钟" -ForegroundColor Yellow
        Write-Host "  [3] 显卡压力测试 (FurMark)                  约5分钟" -ForegroundColor Yellow
        Write-Host "  [4] 显存测试 (OCCT)                         约10分钟" -ForegroundColor Cyan
        Write-Host "  [5] CPU 压力测试                            约10分钟" -ForegroundColor Cyan
        Write-Host "  [6] 内存稳定性测试                           约5分钟" -ForegroundColor Cyan
        Write-Host "  [7] 散热综合测试                            约10分钟" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "  [A] 全选    [0] 退出" -ForegroundColor White
        Write-Host ""
        Write-Host "请输入: " -ForegroundColor White -NoNewline
    }

    $MenuChoice = $null
    while ($null -eq $MenuChoice) {
        Show-MainMenu
        $input = Read-Host
        $trimmed = $input.Trim().ToUpper()

        if ($trimmed -eq "0") {
            Write-Host ""
            Write-Host "已退出。" -ForegroundColor Gray
            exit 0
        } elseif ($trimmed -eq "A") {
            $RunFurmark       = $true
            $RunOcctVram      = $true
            $RunCpuStress     = $true
            $RunMemoryTest    = $true
            $RunDiskHealth    = $true
            $RunThermalStress = $true
            $MenuChoice       = "full"
        } else {
            $selections = $trimmed -split "," | ForEach-Object { $_.Trim() }
            if ($selections -contains "2") { $RunDiskHealth    = $true }
            if ($selections -contains "3") { $RunFurmark       = $true }
            if ($selections -contains "4") { $RunOcctVram      = $true }
            if ($selections -contains "5") { $RunCpuStress     = $true }
            if ($selections -contains "6") { $RunMemoryTest    = $true }
            if ($selections -contains "7") { $RunThermalStress = $true }
            $MenuChoice = "custom"
        }
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host "  即将运行的测试项目:" -ForegroundColor Cyan
    Write-Host "  [必选] 系统信息收集" -ForegroundColor White
    if ($RunDiskHealth)    { Write-Host "  [选中] 硬盘健康度检查"                            -ForegroundColor Yellow }
    if ($RunFurmark)       { Write-Host "  [选中] 显卡压力测试 (FurMark)"                    -ForegroundColor Yellow }
    if ($RunOcctVram)      { Write-Host "  [选中] 显存测试 (OCCT)"                           -ForegroundColor Cyan }
    if ($RunCpuStress)     { Write-Host "  [选中] CPU 压力测试"                              -ForegroundColor Cyan }
    if ($RunMemoryTest)    { Write-Host "  [选中] 内存稳定性测试"                            -ForegroundColor Cyan }
    if ($RunThermalStress) { Write-Host "  [选中] 散热综合测试 (CPU+GPU 同时满载)"           -ForegroundColor Magenta }
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Host "按 Enter 开始验机，或按 Ctrl+C 取消..." -ForegroundColor Gray
    $null = Read-Host
}

# ---------------------------------------------------------------------------
# Create timestamped output directory
# ---------------------------------------------------------------------------
$Timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$OutputBase = Join-Path $RepoRoot $Config.output_dir
$OutputDir  = Join-Path $OutputBase $Timestamp

try {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
} catch {
    Write-Host "[ERROR] Cannot create output directory: $OutputDir" -ForegroundColor Red
    exit 1
}

# ---------------------------------------------------------------------------
# Start transcript
# ---------------------------------------------------------------------------
$TranscriptPath = Join-Path $OutputDir "session_transcript.log"
try {
    Start-Transcript -Path $TranscriptPath -Append | Out-Null
} catch {
    Write-Host "[WARN] Could not start transcript: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  输出目录: $OutputDir" -ForegroundColor Gray
Write-Host ""

$SummaryLines = [System.Collections.Generic.List[string]]::new()
$SummaryLines.Add("PC Check Protocol - 验机报告摘要")
$SummaryLines.Add("模式: $MenuChoice")
$SummaryLines.Add("生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$SummaryLines.Add("输出目录: $OutputDir")
$SummaryLines.Add("")

# ---------------------------------------------------------------------------
# Step 1: Collect system info (always runs)
# ---------------------------------------------------------------------------
Write-Section "系统信息收集"
$CollectScript = Join-Path $ScriptRoot "collect_system_info.ps1"
try {
    & $CollectScript -OutputDir $OutputDir
    Write-Log "系统信息收集完成" "OK"
    $SummaryLines.Add("[OK] 系统信息 - 已收集 (system_info.txt)")
} catch {
    Write-Log "系统信息收集失败: $_" "ERROR"
    $SummaryLines.Add("[FAIL] 系统信息 - 收集失败")
}

# ---------------------------------------------------------------------------
# Step 2: Check tools
# ---------------------------------------------------------------------------
Write-Section "检查工具"
$CheckScript = Join-Path $ScriptRoot "check_tools.ps1"
$ToolStatus  = $null
try {
    $ToolStatus = & $CheckScript -RepoRoot $RepoRoot
    $SummaryLines.Add("工具检查结果:")
    foreach ($key in $ToolStatus.Keys) {
        $found = if ($ToolStatus[$key]) { "[找到]" } else { "[缺失]" }
        $SummaryLines.Add("  $found $key")
    }
} catch {
    Write-Log "工具检查失败: $_" "ERROR"
}

# ---------------------------------------------------------------------------
# Screenshot before tests
# ---------------------------------------------------------------------------
$ScreenshotScript = Join-Path $ScriptRoot "capture_screenshot.ps1"
if ($Config.screenshot_before_after) {
    Write-Section "截图 - 测试前"
    try {
        & $ScreenshotScript -OutputDir $OutputDir -Label "before_tests"
        Write-Log "测试前截图完成" "OK"
    } catch {
        Write-Log "截图失败 (非致命): $_" "WARN"
    }
}

# ---------------------------------------------------------------------------
# Start HWiNFO logging (if any sensor-dependent test is selected)
# ---------------------------------------------------------------------------
$NeedHWInfo    = $RunFurmark -or $RunOcctVram -or $RunCpuStress -or $RunThermalStress
$HWInfoScript  = Join-Path $ScriptRoot "run_hwinfo_logging.ps1"
$HWInfoStarted = $false

if ($NeedHWInfo) {
    Write-Section "启动 HWiNFO 传感器记录"
    if ($ToolStatus -and $ToolStatus["HWiNFO64"]) {
        try {
            . $HWInfoScript
            Start-HWiNFOLogging -RepoRoot $RepoRoot -OutputDir $OutputDir
            $HWInfoStarted = $true
            Write-Log "HWiNFO 传感器记录已启动" "OK"
            $SummaryLines.Add("[OK] HWiNFO 传感器记录 - 已启动")
        } catch {
            Write-Log "HWiNFO 启动失败: $_" "WARN"
            $SummaryLines.Add("[SKIP] HWiNFO 传感器记录 - 启动失败")
        }
    } else {
        Write-Log "HWiNFO64 不存在，跳过传感器记录" "WARN"
        $SummaryLines.Add("[SKIP] HWiNFO 传感器记录 - 工具未找到")
    }
    if ($HWInfoStarted) { Start-Sleep -Seconds 5 }
}

# ---------------------------------------------------------------------------
# GPU stress test (FurMark)
# ---------------------------------------------------------------------------
if ($RunFurmark) {
    Write-Section "GPU 压力测试 (FurMark)"
    $FurMarkScript = Join-Path $ScriptRoot "run_furmark.ps1"
    try {
        $result = & $FurMarkScript -RepoRoot $RepoRoot -OutputDir $OutputDir -DurationSec $Config.furmark_duration_sec
        $SummaryLines.Add("[结果] FurMark GPU压力: $result")
    } catch {
        Write-Log "FurMark 脚本异常: $_" "ERROR"
        $SummaryLines.Add("[FAIL] FurMark - 脚本异常")
    }
}

# ---------------------------------------------------------------------------
# VRAM test (OCCT)
# ---------------------------------------------------------------------------
if ($RunOcctVram) {
    Write-Section "VRAM 显存测试 (OCCT)"
    $OcctScript = Join-Path $ScriptRoot "run_occt.ps1"
    try {
        $result = & $OcctScript -RepoRoot $RepoRoot -OutputDir $OutputDir `
                      -DurationSec $Config.occt_vram_duration_sec `
                      -NonInteractive:$NonInteractive
        $SummaryLines.Add("[结果] OCCT VRAM: $result")
    } catch {
        Write-Log "OCCT VRAM 脚本异常: $_" "ERROR"
        $SummaryLines.Add("[FAIL] OCCT VRAM - 脚本异常")
    }
}

# ---------------------------------------------------------------------------
# CPU stress test
# ---------------------------------------------------------------------------
if ($RunCpuStress) {
    Write-Section "CPU 压力测试"
    $CpuStressScript = Join-Path $ScriptRoot "run_cpu_stress.ps1"
    try {
        $result = & $CpuStressScript -RepoRoot $RepoRoot -OutputDir $OutputDir `
                      -DurationSec $Config.occt_cpu_duration_sec `
                      -NonInteractive:$NonInteractive
        $SummaryLines.Add("[结果] CPU压力测试: $result")
    } catch {
        Write-Log "CPU压力测试脚本异常: $_" "ERROR"
        $SummaryLines.Add("[FAIL] CPU压力测试 - 脚本异常")
    }
}

# ---------------------------------------------------------------------------
# Memory stability test
# ---------------------------------------------------------------------------
if ($RunMemoryTest) {
    Write-Section "内存稳定性测试"
    $MemTestScript = Join-Path $ScriptRoot "run_memory_test.ps1"
    try {
        $result = & $MemTestScript -RepoRoot $RepoRoot -OutputDir $OutputDir `
                      -DurationSec $Config.occt_memory_duration_sec `
                      -NonInteractive:$NonInteractive
        $SummaryLines.Add("[结果] 内存测试: $result")
    } catch {
        Write-Log "内存测试脚本异常: $_" "ERROR"
        $SummaryLines.Add("[FAIL] 内存测试 - 脚本异常")
    }
}

# ---------------------------------------------------------------------------
# Disk SMART health check
# ---------------------------------------------------------------------------
if ($RunDiskHealth) {
    Write-Section "硬盘健康度检查"
    $DiskHealthScript = Join-Path $ScriptRoot "check_disk_health.ps1"
    try {
        $result = & $DiskHealthScript -RepoRoot $RepoRoot -OutputDir $OutputDir `
                      -NonInteractive:$NonInteractive
        $SummaryLines.Add("[结果] 硬盘健康检查: $result")
    } catch {
        Write-Log "硬盘健康检查脚本异常: $_" "ERROR"
        $SummaryLines.Add("[FAIL] 硬盘健康检查 - 脚本异常")
    }
}

# ---------------------------------------------------------------------------
# Thermal stress test (CPU + GPU simultaneous)
# ---------------------------------------------------------------------------
if ($RunThermalStress) {
    Write-Section "散热综合测试 (CPU+GPU 同时满载)"
    $ThermalScript = Join-Path $ScriptRoot "run_thermal_stress.ps1"
    try {
        $result = & $ThermalScript -RepoRoot $RepoRoot -OutputDir $OutputDir `
                      -DurationSec $Config.thermal_stress_duration_sec `
                      -NonInteractive:$NonInteractive
        $SummaryLines.Add("[结果] 散热综合测试: $result")
    } catch {
        Write-Log "散热测试脚本异常: $_" "ERROR"
        $SummaryLines.Add("[FAIL] 散热综合测试 - 脚本异常")
    }
}

# ---------------------------------------------------------------------------
# Stop HWiNFO logging
# ---------------------------------------------------------------------------
if ($HWInfoStarted) {
    Write-Log "停止 HWiNFO 传感器记录..." "INFO"
    try {
        Stop-HWiNFOLogging
        Write-Log "HWiNFO 记录已停止" "OK"
    } catch {
        Write-Log "停止 HWiNFO 失败 (非致命): $_" "WARN"
    }
}

# ---------------------------------------------------------------------------
# Screenshot after tests
# ---------------------------------------------------------------------------
if ($Config.screenshot_before_after) {
    Write-Section "截图 - 测试后"
    try {
        & $ScreenshotScript -OutputDir $OutputDir -Label "after_tests"
        Write-Log "测试后截图完成" "OK"
        $SummaryLines.Add("[OK] 截图 - 测试前后各一张")
    } catch {
        Write-Log "截图失败 (非致命): $_" "WARN"
    }
}

# ---------------------------------------------------------------------------
# Write summary
# ---------------------------------------------------------------------------
$SummaryLines.Add("")
$SummaryLines.Add("完成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$SummaryPath = Join-Path $OutputDir "test_summary.txt"
$SummaryLines | Out-File -FilePath $SummaryPath -Encoding UTF8

# ---------------------------------------------------------------------------
# Package results
# ---------------------------------------------------------------------------
if ($Config.zip_results) {
    Write-Section "打包结果"
    $PackageScript = Join-Path $ScriptRoot "package_results.ps1"
    try {
        & $PackageScript -OutputDir $OutputDir -Timestamp $Timestamp
    } catch {
        Write-Log "打包失败: $_" "ERROR"
    }
}

# ---------------------------------------------------------------------------
# Final message
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  验机完成！" -ForegroundColor Green
Write-Host "  结果目录: $OutputDir" -ForegroundColor White
if ($Config.zip_results) {
    $ZipPath = Join-Path $OutputBase "pc_check_$Timestamp.zip"
    Write-Host "  压缩包:   $ZipPath" -ForegroundColor White
}
Write-Host "  请将上述文件发送给买家核验" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Green

try { Stop-Transcript | Out-Null } catch {}
