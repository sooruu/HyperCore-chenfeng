# HyperCore v3.0 — Intelligent Performance + Battery Balance

iOS-style optimization for Xiaomi 14 Civi (chenfeng, SM8635).
Smooth UI + constant gaming FPS + battery efficient.

## Philosophy

v2.1 was "max everything always on" — great for gaming, terrible for battery.
v3.0 is iOS-style: the system is smart enough to boost only when needed.

## What's New in v3.0

### Enabled Disabled Qualcomm Features
Stock ROM disables these ML-based features on SM8635 (cliffs). We enable them:
- **SilkyScrolls** — ML-based scroll smoothness (IPC/freq boost during scrolls)
- **sPLH** — Scroll Performance Load Hint (complementary to SilkyScrolls)
- **AdaptLaunch** — ML-based adaptive app launch boost (learns per-app patterns)
- **Lightning Game Launch** — adaptive game launch boost
- **TopApp Render Thread Boost** — priority boost for foreground app render thread
- **QGPE AdaptiveEngine** — enabled on cliffs (stock: disabled)
- **PreKill** — proactive memory management
- **PrefApps** — keep preferred apps in memory longer

### New Vendor Config Overrides (6 new files, 14 total)
- `perfconfigstore.xml` — enables all disabled Qualcomm features above
- `perf_hint_threshold.xml` — 2x lower thresholds for faster frame stability boost
- `SilkyScrollsFeature.xml` — tuned IPC/freq thresholds for 120fps scroll
- `sPLHFeature.xml` — scroll perf load hint with cliffs target
- `QAPE.xml` — thread pipeline enabled for 15 popular games
- `smomo_setting.xml` — SmoMo game layer configs (60/90/120fps modes)

### New Runtime Tuning
- **UFS storage tuning** — disabled auto-hibernate for lower storage latency
- **DRAM frequency floor** — memory bus never fully sleeps (instant wake)
- **L3 cache frequency floor** — cache stays warm
- **IRQ affinity** — GPU/display/touch IRQs pinned to performance cores
- **AudioServer SCHED_FIFO** — prevents audio glitches during heavy load
- **CameraServer SCHED_FIFO** — smoother camera viewfinder
- **CPU idle state control** — shallow sleep on big/prime cores
- **Background app limit** — 60 → 96 (keep more apps alive)

### Improved from v2.1
- **GamePowerOptFeature** — Genshin Impact removed from IgnoredApps on cliffs, jank rescue enabled on cliffs
- **PowerFeatureConfig** — VideoPowerOpt and VendorScenarioPowerOpt enabled
- **GPU tuning** — balanced (medium adrenoboost, rail not forced on) saves battery
- **VM tuning** — higher swappiness (use zRAM more, save battery)
- **CPU governor** — moderate ramp-down (8ms vs 4ms) saves battery during idle
- **Stune boost** — reduced from 10 to 5 (less aggressive, more efficient)

## CPU Topology
```
cpu0-2:  Cortex-A520 (little)  — 2016 MHz
cpu3-6:  Cortex-A720 (mid)     — 2803 MHz
cpu7:    Cortex-X4   (prime)   — 3014 MHz
```

## File Count
- 14 vendor/product config bind-mounts (post-fs-data.sh)
- 19 sections kernel-level sysfs tuning (service.sh)
- ~25 system properties via resetprop
