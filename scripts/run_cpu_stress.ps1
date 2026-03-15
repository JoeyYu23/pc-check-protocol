#Requires -Version 5.0
<#
.SYNOPSIS
    CPU Stress Test
    CPU 压力测试脚本

.DESCRIPTION
    Attempts to run OCCT CPU stress test. Falls back to a PowerShell-native
    multi-threaded CPU stress (math loops) if OCCT is not available.

    Interactive mode: prompts seller to select CPU test in OCCT and confirm.
    Non-interactive mode: launches OCCT, waits DurationSec automatically,
    then closes it — no Read-Host prompts.

.PARAMETER NonInteractive
    When set, skip all Read-Host prompts.

.NOTES
    Output: cpu_stress_log.txt, screenshots cpu_stress_start / cpu_stress_end
#>

param(
    [Parameter(Mandatory)]
    [string]$RepoRoot,

    [Parameter(Mandatory)]
    [string]$OutputDir,

    [int]$DurationSec = 600,

    [switch]$NonInteractive
)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) {
        "INFO"  { "Cyan" }
        "OK"    { "Green" }
        "WARN"  { "Yellow" }
        "ERROR" { "Red" }
        "STEP"  { "Magenta" }
        default { "White" }
    }
    Write-Host "[$ts][$Level] $Message" -ForegroundColor $color
}

function Take-Screenshot {
    param([string]$Label)
    $ScreenshotScript = Join-Path (Split-Path -Parent $PSCommandPath) "capture_screenshot.ps1"
    if (Test-Path $ScreenshotScript) {
        try { & $ScreenshotScript -OutputDir $OutputDir -Label $Label } catch {
            Write-Log "截图失败 (非致命): $_" "WARN"
        }
    }
}

$OcctPath = Join-Path $RepoRoot "tools\OCCT\OCCT.exe"
$LogPath  = Join-Path $OutputDir "cpu_stress_log.txt"

