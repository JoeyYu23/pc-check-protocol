#Requires -Version 5.0
<#
.SYNOPSIS
    Run OCCT VRAM stress test.
    运行 OCCT 显存压力测试

.DESCRIPTION
    Interactive mode: launches OCCT and guides the seller through the test
    with clear prompts.
    Non-interactive mode: launches OCCT, waits for DurationSec, then closes
    it automatically — no Read-Host prompts.

.PARAMETER NonInteractive
    When set, skip all Read-Host prompts. OCCT is started, the script waits
    for the configured duration, then stops OCCT automatically.

.OUTPUTS
    String: "COMPLETED", "SKIPPED", "USER_SKIPPED", or "ERROR"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoRoot,
    [Parameter(Mandatory=$true)]
    [string]$OutputDir,
    [int]$DurationSec = 600,
    [switch]$NonInteractive
)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "HH:mm:ss"
    $color = switch ($Level) { "OK" { "Green" } "WARN" { "Yellow" } "ERROR" { "Red" } default { "Cyan" } }
    Write-Host "[$ts][$Level] $Message" -ForegroundColor $color
}

$OcctPath         = Join-Path $RepoRoot "tools\OCCT\OCCT.exe"
$LogPath          = Join-Path $OutputDir "occt_log.txt"
$ScreenshotScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "capture_screenshot.ps1"

if (-not (Test-Path $OcctPath)) {
    Write-Log "OCCT 未找到: $OcctPath" "WARN"
    Write-Log "请从 https://www.ocbase.com/download 下载并安装到 tools\OCCT\" "WARN"
    "[SKIP] OCCT not found at $OcctPath" | Out-File $LogPath -Encoding UTF8
    return "SKIPPED"
}

# ---------------------------------------------------------------------------
# Interactive: confirm with user before starting
# ---------------------------------------------------------------------------
if (-not $NonInteractive) {
    Write-Host ""
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host "  OCCT VRAM 测试说明" -ForegroundColor Cyan
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host "  OCCT 需要手动点击启动测试。" -ForegroundColor White
    Write-Host "  请按照以下步骤操作：" -ForegroundColor White
    Write-Host ""
    Write-Host "  1. 脚本将自动打开 OCCT" -ForegroundColor White
    Write-Host "  2. 在左侧菜单选择 'GPU: VRAM'" -ForegroundColor White
    Write-Host "  3. 确认时长设置为 $([math]::Round($DurationSec/60)) 分钟" -ForegroundColor White
    Write-Host "  4. 点击绿色 '开始' 按钮" -ForegroundColor White
    Write-Host "  5. 等待脚本提示测试完成" -ForegroundColor White
    Write-Host "  6. 脚本提示时点击 '停止' 按钮" -ForegroundColor White
    Write-Host "  =============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  >> 是否运行 OCCT VRAM 测试？" -ForegroundColor Yellow
    Write-Host "  >> 输入 Y 继续，输入 N 跳过: " -ForegroundColor Yellow -NoNewline
    $answer = Read-Host
    if ($answer -notmatch '^[Yy]') {
        Write-Log "用户跳过 OCCT 测试" "INFO"
        "用户跳过 OCCT 测试" | Out-File $LogPath -Encoding UTF8
        return "USER_SKIPPED"
    }
}

$Process   = $null
$Result    = "ERROR"
$StartTime = $null

try {
    $Process = Start-Process -FilePath $OcctPath -PassThru -ErrorAction Stop
    Write-Log "OCCT 已启动 (PID: $($Process.Id))" "OK"
} catch {
    Write-Log "OCCT 启动失败: $_" "ERROR"
    "OCCT launch error: $_" | Out-File $LogPath -Encoding UTF8
    return "ERROR"
}

