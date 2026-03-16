# PC Check Protocol

🌐 [中文](README.md) | **English**

**Used-PC verification tool for second-hand computer transactions**

One-click hardware info collection, stress testing (GPU, CPU, memory, disk), and result packaging — helping buyers and sellers verify hardware during transactions.

---

## Safety Statement

- **No network access, no uploads** — all data stays in the local `output/` directory
- **No personal file access** — only reads hardware info (model, driver version, temperatures)
- **No background services** — script exits cleanly after completion, installs nothing
- **No system setting changes** (except HWiNFO64's CSV logging registry key, removable manually)
- **Open source and auditable** — all `.ps1` scripts are plain PowerShell, readable in Notepad

---

## GUI Mode (Recommended)

**Double-click `run_windows_gui.bat`** to open the graphical interface.

The window shows a **checkbox list** of test items — check what you need, click Start:

| Test Item | Default | Duration |
|-----------|---------|----------|
| System Info (CPU/GPU/RAM/Motherboard) | Always on | ~1 min |
| Disk Health (SMART) | Checked | ~1 min |
| GPU Stress Test (FurMark) | Unchecked | ~5 min |
| VRAM Test (OCCT) | Unchecked | ~10 min |
| CPU Stress Test | Unchecked | ~10 min |
| Memory Stability Test | Unchecked | ~5 min |
| Thermal Stress Test (CPU+GPU combined) | Unchecked | ~10 min |

- Estimated total time updates dynamically as you check/uncheck items
- Tests run in background — GUI stays responsive with real-time log output
- When finished, click "Open Results Folder" to find the ZIP

---

## CLI Mode

**Double-click `run_windows.bat`** (right-click → "Run as Administrator" for full hardware data).

An interactive menu appears — enter item numbers separated by commas (e.g., `2,3,5`), or `A` to select all.

---

## Quick Start (3 Steps)

### Step 1: Download

Click **Code → Download ZIP** on the GitHub page and extract to any folder.

### Step 2: Download test utilities (optional)

Place the following tools in the `tools/` directory for full functionality:

| Tool | Path | Purpose |
|------|------|---------|
| HWiNFO64.exe | `tools/HWiNFO64.exe` | Sensor logging (temperature, power, fan speed) |
| FurMark.exe | `tools/FurMark/FurMark.exe` | GPU stress test |
| OCCT.exe | `tools/OCCT/OCCT.exe` | VRAM / CPU / Memory tests |
| DiskInfo64.exe | `tools/CrystalDiskInfo/DiskInfo64.exe` | Disk SMART detail (optional) |

GPU-Z and CPU-Z are **auto-downloaded** if missing. Without FurMark/OCCT, built-in PowerShell fallback tests will run (limited but functional).

### Step 3: Run

- **GUI:** Double-click `run_windows_gui.bat`
- **CLI:** Double-click `run_windows.bat`

Results are saved to `output/<timestamp>/` and automatically zipped.

---

## Tool Download Links

| Tool | Download | Required | Notes |
|------|----------|----------|-------|
| HWiNFO64 | https://www.hwinfo.com/download/ | Recommended | Single portable exe |
| FurMark | https://geeks3d.com/furmark/ | Recommended | Install to `tools/FurMark/` |
| OCCT | https://www.ocbase.com/download | Recommended | Install to `tools/OCCT/` |
| CrystalDiskInfo | https://crystalmark.info/en/software/crystaldiskinfo/ | Optional | Extract to `tools/CrystalDiskInfo/` |

---

## Output Files

| File | Content |
|------|---------|
| `system_info.txt` | Full hardware info (CPU/GPU/motherboard/RAM) |
| `test_summary.txt` | Pass/fail status per test |
| `session_transcript.log` | Full run log |
| `furmark_log.txt` | GPU stress test log |
| `occt_log.txt` | VRAM test log |
| `cpu_stress_log.txt` | CPU stress test log |
| `memory_test_log.txt` | Memory test log |
| `disk_health.txt` | Disk SMART health report |
| `thermal_stress_log.txt` | Thermal stress log |
| `hwinfo_sensors.csv` | Sensor time-series data (temperature/power/frequency) |
| `screenshot_*.png` | Before/after and mid-test screenshots |

---

## FAQ

**Q: "Script cannot be run" error?**
A: Right-click `run_windows_gui.bat` → "Run as Administrator"

**Q: Screenshots are black?**
A: Some systems block automated screenshots. Use Win+Shift+S manually.

**Q: Can I run without OCCT/FurMark?**
A: Yes. Built-in PowerShell fallback tests run when tools are missing (limited but functional).

**Q: Can results be faked?**
A: Local execution cannot guarantee 100% authenticity. Buyers should attend in person or use video verification.

---

## System Requirements

- Windows 10 / Windows 11
- PowerShell 5.0+ (built-in)
- 4 GB+ available RAM

---

## License

MIT License — see [LICENSE](LICENSE)
