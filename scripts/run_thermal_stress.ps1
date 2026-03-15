#Requires -Version 5.0
<#
.SYNOPSIS
    Thermal Stress Test — CPU + GPU Simultaneous Load
    散热综合评估脚本

.DESCRIPTION
    Launches FurMark (GPU) and OCCT CPU stress simultaneously to test the
    system cooling under worst-case combined load. Records temperatures via
    HWiNFO CSV logging (if available).

    Timeline:
      T+0  min : Screenshot, launch FurMark + OCCT CPU
      T+5  min : Screenshot (mid-test temperatures)
      T+10 min : Screenshot, prompt seller to end tests

    If FurMark or OCCT are not present, the script falls back to a
    PowerShell GPU-free path (CPU-only stress) and notes the limitation.

.PARAMETER RepoRoot
    Root directory of the pc-check-protocol repo.

.PARAMETER OutputDir
    Timestamped output directory for this test session.

.PARAMETER DurationSec
    Total duration of the thermal stress test in seconds. Default: 600.

.NOTES
    Output: thermal_stress_log.txt, screenshots at 0/5/10 minute marks
#>

param(
    [Parameter(Mandatory)]
    [string]$RepoRoot,

    [Parameter(Mandatory)]
    [string]$OutputDir,

    [int]$DurationSec = 600
)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
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
        try {
            & $ScreenshotScript -OutputDir $OutputDir -Label $Label
        } catch {
            Write-Log "截图失败 (非致命): $_" "WARN"
        }
    }
}

$FurMarkPath = Join-Path $RepoRoot "tools\FurMark\FurMark.exe"
$OcctPath    = Join-Path $RepoRoot "tools\OCCT\OCCT.exe"
$LogPath     = Join-Path $OutputDir "thermal_stress_log.txt"

