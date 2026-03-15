#Requires -Version 5.0
<#
.SYNOPSIS
    Memory Stability Test
    内存稳定性测试脚本

.DESCRIPTION
    Attempts to run OCCT Memory test. Falls back to a PowerShell-native
    large memory allocation + read/write test if OCCT is not available.

    OCCT path: semi-automatic — script launches OCCT and prompts seller to
    select the Memory test and click Start.

.PARAMETER RepoRoot
    Root directory of the pc-check-protocol repo.

.PARAMETER OutputDir
    Timestamped output directory for this test session.

.PARAMETER DurationSec
    Duration of the memory test in seconds. Default: 300.

.NOTES
    Output: memory_test_log.txt, screenshots memory_test_start / memory_test_end
#>

param(
    [Parameter(Mandatory)]
    [string]$RepoRoot,

    [Parameter(Mandatory)]
    [string]$OutputDir,

    [int]$DurationSec = 300
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

# ---------------------------------------------------------------------------
# Locate OCCT binary
# ---------------------------------------------------------------------------
$OcctPath = Join-Path $RepoRoot "tools\OCCT\OCCT.exe"
$LogPath  = Join-Path $OutputDir "memory_test_log.txt"

$LogLines = [System.Collections.Generic.List[string]]::new()
$LogLines.Add("Memory Stability Test Log")
$LogLines.Add("开始时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$LogLines.Add("计划时长: $DurationSec 秒")
$LogLines.Add("")

$StartTime = Get-Date

# ---------------------------------------------------------------------------
# Path A: OCCT available — semi-automatic
# ---------------------------------------------------------------------------
if (Test-Path $OcctPath) {
    Write-Log "找到 OCCT，使用 OCCT Memory 内存测试" "INFO"
    $LogLines.Add("测试方法: OCCT Memory 测试 (半自动)")

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  OCCT 内存稳定性测试 - 操作说明" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. OCCT 即将打开" -ForegroundColor White
    Write-Host "  2. 在左侧菜单选择 [Memory] 测试" -ForegroundColor White
    Write-Host "  3. 设置时长为 $DurationSec 秒 ($([math]::Round($DurationSec/60,1)) 分钟)" -ForegroundColor White
    Write-Host "  4. 点击 [开始] 按钮" -ForegroundColor White
    Write-Host "  5. 测试结束后，截图结果页面" -ForegroundColor White
    Write-Host "  6. 回到此窗口按 Enter 确认" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  按 Enter 启动 OCCT..." -ForegroundColor Gray
    $null = Read-Host

    Take-Screenshot -Label "memory_test_start"
    $LogLines.Add("截图: memory_test_start")

    try {
        $proc = Start-Process -FilePath $OcctPath -PassThru
        Write-Log "OCCT 已启动 (PID: $($proc.Id))" "INFO"
        $LogLines.Add("OCCT PID: $($proc.Id)")
    } catch {
        Write-Log "OCCT 启动失败: $_" "ERROR"
        $LogLines.Add("OCCT 启动失败: $_")
    }

    Write-Host ""
    Write-Host "  等待内存测试完成后，按 Enter 继续..." -ForegroundColor Yellow
    $null = Read-Host

    $EndTime = Get-Date
    $Elapsed = [int]($EndTime - $StartTime).TotalSeconds
    $LogLines.Add("结束时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $LogLines.Add("实际时长: $Elapsed 秒")

    Take-Screenshot -Label "memory_test_end"
    $LogLines.Add("截图: memory_test_end")

    Write-Host ""
    Write-Host "  OCCT 内存测试显示是否有错误？(输入 y=无错误/n=有错误): " -ForegroundColor White -NoNewline
    $answer = Read-Host
    if ($answer -match "^[yY]") {
        $LogLines.Add("测试结果: 通过 (卖家确认无错误)")
        $Result = "PASS"
    } else {
        $LogLines.Add("测试结果: 异常 (卖家报告有错误或测试未正常完成)")
        $Result = "WARN"
    }

    try {
        if ($proc -and -not $proc.HasExited) {
            $proc.CloseMainWindow() | Out-Null
            Start-Sleep -Seconds 2
            if (-not $proc.HasExited) { $proc.Kill() }
        }
    } catch {}

# ---------------------------------------------------------------------------
# Path B: No OCCT — PowerShell native memory allocation test
# ---------------------------------------------------------------------------
} else {
    Write-Log "未找到 OCCT，使用 PowerShell 内置内存压力测试" "WARN"
    $LogLines.Add("测试方法: PowerShell 内存分配/读写测试 (fallback)")

    # Get total physical memory (MB) and target ~50% for the test
    $TotalMemMB = 0
    try {
        $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($cs) { $TotalMemMB = [int]($cs.TotalPhysicalMemory / 1MB) }
    } catch {}
    if ($TotalMemMB -lt 1) { $TotalMemMB = 4096 }

    $TargetMB = [math]::Min([int]($TotalMemMB * 0.5), 4096)
    $ChunkMB  = 256
    $LogLines.Add("物理内存: $TotalMemMB MB")
    $LogLines.Add("测试分配量: $TargetMB MB (分 $([int]($TargetMB/$ChunkMB)) 块)")

    Write-Log "物理内存: $TotalMemMB MB，分配 $TargetMB MB 进行读写测试" "INFO"

    Take-Screenshot -Label "memory_test_start"
    $LogLines.Add("截图: memory_test_start")

    $ErrorCount   = 0
    $ChunkCount   = [int]($TargetMB / $ChunkMB)
    $BytesPerChunk = $ChunkMB * 1MB
    $Deadline     = (Get-Date).AddSeconds($DurationSec)
    $Pass         = 0

    Write-Log "开始内存读写循环测试，持续 $DurationSec 秒..." "STEP"
    Write-Host "  (按 Ctrl+C 可提前中止)" -ForegroundColor Gray

    try {
        while ((Get-Date) -lt $Deadline) {
            $Pass++
            $remaining = [int](($Deadline - (Get-Date)).TotalSeconds)
            Write-Progress -Activity "内存测试 Pass $Pass" `
                           -Status "剩余 $remaining 秒" `
                           -PercentComplete ([int](100 * ($DurationSec - $remaining) / $DurationSec))

            # Allocate, write pattern, read back and verify
            for ($c = 0; $c -lt $ChunkCount; $c++) {
                try {
                    $buf = New-Object byte[] $BytesPerChunk
                    # Write pattern: byte = (chunk_index XOR pass) mod 256
                    $pat = [byte](($c -bxor $Pass) % 256)
                    for ($b = 0; $b -lt $BytesPerChunk; $b += 4096) { $buf[$b] = $pat }
                    # Verify a sample of bytes
                    for ($b = 0; $b -lt $BytesPerChunk; $b += 4096) {
                        if ($buf[$b] -ne $pat) { $ErrorCount++ }
                    }
                    $buf = $null
                } catch {
                    $ErrorCount++
                }
            }
            [GC]::Collect()
        }
    } catch {
        Write-Log "内存测试异常: $_" "WARN"
        $LogLines.Add("异常: $_")
    }

    Write-Progress -Activity "内存测试" -Completed

    $EndTime = Get-Date
    $Elapsed = [int]($EndTime - $StartTime).TotalSeconds
    $LogLines.Add("结束时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $LogLines.Add("实际时长: $Elapsed 秒")
    $LogLines.Add("完成轮次: $Pass")
    $LogLines.Add("错误计数: $ErrorCount")

    Take-Screenshot -Label "memory_test_end"
    $LogLines.Add("截图: memory_test_end")

    if ($ErrorCount -eq 0) {
        Write-Log "内存测试通过，$Pass 轮无错误" "OK"
        $LogLines.Add("测试结果: 通过")
        $Result = "PASS"
    } else {
        Write-Log "内存测试发现 $ErrorCount 个错误，内存可能存在问题" "WARN"
        $LogLines.Add("测试结果: 异常 ($ErrorCount 错误)")
        $Result = "WARN"
    }
}

# ---------------------------------------------------------------------------
# Write log file
# ---------------------------------------------------------------------------
$LogLines.Add("")
$LogLines.Add("最终结果: $Result")
$LogLines | Out-File -FilePath $LogPath -Encoding UTF8
Write-Log "日志已保存: memory_test_log.txt" "OK"

return $Result
