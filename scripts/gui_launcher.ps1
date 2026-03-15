#Requires -Version 5.0
<#
.SYNOPSIS
    PC 验机工具 v2.0 - 图形界面启动器

.DESCRIPTION
    WinForms GUI for pc-check-protocol. Sellers double-click this
    instead of the batch file. Runs tests in a background runspace
    so the UI stays responsive.

    Design: checkbox-only, no mode radio buttons.
    SAFETY: No network access, no personal file access, no uploads.

.PARAMETER ScriptRoot
    Path to the scripts/ directory. Defaults to the directory containing
    this file. Passed automatically by run_windows_gui.bat.

.NOTES
    Requires PowerShell 5.1 (Windows 10/11 built-in)
    Uses System.Windows.Forms and System.Drawing (.NET Framework)
#>

param(
    [string]$ScriptRoot = $PSScriptRoot
)

Set-StrictMode -Off
$ErrorActionPreference = "Continue"

# ---------------------------------------------------------------------------
# Load WinForms assemblies
# ---------------------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
if (-not $ScriptRoot) {
    $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$RepoRoot = Split-Path -Parent $ScriptRoot

# ---------------------------------------------------------------------------
# Color / font constants
# ---------------------------------------------------------------------------
$ColorBlue      = [System.Drawing.Color]::FromArgb(33, 150, 243)   # #2196F3
$ColorGreen     = [System.Drawing.Color]::FromArgb(76, 175, 80)    # #4CAF50
$ColorGreenDark = [System.Drawing.Color]::FromArgb(56, 142, 60)    # darker green
$ColorGray      = [System.Drawing.Color]::FromArgb(158, 158, 158)  # gray buttons
$ColorLogBg     = [System.Drawing.Color]::FromArgb(18, 18, 18)     # near-black log bg
$ColorLogFg     = [System.Drawing.Color]::FromArgb(204, 255, 204)  # light green log text
$ColorWhite     = [System.Drawing.Color]::White
$ColorDimText   = [System.Drawing.Color]::FromArgb(120, 120, 120)  # dim description text
$ColorDisabled  = [System.Drawing.Color]::FromArgb(200, 200, 200)  # disabled checkbox color

$FontMain    = New-Object System.Drawing.Font("Microsoft YaHei UI", 10)
$FontHeader  = New-Object System.Drawing.Font("Microsoft YaHei UI", 13, [System.Drawing.FontStyle]::Bold)
$FontSub     = New-Object System.Drawing.Font("Microsoft YaHei UI", 8)
$FontDesc    = New-Object System.Drawing.Font("Microsoft YaHei UI", 8)
$FontButton  = New-Object System.Drawing.Font("Microsoft YaHei UI", 11, [System.Drawing.FontStyle]::Bold)
$FontLog     = New-Object System.Drawing.Font("Consolas", 9)
$FontTime    = New-Object System.Drawing.Font("Microsoft YaHei UI", 9, [System.Drawing.FontStyle]::Bold)

# ---------------------------------------------------------------------------
# Test item durations (seconds)
# ---------------------------------------------------------------------------
$DurationDisk    = 60
$DurationGpu     = 300
$DurationVram    = 600
$DurationCpu     = 600
$DurationMemory  = 300
$DurationThermal = 600

# ---------------------------------------------------------------------------
# Main form (fixed size, expanded when progress is shown)
# ---------------------------------------------------------------------------
$Form = New-Object System.Windows.Forms.Form
$Form.Text            = "PC 验机工具 v2.0"
$Form.Size            = New-Object System.Drawing.Size(550, 680)
$Form.MinimumSize     = New-Object System.Drawing.Size(550, 680)
$Form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$Form.MaximizeBox     = $false
$Form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
$Form.BackColor       = $ColorWhite
$Form.Font            = $FontMain

# ---------------------------------------------------------------------------
# 1. Header panel (blue, 55px)
# ---------------------------------------------------------------------------
$PanelHeader = New-Object System.Windows.Forms.Panel
$PanelHeader.Location  = New-Object System.Drawing.Point(0, 0)
$PanelHeader.Size      = New-Object System.Drawing.Size(550, 55)
$PanelHeader.BackColor = $ColorBlue

$LabelTitle = New-Object System.Windows.Forms.Label
$LabelTitle.Text      = "PC 验机工具 v2.0"
$LabelTitle.Font      = $FontHeader
$LabelTitle.ForeColor = $ColorWhite
$LabelTitle.Location  = New-Object System.Drawing.Point(16, 6)
$LabelTitle.Size      = New-Object System.Drawing.Size(520, 26)
$LabelTitle.BackColor = [System.Drawing.Color]::Transparent

$LabelSubtitle = New-Object System.Windows.Forms.Label
$LabelSubtitle.Text      = "安全开源  ·  不联网  ·  不碰个人文件"
$LabelSubtitle.Font      = $FontSub
$LabelSubtitle.ForeColor = $ColorWhite
$LabelSubtitle.Location  = New-Object System.Drawing.Point(18, 34)
$LabelSubtitle.Size      = New-Object System.Drawing.Size(520, 16)
$LabelSubtitle.BackColor = [System.Drawing.Color]::Transparent

$PanelHeader.Controls.Add($LabelTitle)
$PanelHeader.Controls.Add($LabelSubtitle)
$Form.Controls.Add($PanelHeader)

# ---------------------------------------------------------------------------
# 2. Checkbox GroupBox
# ---------------------------------------------------------------------------
$GroupTests = New-Object System.Windows.Forms.GroupBox
$GroupTests.Text     = "请勾选要运行的测试项目"
$GroupTests.Location = New-Object System.Drawing.Point(16, 68)
$GroupTests.Size     = New-Object System.Drawing.Size(516, 490)
$GroupTests.Font     = $FontMain
$Form.Controls.Add($GroupTests)

# ---------------------------------------------------------------------------
# Helper: create one checkbox row (checkbox + description label)
# Returns @{ Checkbox = ...; Label = ... }
# ---------------------------------------------------------------------------
function New-TestRow {
    param(
        [System.Windows.Forms.GroupBox]$Parent,
        [int]$TopY,
        [string]$CheckText,
        [string]$TimeHint,
        [string]$Description,
        [bool]$Checked = $false,
        [bool]$Disabled = $false
    )

    # Checkbox line: "☑ 电脑基本信息    [必选] 约1分钟"
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text     = $CheckText
    $chk.Location = New-Object System.Drawing.Point(14, $TopY)
    $chk.Size     = New-Object System.Drawing.Size(300, 22)
    $chk.Font     = $FontMain
    $chk.Checked  = $Checked
    if ($Disabled) {
        $chk.Enabled   = $false
        $chk.ForeColor = $ColorDimText
    }

    # Right-aligned time hint
    $lblTime = New-Object System.Windows.Forms.Label
    $lblTime.Text      = $TimeHint
    $lblTime.Font      = $FontDesc
    $lblTime.ForeColor = $ColorDimText
    $lblTime.Location  = New-Object System.Drawing.Point(320, ($TopY + 3))
    $lblTime.Size      = New-Object System.Drawing.Size(180, 18)
    $lblTime.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight

    # Description sub-line
    $lblDesc = New-Object System.Windows.Forms.Label
    $lblDesc.Text      = $Description
    $lblDesc.Font      = $FontDesc
    $lblDesc.ForeColor = $ColorDimText
    $lblDesc.Location  = New-Object System.Drawing.Point(32, ($TopY + 22))
    $lblDesc.Size      = New-Object System.Drawing.Size(468, 16)

    $Parent.Controls.Add($chk)
    $Parent.Controls.Add($lblTime)
    $Parent.Controls.Add($lblDesc)

    return @{ Checkbox = $chk; LabelTime = $lblTime; LabelDesc = $lblDesc }
}

# Separator line helper
function Add-Separator {
    param([System.Windows.Forms.GroupBox]$Parent, [int]$Y)
    $sep = New-Object System.Windows.Forms.Label
    $sep.Location  = New-Object System.Drawing.Point(14, $Y)
    $sep.Size      = New-Object System.Drawing.Size(486, 1)
    $sep.BackColor = [System.Drawing.Color]::FromArgb(220, 220, 220)
    $Parent.Controls.Add($sep)
}

# Row layout: each row = 22px checkbox + 16px desc + 12px gap = 50px per item
$rowHeight = 50
$startY    = 22

$rowSysInfo = New-TestRow -Parent $GroupTests -TopY $startY `
    -CheckText "电脑基本信息" `
    -TimeHint "[必选]  约1分钟" `
    -Description "读取 CPU/显卡/内存/主板型号" `
    -Checked $true -Disabled $true

Add-Separator -Parent $GroupTests -Y ($startY + $rowHeight - 3)

$rowDisk = New-TestRow -Parent $GroupTests -TopY ($startY + $rowHeight) `
    -CheckText "硬盘健康度检查" `
    -TimeHint "约1分钟" `
    -Description "检查硬盘是否有坏道、用了多久、剩余寿命" `
    -Checked $true

Add-Separator -Parent $GroupTests -Y ($startY + $rowHeight * 2 - 3)

$rowGpu = New-TestRow -Parent $GroupTests -TopY ($startY + $rowHeight * 2) `
    -CheckText "显卡压力测试" `
    -TimeHint "约5分钟" `
    -Description "让显卡全力运行，测试是否稳定不崩溃" `
    -Checked $false

Add-Separator -Parent $GroupTests -Y ($startY + $rowHeight * 3 - 3)

$rowVram = New-TestRow -Parent $GroupTests -TopY ($startY + $rowHeight * 3) `
    -CheckText "显存测试" `
    -TimeHint "约10分钟" `
    -Description "测试显卡内存是否有坏点" `
    -Checked $false

Add-Separator -Parent $GroupTests -Y ($startY + $rowHeight * 4 - 3)

$rowCpu = New-TestRow -Parent $GroupTests -TopY ($startY + $rowHeight * 4) `
    -CheckText "CPU 压力测试" `
    -TimeHint "约10分钟" `
    -Description "让CPU全力运行，测温度和稳定性" `
    -Checked $false

Add-Separator -Parent $GroupTests -Y ($startY + $rowHeight * 5 - 3)

$rowMemory = New-TestRow -Parent $GroupTests -TopY ($startY + $rowHeight * 5) `
    -CheckText "内存稳定性测试" `
    -TimeHint "约5分钟" `
    -Description "测试内存条是否有错误" `
    -Checked $false

Add-Separator -Parent $GroupTests -Y ($startY + $rowHeight * 6 - 3)

$rowThermal = New-TestRow -Parent $GroupTests -TopY ($startY + $rowHeight * 6) `
    -CheckText "散热综合测试" `
    -TimeHint "约10分钟" `
    -Description "CPU和显卡同时满载，测试散热系统是否正常" `
    -Checked $false

# Shorthand references to checkboxes
$chkDisk    = $rowDisk.Checkbox
$chkGpu     = $rowGpu.Checkbox
$chkVram    = $rowVram.Checkbox
$chkCpu     = $rowCpu.Checkbox
$chkMemory  = $rowMemory.Checkbox
$chkThermal = $rowThermal.Checkbox

# ---------------------------------------------------------------------------
# 3. Estimated time label
# ---------------------------------------------------------------------------
$LblTime = New-Object System.Windows.Forms.Label
$LblTime.Text      = "预计总时长：约 2 分钟"
$LblTime.Font      = $FontTime
$LblTime.ForeColor = $ColorBlue
$LblTime.Location  = New-Object System.Drawing.Point(16, 570)
$LblTime.Size      = New-Object System.Drawing.Size(516, 22)
$LblTime.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$Form.Controls.Add($LblTime)

# ---------------------------------------------------------------------------
# 4. Progress area (initially hidden)
# ---------------------------------------------------------------------------
$PanelProgress = New-Object System.Windows.Forms.Panel
$PanelProgress.Location  = New-Object System.Drawing.Point(16, 600)
$PanelProgress.Size      = New-Object System.Drawing.Size(516, 210)
$PanelProgress.Visible   = $false
$PanelProgress.BackColor = $ColorWhite

$LabelStep = New-Object System.Windows.Forms.Label
$LabelStep.Text      = "正在收集系统信息..."
$LabelStep.Location  = New-Object System.Drawing.Point(0, 0)
$LabelStep.Size      = New-Object System.Drawing.Size(516, 22)
$LabelStep.Font      = $FontMain
$LabelStep.ForeColor = [System.Drawing.Color]::FromArgb(33, 33, 33)

$ProgressBar = New-Object System.Windows.Forms.ProgressBar
$ProgressBar.Location = New-Object System.Drawing.Point(0, 26)
$ProgressBar.Size     = New-Object System.Drawing.Size(516, 18)
$ProgressBar.Minimum  = 0
$ProgressBar.Maximum  = 100
$ProgressBar.Value    = 0
$ProgressBar.Style    = [System.Windows.Forms.ProgressBarStyle]::Continuous

$RichLog = New-Object System.Windows.Forms.RichTextBox
$RichLog.Location    = New-Object System.Drawing.Point(0, 50)
$RichLog.Size        = New-Object System.Drawing.Size(516, 160)
$RichLog.ReadOnly    = $true
$RichLog.BackColor   = $ColorLogBg
$RichLog.ForeColor   = $ColorLogFg
$RichLog.Font        = $FontLog
$RichLog.ScrollBars  = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
$RichLog.WordWrap    = $true

$PanelProgress.Controls.AddRange(@($LabelStep, $ProgressBar, $RichLog))
$Form.Controls.Add($PanelProgress)

# ---------------------------------------------------------------------------
# 5. Buttons
# ---------------------------------------------------------------------------
$BtnStart = New-Object System.Windows.Forms.Button
$BtnStart.Text      = "开始验机"
$BtnStart.Location  = New-Object System.Drawing.Point(170, 600)
$BtnStart.Size      = New-Object System.Drawing.Size(200, 45)
$BtnStart.Font      = $FontButton
$BtnStart.BackColor = $ColorGreen
$BtnStart.ForeColor = $ColorWhite
$BtnStart.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$BtnStart.FlatAppearance.BorderSize          = 0
$BtnStart.FlatAppearance.MouseOverBackColor  = $ColorGreenDark
$BtnStart.Cursor    = [System.Windows.Forms.Cursors]::Hand

$BtnExit = New-Object System.Windows.Forms.Button
$BtnExit.Text      = "退出"
$BtnExit.Location  = New-Object System.Drawing.Point(452, 600)
$BtnExit.Size      = New-Object System.Drawing.Size(80, 45)
$BtnExit.Font      = $FontMain
$BtnExit.BackColor = $ColorGray
$BtnExit.ForeColor = $ColorWhite
$BtnExit.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$BtnExit.FlatAppearance.BorderSize = 0
$BtnExit.Cursor    = [System.Windows.Forms.Cursors]::Hand

$Form.Controls.AddRange(@($BtnStart, $BtnExit))

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
$Script:OutputDir = $null

# ---------------------------------------------------------------------------
# Dynamic time calculation
# ---------------------------------------------------------------------------
function Update-TimeLabel {
    $total = 60  # system info always included
    if ($chkDisk.Checked)    { $total += $DurationDisk }
    if ($chkGpu.Checked)     { $total += $DurationGpu }
    if ($chkVram.Checked)    { $total += $DurationVram }
    if ($chkCpu.Checked)     { $total += $DurationCpu }
    if ($chkMemory.Checked)  { $total += $DurationMemory }
    if ($chkThermal.Checked) { $total += $DurationThermal }

    $minutes = [math]::Ceiling($total / 60)
    $LblTime.Text = "预计总时长：约 $minutes 分钟"
}

# Wire checkboxes to time update
$chkDisk.Add_CheckedChanged({ Update-TimeLabel })
$chkGpu.Add_CheckedChanged({ Update-TimeLabel })
$chkVram.Add_CheckedChanged({ Update-TimeLabel })
$chkCpu.Add_CheckedChanged({ Update-TimeLabel })
$chkMemory.Add_CheckedChanged({ Update-TimeLabel })
$chkThermal.Add_CheckedChanged({ Update-TimeLabel })

Update-TimeLabel

# ---------------------------------------------------------------------------
# Layout helper: reflow buttons and optionally expand form for progress area
# ---------------------------------------------------------------------------
function Update-Layout {
    if ($PanelProgress.Visible) {
        # Expanded: checkboxes + time label + progress area + buttons
        $progressY  = 600
        $buttonY    = $progressY + 220
        $formHeight = $buttonY + 65

        $PanelProgress.Location = New-Object System.Drawing.Point(16, $progressY)
        $LblTime.Location       = New-Object System.Drawing.Point(16, 570)
    } else {
        $buttonY    = 600
        $formHeight = 680
        $LblTime.Location = New-Object System.Drawing.Point(16, 570)
    }

    $BtnStart.Location = New-Object System.Drawing.Point(170, $buttonY)
    $BtnExit.Location  = New-Object System.Drawing.Point(452, $buttonY)
    $Form.ClientSize   = New-Object System.Drawing.Size(550, ($buttonY + 60))
}

# ---------------------------------------------------------------------------
# Thread-safe log helpers
# ---------------------------------------------------------------------------
function Append-Log {
    param([string]$Text)
    if ($RichLog.InvokeRequired) {
        $RichLog.Invoke([Action[string]] {
            param($t)
            $RichLog.AppendText($t + "`n")
            $RichLog.ScrollToCaret()
        }, $Text)
    } else {
        $RichLog.AppendText($Text + "`n")
        $RichLog.ScrollToCaret()
    }
}

function Set-StepLabel {
    param([string]$Text)
    if ($LabelStep.InvokeRequired) {
        $LabelStep.Invoke([Action[string]] { param($t) $LabelStep.Text = $t }, $Text)
    } else {
        $LabelStep.Text = $Text
    }
}

function Set-Progress {
    param([int]$Value)
    $clamped = [Math]::Max(0, [Math]::Min(100, $Value))
    if ($ProgressBar.InvokeRequired) {
        $ProgressBar.Invoke([Action[int]] { param($v) $ProgressBar.Value = $v }, $clamped)
    } else {
        $ProgressBar.Value = $clamped
    }
}

# ---------------------------------------------------------------------------
# Build -CustomTests string from checked boxes
# ---------------------------------------------------------------------------
function Build-CustomTestsParam {
    $parts = @()
    if ($chkDisk.Checked)    { $parts += "disk" }
    if ($chkGpu.Checked)     { $parts += "furmark" }
    if ($chkVram.Checked)    { $parts += "vram" }
    if ($chkCpu.Checked)     { $parts += "cpu" }
    if ($chkMemory.Checked)  { $parts += "memory" }
    if ($chkThermal.Checked) { $parts += "thermal" }
    return ($parts -join ",")
}

# ---------------------------------------------------------------------------
# Background runspace — runs tests without freezing the GUI
# ---------------------------------------------------------------------------
function Start-TestsInBackground {
    param([string]$CustomTests)

    $runWindowsScript = Join-Path $ScriptRoot "run_windows.ps1"

    $queue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    $Script:BgQueue = $queue

    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $rs.ApartmentState = [System.Threading.ApartmentState]::STA
    $rs.ThreadOptions  = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
    $rs.Open()

    $rs.SessionStateProxy.SetVariable("RunWindowsScript", $runWindowsScript)
    $rs.SessionStateProxy.SetVariable("ScriptRootPath",   $ScriptRoot)
    $rs.SessionStateProxy.SetVariable("RepoRootPath",     $RepoRoot)
    $rs.SessionStateProxy.SetVariable("CustomTests",      $CustomTests)
    $rs.SessionStateProxy.SetVariable("LogQueue",         $queue)

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs

    $scriptBlock = {
        $ErrorActionPreference = "Continue"
        Set-StrictMode -Off

        function Queue-Log { param([string]$msg) $LogQueue.Enqueue($msg) }

        Queue-Log "=== 开始验机 ==="
        if ($CustomTests) { Queue-Log "测试项目: $CustomTests" }
        Queue-Log ""

        try {
            $argList = @(
                "-NoProfile",
                "-ExecutionPolicy", "Bypass",
                "-File", "`"$RunWindowsScript`"",
                "-ScriptRoot", "`"$ScriptRootPath`"",
                "-NonInteractive"
            )
            if ($CustomTests) {
                $argList += @("-CustomTests", "`"$CustomTests`"")
            }

            $proc = New-Object System.Diagnostics.Process
            $proc.StartInfo.FileName               = "powershell.exe"
            $proc.StartInfo.Arguments              = ($argList -join " ")
            $proc.StartInfo.UseShellExecute        = $false
            $proc.StartInfo.RedirectStandardOutput = $true
            $proc.StartInfo.RedirectStandardError  = $true
            $proc.StartInfo.CreateNoWindow         = $true
            $proc.StartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $proc.StartInfo.StandardErrorEncoding  = [System.Text.Encoding]::UTF8

            $proc.Add_OutputDataReceived({
                param($s, $e)
                if ($null -ne $e.Data) { $LogQueue.Enqueue($e.Data) }
            })
            $proc.Add_ErrorDataReceived({
                param($s, $e)
                if ($null -ne $e.Data) { $LogQueue.Enqueue("[STDERR] " + $e.Data) }
            })

            $proc.Start()       | Out-Null
            $proc.BeginOutputReadLine()
            $proc.BeginErrorReadLine()
            $proc.WaitForExit()

            Queue-Log ""
            if ($proc.ExitCode -eq 0) {
                Queue-Log "=== 验机完成 (退出码: 0) ==="
            } else {
                Queue-Log "=== 验机结束 (退出码: $($proc.ExitCode)) ==="
            }
        } catch {
            Queue-Log "[ERROR] 启动测试脚本失败: $_"
        }

        $LogQueue.Enqueue("__DONE__")
    }

    $ps.AddScript($scriptBlock) | Out-Null
    $Script:BgPowerShell = $ps
    $Script:BgRunspace   = $rs

    $null = $ps.BeginInvoke()
}

# ---------------------------------------------------------------------------
# Timer: drain queue → log box; detect completion
# ---------------------------------------------------------------------------
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 150
$Script:ProgressStep = 0
$Script:TotalSteps   = 7

$Timer.Add_Tick({
    if ($null -eq $Script:BgQueue) { return }

    $item  = $null
    $count = 0
    while ($Script:BgQueue.TryDequeue([ref]$item) -and $count -lt 40) {
        $count++

        if ($item -eq "__DONE__") {
            $Timer.Stop()
            Set-Progress 100
            Set-StepLabel "验机完成！"
            $Script:TestsCompleted = $true

            $BtnStart.Enabled   = $true
            $BtnStart.Text      = "打开结果文件夹"
            $BtnStart.BackColor = $ColorBlue
            $BtnStart.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(25, 118, 210)

            # Locate output directory
            $outputBase = Join-Path $RepoRoot "output"
            if (Test-Path $outputBase) {
                $latest = Get-ChildItem $outputBase -Directory |
                          Sort-Object LastWriteTime -Descending |
                          Select-Object -First 1
                if ($latest) { $Script:OutputDir = $latest.FullName }
            }
            Append-Log ""
            Append-Log ">>> 验机完成！结果保存在: $Script:OutputDir"
            continue
        }

        # Heuristic progress updates based on log content
        if ($item -match "系统信息收集") {
            $Script:ProgressStep = 1; Set-StepLabel "正在收集系统信息..."
        } elseif ($item -match "GPU 压力测试|FurMark") {
            $Script:ProgressStep = 2; Set-StepLabel "正在运行显卡压力测试..."
        } elseif ($item -match "VRAM|OCCT") {
            $Script:ProgressStep = 3; Set-StepLabel "正在运行显存测试..."
        } elseif ($item -match "CPU 压力") {
            $Script:ProgressStep = 4; Set-StepLabel "正在运行CPU压力测试..."
        } elseif ($item -match "内存稳定性") {
            $Script:ProgressStep = 5; Set-StepLabel "正在运行内存稳定性测试..."
        } elseif ($item -match "硬盘 SMART|硬盘健康") {
            $Script:ProgressStep = 6; Set-StepLabel "正在检查硬盘健康度..."
        } elseif ($item -match "散热综合") {
            $Script:ProgressStep = 6; Set-StepLabel "正在进行散热综合测试..."
        } elseif ($item -match "打包结果") {
            $Script:ProgressStep = 7; Set-StepLabel "正在打包结果..."
        }

        $pct = [int](($Script:ProgressStep / $Script:TotalSteps) * 95)
        Set-Progress $pct
        Append-Log $item
    }
})

# ---------------------------------------------------------------------------
# Button: Start / Open Folder (dual-mode after completion)
# ---------------------------------------------------------------------------
$Script:TestsCompleted = $false

$BtnStart.Add_Click({
    if ($Script:TestsCompleted) {
        # Open results folder
        if ($Script:OutputDir -and (Test-Path $Script:OutputDir)) {
            Start-Process explorer.exe $Script:OutputDir
        } else {
            $outputBase = Join-Path $RepoRoot "output"
            if (Test-Path $outputBase) {
                Start-Process explorer.exe $outputBase
            } else {
                [System.Windows.Forms.MessageBox]::Show(
                    "找不到输出目录。请确认验机已完成。",
                    "提示",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            }
        }
        return
    }

    # Disable controls while running
    $BtnStart.Enabled    = $false
    $BtnStart.Text       = "验机中..."
    $GroupTests.Enabled  = $false

    # Show progress area and reflow
    $PanelProgress.Visible = $true
    Update-Layout

    # Clear log
    $RichLog.Clear()
    Set-Progress 0
    Set-StepLabel "正在初始化..."
    $Script:ProgressStep   = 0
    $Script:OutputDir      = $null
    $Script:TestsCompleted = $false

    $customTests = Build-CustomTestsParam
    Start-TestsInBackground -CustomTests $customTests
    $Timer.Start()
})

# ---------------------------------------------------------------------------
# Button: Exit
# ---------------------------------------------------------------------------
$BtnExit.Add_Click({
    $Timer.Stop()
    if ($Script:BgPowerShell) { try { $Script:BgPowerShell.Stop() } catch {} }
    if ($Script:BgRunspace)   { try { $Script:BgRunspace.Close()  } catch {} }
    $Form.Close()
})

# ---------------------------------------------------------------------------
# Form closing cleanup
# ---------------------------------------------------------------------------
$Form.Add_FormClosing({
    $Timer.Stop()
    if ($Script:BgPowerShell) { try { $Script:BgPowerShell.Stop() } catch {} }
    if ($Script:BgRunspace)   { try { $Script:BgRunspace.Close()  } catch {} }
})

# ---------------------------------------------------------------------------
# Initial layout
# ---------------------------------------------------------------------------
Update-Layout

# ---------------------------------------------------------------------------
# Run the GUI
# ---------------------------------------------------------------------------
[System.Windows.Forms.Application]::Run($Form)