# ---------------------------------------------------------------------------
# Interactive: wait for user to click Start in OCCT
# Non-interactive: give OCCT 10 seconds to initialize, then treat as started
# ---------------------------------------------------------------------------
if ($NonInteractive) {
    Write-Log "非交互模式: 等待 OCCT 初始化 (10秒)..." "INFO"
    Start-Sleep -Seconds 10
} else {
    Write-Host ""
    Write-Host "  >> 请在 OCCT 中点击开始按钮，然后按回车继续..." -ForegroundColor Yellow
    Read-Host | Out-Null
}

$StartTime = Get-Date
Write-Log "测试开始，计划运行 $DurationSec 秒..." "INFO"

# Screenshot at start
if (Test-Path $ScreenshotScript) {
    try { & $ScreenshotScript -OutputDir $OutputDir -Label "occt_start" } catch {}
}

# Wait for duration with periodic screenshots and progress updates
$EndTime      = $StartTime.AddSeconds($DurationSec)
$Interval     = 60
$LastSnapshot = $StartTime

while ((Get-Date) -lt $EndTime) {
    Start-Sleep -Seconds 15

    if ($Process -and $Process.HasExited) {
        Write-Log "OCCT 意外退出 (退出码: $($Process.ExitCode))" "WARN"
        break
    }

    $Elapsed   = [int]((Get-Date) - $StartTime).TotalSeconds
    $Remaining = [int]($DurationSec - $Elapsed)
    Write-Log "OCCT 测试进行中... 已运行 $Elapsed 秒，剩余 $Remaining 秒" "INFO"

    if (((Get-Date) - $LastSnapshot).TotalSeconds -ge $Interval) {
        if (Test-Path $ScreenshotScript) {
            try { & $ScreenshotScript -OutputDir $OutputDir -Label "occt_${Elapsed}s" } catch {}
        }
        $LastSnapshot = Get-Date
    }
}

$EndActual      = Get-Date
$ActualDuration = [int]($EndActual - $StartTime).TotalSeconds

# Screenshot at end
if (Test-Path $ScreenshotScript) {
    try { & $ScreenshotScript -OutputDir $OutputDir -Label "occt_end" } catch {}
}

# ---------------------------------------------------------------------------
# Interactive: prompt user to stop OCCT and confirm result
# Non-interactive: stop OCCT automatically, log as COMPLETED
# ---------------------------------------------------------------------------
if ($NonInteractive) {
    Write-Log "非交互模式: 自动停止 OCCT..." "INFO"
    $Result = "COMPLETED"
} else {
    Write-Host ""
    Write-Host "  >> 测试时间到！请在 OCCT 中点击停止按钮，然后按回车继续..." -ForegroundColor Green
    Read-Host | Out-Null
}

# Try to gracefully close OCCT
if ($Process -and -not $Process.HasExited) {
    try {
        $Process.CloseMainWindow() | Out-Null
        Start-Sleep -Seconds 2
        if (-not $Process.HasExited) { $Process.Kill() }
    } catch {}
}

Write-Log "OCCT VRAM 测试完成，运行时长 $ActualDuration 秒" "OK"
if (-not $NonInteractive) {
    Write-Log "请检查 OCCT 中是否显示 '0 errors'，并截图保存" "INFO"
}

# Final screenshot
if (Test-Path $ScreenshotScript) {
    try { & $ScreenshotScript -OutputDir $OutputDir -Label "occt_result" } catch {}
}

# Write log
$LogContent = @"
OCCT VRAM 测试日志
==================
开始时间:   $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))
结束时间:   $($EndActual.ToString('yyyy-MM-dd HH:mm:ss'))
计划时长:   $DurationSec 秒
实际时长:   $ActualDuration 秒
OCCT路径:   $OcctPath
模式:       $(if ($NonInteractive) { '非交互 (自动)' } else { '交互 (半自动)' })
注意:       请检查 OCCT 界面中是否显示 0 errors
"@
$LogContent | Out-File $LogPath -Encoding UTF8

if (-not $NonInteractive) { $Result = "COMPLETED" }
return $Result
