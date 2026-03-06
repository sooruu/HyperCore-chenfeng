#!/system/bin/sh
# HyperCore v4.0 — Vendor Config Overrides (bind-mount)
MODDIR=${0%/*}

bind_mount() {
    local src="$1"
    local dst="$2"
    if [ -f "$dst" ]; then
        mount --bind "$src" "$dst"
    fi
}

# === EXISTING v2.1 OVERRIDES (8 files) ===
bind_mount "$MODDIR/system/vendor/etc/perf/thermalbreakboostconfig.xml" /vendor/etc/perf/thermalbreakboostconfig.xml
bind_mount "$MODDIR/system/vendor/etc/perf/perfboostsconfig.xml" /vendor/etc/perf/perfboostsconfig.xml
bind_mount "$MODDIR/system/vendor/etc/display/thermallevel_to_fps.xml" /vendor/etc/display/thermallevel_to_fps.xml
bind_mount "$MODDIR/system/vendor/etc/lm/QGPE.xml" /vendor/etc/lm/QGPE.xml
bind_mount "$MODDIR/system/vendor/etc/pwr/GamePowerOptFeature.xml" /vendor/etc/pwr/GamePowerOptFeature.xml
bind_mount "$MODDIR/system/vendor/etc/pwr/PowerFeatureConfig.xml" /vendor/etc/pwr/PowerFeatureConfig.xml
bind_mount "$MODDIR/system/product/etc/displayconfig/thermal_brightness_control.xml" /product/etc/displayconfig/thermal_brightness_control.xml
bind_mount "$MODDIR/system/product/etc/displayconfig/common_multi_factor_thermal_brightness_control.xml" /product/etc/displayconfig/common_multi_factor_thermal_brightness_control.xml

# === NEW v3.0 OVERRIDES ===
# perfconfigstore.xml — enables SilkyScrolls, sPLH, AdaptLaunch, TopAppRenderThreadBoost
bind_mount "$MODDIR/system/vendor/etc/perf/perfconfigstore.xml" /vendor/etc/perf/perfconfigstore.xml

# perf_hint_threshold.xml — lower thresholds for more aggressive frame stability
bind_mount "$MODDIR/system/vendor/etc/display/perf_hint_threshold.xml" /vendor/etc/display/perf_hint_threshold.xml

# SilkyScrollsFeature.xml — tuned IPC/freq thresholds for scroll smoothness
bind_mount "$MODDIR/system/vendor/etc/lm/SilkyScrollsFeature.xml" /vendor/etc/lm/SilkyScrollsFeature.xml

# sPLHFeature.xml — scroll performance load hint with cliffs target
bind_mount "$MODDIR/system/vendor/etc/lm/sPLHFeature.xml" /vendor/etc/lm/sPLHFeature.xml

# QAPE.xml — enable thread pipeline for popular games
bind_mount "$MODDIR/system/vendor/etc/lm/QAPE.xml" /vendor/etc/lm/QAPE.xml

# smomo_setting.xml — SmoMo game layer configs for popular titles
bind_mount "$MODDIR/system/vendor/etc/smomo_setting.xml" /vendor/etc/smomo_setting.xml
