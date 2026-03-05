# HyperCore - Thermal & Performance Module

KernelSU / Magisk module for **Xiaomi 14 Civi (chenfeng)** running HyperOS 3.0 (Android 16).

Disables thermal throttling, locks max CPU/GPU clocks during gaming, enables aggressive game power optimization, and maintains full brightness + 120fps regardless of thermal state.

## What it does

### Vendor Config Overrides (post-fs-data.sh)

8 bind-mounted config files replacing stock vendor/product XMLs:

| File | Effect |
|------|--------|
| `thermalbreakboostconfig.xml` | Disables thermal break boost — no clock drops during sustained load |
| `perfboostsconfig.xml` | Aggressive perf boost configs for foreground apps |
| `thermallevel_to_fps.xml` | Locks 120fps at all thermal levels (stock drops to 60fps at level 3+) |
| `QGPE.xml` | Game Performance Engine — 2x faster PID sampling, jank rescue enabled, max GPU frequency lock |
| `GamePowerOptFeature.xml` | Enables all game power optimization features |
| `PowerFeatureConfig.xml` | Disables thermal monitoring for CPU/GPU, removes power caps |
| `thermal_brightness_control.xml` | Prevents brightness reduction during thermal throttling |
| `common_multi_factor_thermal_brightness_control.xml` | Disables multi-factor thermal brightness control |

### Kernel-level Runtime Tuning (service.sh)

14 sections of sysfs writes and property changes — no kernel binary modification:

1. **CPU Governor** — Zero rate-limit ramp-up, 4ms ramp-down hold, disable predictive load
2. **I/O Scheduler** — 64KB read-ahead, disable iostats and add_random
3. **Memory/VM** — Swappiness 60, aggressive dirty writeback, disable compaction proactiveness
4. **Kernel Scheduler** — Lower migration cost, 4ms latency, faster wakeup granularity
5. **GPU (Adreno)** — Force clk/bus/rail on, disable nap, adrenoboost level 3
6. **Network** — BBR congestion control, TCP fast open, disable slow start after idle
7. **Debug Overhead** — Disable printk, disable panic on oops
8. **zRAM** — lz4 compression (faster decompression)
9. **Stune/Cpuset** — Boost top-app +10, background restricted to efficiency cores
10. **UI Rendering** — Force GPU rendering, skiagl threaded backend, disable backpressure
11. **SurfaceFlinger** — SCHED_FIFO priority 99, HWC boost priority 98, latch_unsignaled
12. **Dalvik/ART** — 512m heap, 256m growth limit, 8 dex2oat threads, speed-profile
13. **Touch Responsiveness** — Scrolling cache, pressure scale tuning, touch boost
14. **Telemetry Kill** — Kill miui analytics/daemon, disable kernel tracing

## Installation

1. Download the latest zip from [Releases](../../releases)
2. Open KernelSU Manager (or Magisk Manager)
3. Go to Modules → Install from storage
4. Select the zip file
5. Reboot

## Compatibility

- Device: Xiaomi 14 Civi (chenfeng) — model `24053PY09I`
- SoC: Snapdragon 7+ Gen 3 (SM8635 / pineapple)
- ROM: HyperOS 3.0 (Xiaomi EU, ZKROM, or stock CN)
- Root: KernelSU (Wild/Next/Official) or Magisk
- Android: 16 (API 36)

## Warning

This module disables thermal protection. Your device will run hotter under sustained gaming loads. This is by design — it trades thermal safety for maximum performance. Monitor temps if you're concerned.

## Module Structure

```
hypercore_module/
├── module.prop
├── post-fs-data.sh
├── service.sh
└── system/
    ├── product/etc/displayconfig/
    │   ├── thermal_brightness_control.xml
    │   └── common_multi_factor_thermal_brightness_control.xml
    └── vendor/etc/
        ├── display/thermallevel_to_fps.xml
        ├── lm/QGPE.xml
        ├── perf/perfboostsconfig.xml
        ├── perf/thermalbreakboostconfig.xml
        └── pwr/
            ├── GamePowerOptFeature.xml
            └── PowerFeatureConfig.xml
```

## Credits

- Config analysis and module packaging by the chenfeng-dev community
- Based on stock HyperOS 3.0.4.0 (WNJINXM) vendor configs

## License

MIT
