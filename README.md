# PC Check Protocol

**二手电脑交易验机工具**

一键收集硬件信息、运行多项压力测试、打包结果，帮助买卖双方在交易现场快速完成整机验机。适用于各类台式机与笔记本（含 GPU、CPU、内存、硬盘全面检测）。

**Used-PC verification tool for buyers and sellers — collects hardware info, runs stress tests (GPU, CPU, memory, disk), and packages results for review.**

---

## 安全声明 / Safety Statement

- **不联网、不上传**：所有数据只保存在本机 `output/` 目录，不发送到任何服务器
- **不访问个人文件**：只读取硬件信息（型号、驱动版本、温度），不碰文档、图片、密码
- **不留后台服务**：脚本运行完毕即结束，不安装任何常驻程序
- **不修改系统设置**（除 HWiNFO64 的 CSV 记录注册表项，测试后可手动删除）
- **开源可审计**：所有 `.ps1` 脚本均为明文 PowerShell，可用记事本打开查看

---

- **No network access, no uploads** — all data stays in the local `output/` directory
- **No personal file access** — only reads hardware info (model, driver version, temperatures)
- **No background services** — script exits cleanly after completion, installs nothing
- **No system setting changes** (except HWiNFO64's CSV logging registry key, removable manually)
- **Open source and auditable** — all `.ps1` scripts are plain PowerShell, readable in Notepad

---

## GUI 模式（推荐） / GUI Mode (Recommended)

**双击 `run_windows_gui.bat`** 即可打开图形界面，无需命令行知识。

```
┌─────────────────────────────────────────────┐
│  PC 验机工具 v2.0                            │  ← 蓝色标题栏
│  安全开源 · 不联网 · 不碰个人文件            │
├─────────────────────────────────────────────┤
│  请勾选要运行的测试项目                      │
│  ☑ 电脑基本信息          [必选]  约1分钟    │  ← 固定勾选，不可取消
│  ☑ 硬盘健康度检查                约1分钟    │  ← 默认勾选
│  ☐ 显卡压力测试                  约5分钟    │
│  ☐ 显存测试                     约10分钟    │
│  ☐ CPU 压力测试                 约10分钟    │
│  ☐ 内存稳定性测试                约5分钟    │
│  ☐ 散热综合测试                 约10分钟    │
├─────────────────────────────────────────────┤
│  预计总时长：约 2 分钟                       │  ← 随勾选动态更新
├─────────────────────────────────────────────┤
│  [进度条]                                    │  ← 点击开始后显示
│  实时日志输出...                             │
├─────────────────────────────────────────────┤
│    [ 开始验机 ]                    [ 退出 ] │
└─────────────────────────────────────────────┘
```

**使用方式：** 买家让测哪几项就勾哪几项，点"开始验机"即可。完成后按钮变为"打开结果文件夹"。

**界面特点：**
- 中文全程提示，不出现黑色命令行窗口
- 测试在后台运行，界面始终可响应
- 实时日志滚动显示当前进度
- 预计时长随勾选自动计算
- 完成后一键打开结果文件夹

---

## GUI Mode (Recommended for beginners)

**Double-click `run_windows_gui.bat`** to open the graphical interface.

The window shows a **checkbox list** of test items:

| Test Item | Default | Duration |
|-----------|---------|----------|
| System Info (CPU/GPU/RAM/Motherboard) | Always on | ~1 min |
| Disk Health (SMART) | Checked | ~1 min |
| GPU Stress Test (FurMark) | Unchecked | ~5 min |
| VRAM Test (OCCT) | Unchecked | ~10 min |
| CPU Stress Test | Unchecked | ~10 min |
| Memory Stability Test | Unchecked | ~5 min |
| Thermal Stress Test (CPU+GPU combined) | Unchecked | ~10 min |

Check the tests the buyer requires, click **"开始验机"** (Start). The estimated total time updates dynamically. When finished, click **"打开结果文件夹"** (Open Results Folder).

---

## 命令行模式 / CLI Mode

**双击 `run_windows.bat`** 运行命令行版本（右键"以管理员身份运行"获得完整硬件数据）。

命令行版本会显示交互菜单，输入编号选择测试项目（支持多选）：

```
请选择要运行的测试项目 (输入编号，多选用逗号分隔，如: 2,3,5):

  [1] 电脑基本信息        (必选，自动包含)     约1分钟
  [2] 硬盘健康度检查                          约1分钟
  [3] 显卡压力测试 (FurMark)                  约5分钟
  [4] 显存测试 (OCCT)                         约10分钟
  [5] CPU 压力测试                            约10分钟
  [6] 内存稳定性测试                           约5分钟
  [7] 散热综合测试                            约10分钟

  [A] 全选    [0] 退出
```

---

## CLI Mode

**Double-click `run_windows.bat`** (right-click → "Run as Administrator" for full hardware data).

An interactive menu appears — enter item numbers separated by commas (e.g., `2,3,5`), or `A` to select all.

---

## 快速开始（3步） / Quick Start (3 Steps)

### 第一步：下载本工具 / Step 1: Download this tool

从 GitHub 页面点 **Code → Download ZIP**，解压到任意目录。/
Click **Code → Download ZIP** on the GitHub page and extract to any folder.

### 第二步：下载测试工具 / Step 2: Download test utilities

将以下工具放入 `tools/` 目录 / Place the following tools in the `tools/` directory:

| 工具 / Tool | 放置路径 / Path | 用途 / Purpose |
|------|------|------|
| HWiNFO64.exe | `tools/HWiNFO64.exe` | 传感器记录 / Sensor logging |
| FurMark.exe | `tools/FurMark/FurMark.exe` | GPU 烤机 / GPU stress test |
| OCCT.exe | `tools/OCCT/OCCT.exe` | VRAM/CPU/内存测试 / VRAM/CPU/Memory tests |
| DiskInfo64.exe | `tools/CrystalDiskInfo/DiskInfo64.exe` | 硬盘详情（可选）/ Disk SMART detail (optional) |

### 第三步：运行验机 / Step 3: Run verification

- **图形界面（推荐）：双击 `run_windows_gui.bat`** / GUI mode: double-click `run_windows_gui.bat`
- **命令行：双击 `run_windows.bat`** / CLI mode: double-click `run_windows.bat`

验机完成后，结果保存在 `output/<时间戳>/` 目录，并自动打包为 ZIP。/
Results are saved to `output/<timestamp>/` and automatically zipped.

---

## 工具下载链接 / Tool Download Links

| 工具 / Tool | 下载地址 / Download | 是否必须 / Required | 说明 / Notes |
|------------|-------------------|-------------------|-------------|
| HWiNFO64 | https://www.hwinfo.com/download/ | 建议 / Recommended | 单文件 portable 版 / Single portable exe |
| FurMark | https://geeks3d.com/furmark/ | 建议 / Recommended | 需安装到 `tools/FurMark/` / Install to `tools/FurMark/` |
| OCCT | https://www.ocbase.com/download | 建议 / Recommended | 需安装到 `tools/OCCT/` / Install to `tools/OCCT/` |
| CrystalDiskInfo | https://crystalmark.info/en/software/crystaldiskinfo/ | 可选 / Optional | 解压到 `tools/CrystalDiskInfo/` |

---

## 输出说明 / Output Files

验机完成后，`output/<时间戳>/` 目录包含 / After verification, `output/<timestamp>/` contains:

| 文件 / File | 内容 / Content |
|------------|--------------|
| `system_info.txt` | 完整系统硬件信息（CPU/GPU/主板/内存）/ Full hardware info |
| `test_summary.txt` | 各测试步骤的通过/失败状态 / Pass/fail status per test |
| `session_transcript.log` | 完整运行日志 / Full run log |
| `furmark_log.txt` | 显卡压力测试日志 / GPU stress test log |
| `occt_log.txt` | 显存测试日志 / VRAM test log |
| `cpu_stress_log.txt` | CPU 压力测试日志 / CPU stress test log |
| `memory_test_log.txt` | 内存稳定性测试日志 / Memory test log |
| `disk_health.txt` | 硬盘 SMART 健康报告 / Disk SMART health report |
| `thermal_stress_log.txt` | 散热综合测试日志 / Thermal stress log |
| `hwinfo_sensors.csv` | HWiNFO64 传感器时序数据（温度/功耗/频率）/ Sensor time-series data |
| `screenshot_*.png` | 测试前后及各阶段截图 / Before/after and mid-test screenshots |
| `../pc_check_<时间戳>.zip` | 以上所有文件的压缩包 / Archive of all above files |

---

## 常见问题 FAQ

**Q: 运行时提示"此脚本无法运行"？/ "Script cannot be run" error?**
A: 右键 `run_windows_gui.bat`（或 `run_windows.bat`）→ "以管理员身份运行" / Right-click → "Run as Administrator"

**Q: 截图是黑屏？/ Screenshots are black?**
A: 部分系统的图形保护会阻止截图。手动截图（Win+Shift+S）保存到 `output/` 目录即可。/
Some systems block automated screenshots. Use Win+Shift+S manually and save to `output/`.

**Q: 没有 OCCT/FurMark 也能用吗？/ Can I run without OCCT/FurMark?**
A: 可以。脚本有内置的 PowerShell 降级测试（CPU多线程数学循环 + 内存读写循环），功能有限但基本可用。/
Yes. The script includes PowerShell-native fallback tests when tools are missing.

**Q: 验机结果能造假吗？/ Can results be faked?**
A: 卖家本地运行无法保证 100% 防伪，建议买家在场或视频验机，结合型号序列号核实。/
Local execution cannot guarantee 100% authenticity. Buyers should attend in person or use video verification.

---

## 系统要求 / System Requirements

- Windows 10 / Windows 11
- PowerShell 5.0+（系统自带 / built-in）
- 4 GB 以上可用内存 / 4 GB+ available RAM

---

## License

MIT License — 详见 [LICENSE](LICENSE)