$LogLines = [System.Collections.Generic.List[string]]::new()
$LogLines.Add("Thermal Stress Test Log (CPU + GPU Combined)")
$LogLines.Add("开始时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$LogLines.Add("计划时长: $DurationSec 秒")
$LogLines.Add("")

$HasFurMark = Test-Path $FurMarkPath
$HasOcct    = Test-Path $OcctPath

$LogLines.Add("FurMark: $(if ($HasFurMark) { '找到' } else { '未找到 (仅 CPU 压力)' })")
$LogLines.Add("OCCT: $(if ($HasOcct) { '找到' } else { '未找到 (使用 PowerShell 压力)' })")
$LogLines.Add("")

# ---------------------------------------------------------------------------
# Instructions to seller
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "  散热综合评估 - CPU+GPU 同时满载测试" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  此测试同时对 CPU 和 GPU 施加满载，评估整机散热能力。" -ForegroundColor White
Write-Host "  测试过程中风扇会全速运转，这是正常现象。" -ForegroundColor White
Write-Host ""

if ($HasFurMark -and $HasOcct) {
    Write-Host "  操作步骤:" -ForegroundColor Cyan
    Write-Host "  1. FurMark 和 OCCT 将同时打开" -ForegroundColor White
    Write-Host "  2. 在 OCCT 中选择 [CPU] 测试并点击 [开始]" -ForegroundColor White
    Write-Host "  3. FurMark 会自动开始 GPU 压力测试" -ForegroundColor White
    Write-Host "  4. 请不要关闭任何窗口，等待 $([int]($DurationSec/60)) 分钟" -ForegroundColor White
    Write-Host "  5. 脚本将在 5 分钟和 $([int]($DurationSec/60)) 分钟时自动截图" -ForegroundColor White
    Write-Host "  6. 测试结束后回到此窗口按 Enter" -ForegroundColor Yellow
} elseif ($HasFurMark) {
    Write-Host "  [注意] 未找到 OCCT，将只运行 FurMark GPU 压力 + PowerShell CPU 压力" -ForegroundColor Yellow
} elseif ($HasOcct) {
    Write-Host "  [注意] 未找到 FurMark，将只运行 OCCT CPU 压力（无 GPU 烤机）" -ForegroundColor Yellow
} else {
    Write-Host "  [注意] FurMark 和 OCCT 均未找到，使用 PowerShell CPU 压力测试代替" -ForegroundColor Yellow
    Write-Host "  GPU 散热评估将无法进行，建议先运行 GPU 压力测试 (选项 2 或 3)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  按 Enter 开始散热评估..." -ForegroundColor Gray
$null = Read-Host

$StartTime  = Get-Date
$FurMarkProc = $null
$OcctProc    = $null
$CPUJobs     = @()

# ---------------------------------------------------------------------------
# Launch FurMark (GPU stress)
# ---------------------------------------------------------------------------
if ($HasFurMark) {
    Write-Log "启动 FurMark GPU 压力测试..." "STEP"
    try {
        # FurMark CLI: run fullscreen burn-in test
        $furArgs = @(
            "/nogui",
            "/width=1280",
            "/height=720",
            "/msaa=0",
            "/run_mode=1"     # 1 = GPU stress test
        )
        $FurMarkProc = Start-Process -FilePath $FurMarkPath -ArgumentList $furArgs -PassThru -ErrorAction Stop
        Write-Log "FurMark 已启动 (PID: $($FurMarkProc.Id))" "OK"
        $LogLines.Add("FurMark PID: $($FurMarkProc.Id)")
    } catch {
        Write-Log "FurMark 自动启动失败，尝试手动模式: $_" "WARN"
        try {
            $FurMarkProc = Start-Process -FilePath $FurMarkPath -PassThru
            Write-Log "FurMark 已以普通模式启动" "INFO"
            $LogLines.Add("FurMark 以普通模式启动 (PID: $($FurMarkProc.Id))")
        } catch {
            Write-Log "FurMark 启动失败: $_" "ERROR"
            $LogLines.Add("FurMark 启动失败: $_")
        }
    }
} else {
    Write-Log "FurMark 未找到，跳过 GPU 烤机" "WARN"
}

Start-Sleep -Seconds 3

# ---------------------------------------------------------------------------
# Launch OCCT CPU stress or PowerShell fallback
# ---------------------------------------------------------------------------
if ($HasOcct) {
    Write-Log "启动 OCCT CPU 压力测试..." "STEP"
    Write-Host ""
    Write-Host "  请在 OCCT 界面选择 [CPU] 测试并点击 [开始]..." -ForegroundColor Yellow
    try {
        $OcctProc = Start-Process -FilePath $OcctPath -PassThru
        Write-Log "OCCT 已启动 (PID: $($OcctProc.Id))" "OK"
        $LogLines.Add("OCCT PID: $($OcctProc.Id)")
    } catch {
        Write-Log "OCCT 启动失败: $_" "ERROR"
        $LogLines.Add("OCCT 启动失败: $_")
    }
} else {
    # PowerShell CPU fallback
    Write-Log "OCCT 未找到，启动 PowerShell CPU 压力线程..." "WARN"
    $CpuCount = [Environment]::ProcessorCount
    for ($i = 0; $i -lt $CpuCount; $i++) {
        $CPUJobs += Start-Job -ScriptBlock {
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
    Write-Log "$CpuCount 个 CPU 压力线程已启动" "OK"
    $LogLines.Add("PowerShell CPU 线程数: $CpuCount")
}

# ---------------------------------------------------------------------------
# Screenshot at T+0 (start)
# ---------------------------------------------------------------------------
Take-Screenshot -Label "thermal_start_t0"
$LogLines.Add("截图 T+0 分钟: thermal_start_t0")
Write-Log "截图 T+0 已保存" "OK"

# ---------------------------------------------------------------------------
# Wait until T+5 min, take mid screenshot
# ---------------------------------------------------------------------------
$MidPoint = 300  # 5 minutes in seconds
if ($MidPoint -lt $DurationSec) {
    Write-Log "等待 5 分钟后截图 (中段温度记录)..." "INFO"
    $MidDeadline = $StartTime.AddSeconds($MidPoint)
    $TotalSec    = $DurationSec

    while ((Get-Date) -lt $MidDeadline) {
        $remaining = [int](($MidDeadline - (Get-Date)).TotalSeconds)
        Write-Progress -Activity "散热评估进行中 (等待中段截图)" `
                       -Status "距中段截图还有 $remaining 秒" `
                       -PercentComplete ([int](100 * ($MidPoint - $remaining) / $MidPoint))
        Start-Sleep -Seconds 5
    }
    Write-Progress -Activity "散热评估" -Completed

    Take-Screenshot -Label "thermal_mid_t5min"
    $LogLines.Add("截图 T+5 分钟: thermal_mid_t5min")
    Write-Log "截图 T+5 分钟已保存" "OK"
}

# ---------------------------------------------------------------------------
# Wait until full duration
# ---------------------------------------------------------------------------
$EndDeadline = $StartTime.AddSeconds($DurationSec)
$Remaining   = [int](($EndDeadline - (Get-Date)).TotalSeconds)
if ($Remaining -gt 0) {
    Write-Log "继续等待直到 $([int]($DurationSec/60)) 分钟..." "INFO"
    while ((Get-Date) -lt $EndDeadline) {
        $rem = [int](($EndDeadline - (Get-Date)).TotalSeconds)
        Write-Progress -Activity "散热评估进行中" `
                       -Status "剩余 $rem 秒" `
                       -PercentComplete ([int](100 * ($DurationSec - $rem) / $DurationSec))
        Start-Sleep -Seconds 5
    }
    Write-Progress -Activity "散热评估" -Completed
}

# ---------------------------------------------------------------------------
# Screenshot at T+end
# ---------------------------------------------------------------------------
Take-Screenshot -Label "thermal_end_t$([int]($DurationSec/60))min"
$LogLines.Add("截图 T+$([int]($DurationSec/60)) 分钟: thermal_end")
Write-Log "截图结束段已保存" "OK"

# ---------------------------------------------------------------------------
# Stop all stress processes
# ---------------------------------------------------------------------------
Write-Log "停止所有压力进程..." "INFO"

if ($FurMarkProc -and -not $FurMarkProc.HasExited) {
    try {
        $FurMarkProc.CloseMainWindow() | Out-Null
        Start-Sleep -Seconds 2
        if (-not $FurMarkProc.HasExited) { $FurMarkProc.Kill() }
        Write-Log "FurMark 已停止" "OK"
    } catch { Write-Log "停止 FurMark 失败 (非致命): $_" "WARN" }
}

if ($OcctProc -and -not $OcctProc.HasExited) {
    try {
        $OcctProc.CloseMainWindow() | Out-Null
        Start-Sleep -Seconds 2
        if (-not $OcctProc.HasExited) { $OcctProc.Kill() }
        Write-Log "OCCT 已停止" "OK"
    } catch { Write-Log "停止 OCCT 失败 (非致命): $_" "WARN" }
}

if ($CPUJobs.Count -gt 0) {
    $CPUJobs | Stop-Job -ErrorAction SilentlyContinue
    $CPUJobs | Remove-Job -ErrorAction SilentlyContinue
    Write-Log "PowerShell CPU 压力线程已停止" "OK"
}

# ---------------------------------------------------------------------------
# Ask seller for temperature observation
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  测试完成。请问测试期间系统是否保持稳定？(y=稳定/n=出现问题): " -ForegroundColor White -NoNewline
$answer = Read-Host

$EndTime = Get-Date
$Elapsed = [int]($EndTime - $StartTime).TotalSeconds
$LogLines.Add("结束时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$LogLines.Add("实际时长: $Elapsed 秒")

if ($answer -match "^[yY]") {
    $LogLines.Add("测试结果: 通过 (散热系统稳定)")
    $Result = "PASS"
    Write-Log "散热综合评估完成，系统稳定" "OK"
} else {
    $LogLines.Add("测试结果: 异常 (卖家报告测试期间出现问题)")
    $Result = "WARN"
    Write-Log "散热综合评估：卖家报告异常" "WARN"
}

# Reminder: check HWiNFO CSV for temperature curves
$LogLines.Add("")
$LogLines.Add("提示: 如果 HWiNFO 已记录传感器数据，")
$LogLines.Add("      请用 Excel 打开 hwinfo_sensors.csv 分析温度曲线")

# ---------------------------------------------------------------------------
# Write log file
# ---------------------------------------------------------------------------
$LogLines.Add("")
$LogLines.Add("最终结果: $Result")
$LogLines | Out-File -FilePath $LogPath -Encoding UTF8
Write-Log "日志已保存: thermal_stress_log.txt" "OK"

return $Result