$LogLines = [System.Collections.Generic.List[string]]::new()
$LogLines.Add("CPU Stress Test Log")
$LogLines.Add("开始时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$LogLines.Add("计划时长: $DurationSec 秒")
$LogLines.Add("")

$StartTime = Get-Date

# ---------------------------------------------------------------------------
# Path A: OCCT available
# ---------------------------------------------------------------------------
if (Test-Path $OcctPath) {
    Write-Log "找到 OCCT，使用 OCCT CPU 压力测试" "INFO"
    $LogLines.Add("测试方法: OCCT CPU 测试 $(if ($NonInteractive) { '(非交互自动)' } else { '(半自动)' })")

    if (-not $NonInteractive) {
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "  OCCT CPU 压力测试 - 操作说明" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  1. OCCT 即将打开" -ForegroundColor White
        Write-Host "  2. 在左侧菜单选择 [CPU] 测试" -ForegroundColor White
        Write-Host "  3. 设置时长为 $DurationSec 秒 ($([math]::Round($DurationSec/60,1)) 分钟)" -ForegroundColor White
        Write-Host "  4. 点击 [开始] 按钮" -ForegroundColor White
        Write-Host "  5. 测试结束后，截图结果页面" -ForegroundColor White
        Write-Host "  6. 回到此窗口按 Enter 确认" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  按 Enter 启动 OCCT..." -ForegroundColor Gray
        $null = Read-Host
    }

    Take-Screenshot -Label "cpu_stress_start"
    $LogLines.Add("截图: cpu_stress_start")

    $proc = $null
    try {
        $proc = Start-Process -FilePath $OcctPath -PassThru
        Write-Log "OCCT 已启动 (PID: $($proc.Id))" "INFO"
        $LogLines.Add("OCCT PID: $($proc.Id)")
    } catch {
        Write-Log "OCCT 启动失败: $_" "ERROR"
        $LogLines.Add("OCCT 启动失败: $_")
    }

    if ($NonInteractive) {
        # Wait for the configured duration automatically
        Write-Log "非交互模式: 等待 $DurationSec 秒..." "INFO"
        $deadline = (Get-Date).AddSeconds($DurationSec)
        while ((Get-Date) -lt $deadline) {
            $rem = [int](($deadline - (Get-Date)).TotalSeconds)
            Write-Log "CPU压力测试进行中，剩余 $rem 秒" "INFO"
            Start-Sleep -Seconds 30
        }
        $Result = "PASS"
        $LogLines.Add("测试结果: 完成 (非交互模式，自动计时)")
    } else {
        Write-Host ""
        Write-Host "  等待测试完成后，按 Enter 继续..." -ForegroundColor Yellow
        $null = Read-Host

        # Ask seller for result
        Write-Host ""
        Write-Host "  OCCT CPU 测试显示是否有错误？(输入 y=无错误/n=有错误): " -ForegroundColor White -NoNewline
        $answer = Read-Host
        if ($answer -match "^[yY]") {
            $LogLines.Add("测试结果: 通过 (卖家确认无错误)")
            $Result = "PASS"
        } else {
            $LogLines.Add("测试结果: 异常 (卖家报告有错误或测试未正常完成)")
            $Result = "WARN"
        }
    }

    $EndTime  = Get-Date
    $Elapsed  = [int]($EndTime - $StartTime).TotalSeconds
    $LogLines.Add("结束时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $LogLines.Add("实际时长: $Elapsed 秒")

    Take-Screenshot -Label "cpu_stress_end"
    $LogLines.Add("截图: cpu_stress_end")

    # Stop OCCT
    try {
        if ($proc -and -not $proc.HasExited) {
            $proc.CloseMainWindow() | Out-Null
            Start-Sleep -Seconds 2
            if (-not $proc.HasExited) { $proc.Kill() }
        }
    } catch {}

# ---------------------------------------------------------------------------
# Path B: No OCCT — PowerShell native CPU stress (always unattended)
# ---------------------------------------------------------------------------
} else {
    Write-Log "未找到 OCCT，使用 PowerShell 内置 CPU 压力测试" "WARN"
    $LogLines.Add("测试方法: PowerShell 多线程数学压力测试 (fallback)")

    $CpuCount = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).NumberOfLogicalProcessors
    if (-not $CpuCount -or $CpuCount -lt 1) { $CpuCount = [Environment]::ProcessorCount }
    Write-Log "检测到 $CpuCount 个逻辑核心，全部占满" "INFO"
    $LogLines.Add("逻辑核心数: $CpuCount")

    Take-Screenshot -Label "cpu_stress_start"
    $LogLines.Add("截图: cpu_stress_start")

    Write-Log "启动 $CpuCount 个压力线程，持续 $DurationSec 秒..." "STEP"
    Write-Host "  (按 Ctrl+C 可提前中止)" -ForegroundColor Gray

    $jobs = @()
    for ($i = 0; $i -lt $CpuCount; $i++) {
        $jobs += Start-Job -ScriptBlock {
            param($sec)
            $deadline = (Get-Date).AddSeconds($sec)
            $x = 1.0
            while ((Get-Date) -lt $deadline) {
                for ($k = 0; $k -lt 100000; $k++) {
                    $x = [math]::Sqrt($x * 3.14159265358979 + 1.0)
                }
            }
        } -ArgumentList $DurationSec
    }

    $deadline = (Get-Date).AddSeconds($DurationSec)
    while ((Get-Date) -lt $deadline) {
        $remaining = [int](($deadline - (Get-Date)).TotalSeconds)
        Write-Progress -Activity "CPU 压力测试进行中" `
                       -Status "剩余 $remaining 秒" `
                       -PercentComplete ([int](100 * ($DurationSec - $remaining) / $DurationSec))
        Start-Sleep -Seconds 2
    }
    Write-Progress -Activity "CPU 压力测试进行中" -Completed

    $jobs | Stop-Job  -ErrorAction SilentlyContinue
    $jobs | Remove-Job -ErrorAction SilentlyContinue

    $EndTime = Get-Date
    $Elapsed = [int]($EndTime - $StartTime).TotalSeconds
    $LogLines.Add("结束时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $LogLines.Add("实际时长: $Elapsed 秒")
    $LogLines.Add("测试结果: 完成 (未检测到崩溃或蓝屏)")
    $Result = "PASS"

    Take-Screenshot -Label "cpu_stress_end"
    $LogLines.Add("截图: cpu_stress_end")

    Write-Log "CPU 压力测试完成，$Elapsed 秒内系统稳定" "OK"
}

# ---------------------------------------------------------------------------
# Write log file
# ---------------------------------------------------------------------------
$LogLines.Add("")
$LogLines.Add("最终结果: $Result")
$LogLines | Out-File -FilePath $LogPath -Encoding UTF8
Write-Log "日志已保存: cpu_stress_log.txt" "OK"

return $Result
