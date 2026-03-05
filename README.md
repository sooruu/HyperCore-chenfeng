# HyperCore - Thermal & Performance Module

KernelSU / Magisk module for **Xiaomi 14 Civi (chenfeng)** running HyperOS 3.0 (Android 16).

Disables thermal throttling, locks max CPU/GPU clocks during gaming, enables aggressive game power optimization, and maintains full brightness + 120fps regardless of thermal state.

## What it does

This module overrides 8 system config files using bind mounts at boot:

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

## Installation

1. Download `HyperCore_chenfeng_v1.0.zip` from [Releases](../../releases)
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
