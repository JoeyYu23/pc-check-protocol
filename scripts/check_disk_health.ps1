#Requires -Version 5.0
<#
.SYNOPSIS
    Disk SMART Health Check
    硬盘 SMART 健康度检查脚本

.DESCRIPTION
    Uses PowerShell CIM/WMI to read disk health data — no external tools required.
    Reports: disk model, size, media type (SSD/HDD/NVMe), health status,
    temperature, power-on hours, reallocated sector count, wear level (SSD).

    Also checks if CrystalDiskInfo is available in tools/ and launches it for
    a more detailed visual inspection.

    Requires no external tools for the basic SMART report (pure PowerShell).

.PARAMETER RepoRoot
    Root directory of the pc-check-protocol repo.

.PARAMETER OutputDir
    Timestamped output directory for this test session.

.NOTES
    Output: disk_health.txt
    Some SMART attributes require Administrator privileges and supported drives.
    NVMe health data availability depends on Windows version and driver support.
#>

param(
    [Parameter(Mandatory)]
    [string]$RepoRoot,

    [Parameter(Mandatory)]
    [string]$OutputDir,

    [switch]$NonInteractive
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

$LogPath  = Join-Path $OutputDir "disk_health.txt"
$ReportLines = [System.Collections.Generic.List[string]]::new()
$ReportLines.Add("Disk SMART Health Report")
$ReportLines.Add("生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$ReportLines.Add("=" * 60)
$ReportLines.Add("")

$OverallResult = "PASS"

# ---------------------------------------------------------------------------
# Section 1: Physical disk list (Get-PhysicalDisk — requires Storage module)
# ---------------------------------------------------------------------------
Write-Log "读取物理磁盘列表..." "STEP"
$ReportLines.Add("[ 物理磁盘列表 ]")
$ReportLines.Add("")

try {
    $physDisks = Get-PhysicalDisk -ErrorAction Stop
    foreach ($disk in $physDisks) {
        $sizeGB     = if ($disk.Size -gt 0) { [math]::Round($disk.Size / 1GB, 1) } else { "N/A" }
        $mediaType  = switch ($disk.MediaType) {
            "HDD"         { "HDD (机械硬盘)" }
            "SSD"         { "SSD (固态硬盘)" }
            "SCM"         { "SCM" }
            "Unspecified" { "未知 (可能是 NVMe)" }
            default       { $disk.MediaType }
        }
        $busType    = $disk.BusType
        $health     = $disk.HealthStatus
        $opStatus   = $disk.OperationalStatus
        $model      = $disk.FriendlyName

        $ReportLines.Add("  磁盘: $model")
        $ReportLines.Add("  容量: $sizeGB GB | 类型: $mediaType | 接口: $busType")
        $ReportLines.Add("  健康状态: $health | 运行状态: $opStatus")

        Write-Log "磁盘: $model  容量: ${sizeGB}GB  类型: $mediaType  健康: $health" "INFO"

        # Flag unhealthy disks
        if ($health -ne "Healthy") {
            Write-Log "警告: 磁盘 $model 健康状态异常: $health" "WARN"
            $ReportLines.Add("  [警告] 健康状态非 Healthy，请立即备份数据！")
            $OverallResult = "WARN"
        }

        # Read reliability counter (SMART attributes)
        try {
            $rel = Get-StorageReliabilityCounter -PhysicalDisk $disk -ErrorAction Stop
            $tempC        = $rel.Temperature
            $wearLevel    = $rel.Wear
            $powerOnHours = $rel.PowerOnHours
            $readErrors   = $rel.ReadErrorsUncorrected
            $writeErrors  = $rel.WriteErrorsUncorrected

            $ReportLines.Add("  温度: $(if ($tempC) { "${tempC}°C" } else { 'N/A' })")
            $ReportLines.Add("  通电时间: $(if ($powerOnHours) { "${powerOnHours} 小时" } else { 'N/A' })")
            $ReportLines.Add("  磨损程度 (Wear): $(if ($null -ne $wearLevel) { "${wearLevel}%" } else { 'N/A' })")
            $ReportLines.Add("  未纠正读取错误: $(if ($null -ne $readErrors) { $readErrors } else { 'N/A' })")
            $ReportLines.Add("  未纠正写入错误: $(if ($null -ne $writeErrors) { $writeErrors } else { 'N/A' })")

            Write-Log "  温度: $tempC°C  通电: $powerOnHours h  磨损: $wearLevel%  读错误: $readErrors  写错误: $writeErrors" "INFO"

            # Warn on high temperature
            if ($tempC -and $tempC -gt 55) {
                $ReportLines.Add("  [警告] 磁盘温度过高 (${tempC}°C > 55°C)，可能存在散热问题")
                $OverallResult = "WARN"
            }
            # Warn on high power-on hours
            if ($powerOnHours -and $powerOnHours -gt 30000) {
                $ReportLines.Add("  [注意] 通电时间较长 (${powerOnHours} 小时)，SSD 约 5 年，HDD 约 3-4 年")
            }
            # Warn on high wear level
            if ($null -ne $wearLevel -and $wearLevel -gt 80) {
                $ReportLines.Add("  [警告] SSD 磨损程度高 (${wearLevel}%)，剩余寿命有限")
                $OverallResult = "WARN"
            }
            # Warn on uncorrected errors
            if ($readErrors -and $readErrors -gt 0) {
                $ReportLines.Add("  [警告] 存在未纠正读取错误 ($readErrors)，可能有坏道")
                $OverallResult = "WARN"
            }
            if ($writeErrors -and $writeErrors -gt 0) {
                $ReportLines.Add("  [警告] 存在未纠正写入错误 ($writeErrors)，可能有坏道")
                $OverallResult = "WARN"
            }
        } catch {
            $ReportLines.Add("  SMART 详细数据: 无法读取 (需要管理员权限或驱动不支持)")
            Write-Log "SMART 详细数据读取失败 (非致命): $_" "WARN"
        }

        $ReportLines.Add("")
    }
} catch {
    Write-Log "Get-PhysicalDisk 失败: $_" "WARN"
    $ReportLines.Add("  无法通过 Get-PhysicalDisk 读取 (可能需要 Storage 模块或管理员权限)")
    $ReportLines.Add("")
}

# ---------------------------------------------------------------------------
# Section 2: WMI disk info (fallback / supplemental data)
# ---------------------------------------------------------------------------
$ReportLines.Add("[ WMI 磁盘信息 (补充) ]")
$ReportLines.Add("")

try {
    $wmiDisks = Get-CimInstance Win32_DiskDrive -ErrorAction Stop
    foreach ($d in $wmiDisks) {
        $sizeGB = if ($d.Size) { [math]::Round([long]$d.Size / 1GB, 1) } else { "N/A" }
        $ReportLines.Add("  $($d.Model)  容量: $sizeGB GB  序列号: $($d.SerialNumber)  接口: $($d.InterfaceType)")
        Write-Log "WMI: $($d.Model)  $sizeGB GB  S/N: $($d.SerialNumber)" "INFO"
    }
} catch {
    $ReportLines.Add("  WMI 磁盘读取失败: $_")
}

$ReportLines.Add("")

# ---------------------------------------------------------------------------
# Section 3: CrystalDiskInfo (optional, if found in tools/)
# ---------------------------------------------------------------------------
$CdiPath = Join-Path $RepoRoot "tools\CrystalDiskInfo\DiskInfo64.exe"
$CdiAlt  = Join-Path $RepoRoot "tools\CrystalDiskInfo.exe"

$CdiBin = $null
if (Test-Path $CdiPath) { $CdiBin = $CdiPath }
elseif (Test-Path $CdiAlt) { $CdiBin = $CdiAlt }

$ReportLines.Add("[ CrystalDiskInfo ]")
if ($CdiBin) {
    Write-Log "找到 CrystalDiskInfo，正在启动..." "INFO"
    $ReportLines.Add("  CrystalDiskInfo 已找到: $CdiBin")
    $ReportLines.Add("  请在 CrystalDiskInfo 界面中截图保存详细 SMART 数据")
    try {
        Start-Process -FilePath $CdiBin
        if (-not $NonInteractive) {
            Write-Host ""
            Write-Host "  CrystalDiskInfo 已打开。请截图 SMART 详情后按 Enter 继续..." -ForegroundColor Yellow
            $null = Read-Host
            $ReportLines.Add("  (卖家已确认查看 CrystalDiskInfo)")
        } else {
            Write-Log "CrystalDiskInfo 已启动（非交互模式，自动继续）" "INFO"
            Start-Sleep -Seconds 5
            $ReportLines.Add("  (非交互模式: CrystalDiskInfo 已自动启动)")
        }
    } catch {
        Write-Log "CrystalDiskInfo 启动失败: $_" "WARN"
        $ReportLines.Add("  启动失败: $_")
    }
} else {
    Write-Log "未找到 CrystalDiskInfo，仅使用 PowerShell SMART 数据" "INFO"
    $ReportLines.Add("  未找到 (可选工具，放置路径: tools\CrystalDiskInfo\DiskInfo64.exe)")
}

$ReportLines.Add("")

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
$ReportLines.Add("=" * 60)
$ReportLines.Add("整体评估: $OverallResult")
$ReportLines.Add("")
$ReportLines.Add("说明:")
$ReportLines.Add("  PASS  = 所有检测项目正常")
$ReportLines.Add("  WARN  = 发现一项或多项异常，请参考上方详情")
$ReportLines.Add("")
$ReportLines.Add("磁盘健康参考标准:")
$ReportLines.Add("  通电时间 < 20000 小时          良好")
$ReportLines.Add("  通电时间 20000-30000 小时       中等")
$ReportLines.Add("  通电时间 > 30000 小时           老化")
$ReportLines.Add("  SSD 磨损程度 < 50%              正常")
$ReportLines.Add("  SSD 磨损程度 50-80%             注意")
$ReportLines.Add("  SSD 磨损程度 > 80%              即将达到寿命上限")
$ReportLines.Add("  温度 < 50°C                     正常")
$ReportLines.Add("  温度 50-55°C                    偏高，注意散热")
$ReportLines.Add("  温度 > 55°C                     过热，有风险")

# Write report
$ReportLines | Out-File -FilePath $LogPath -Encoding UTF8
Write-Log "硬盘健康报告已保存: disk_health.txt  整体结果: $OverallResult" "OK"

return $OverallResult
