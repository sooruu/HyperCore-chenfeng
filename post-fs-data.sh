#!/system/bin/sh
MODDIR=${0%/*}

# Use bind mounts to overlay files on read-only partitions
# This works even with dm-verity/fs-verity on Android 16

bind_mount() {
    local src="$1"
    local dst="$2"
    if [ -f "$dst" ]; then
        mount --bind "$src" "$dst"
    fi
}

# Vendor overrides
bind_mount "$MODDIR/system/vendor/etc/perf/thermalbreakboostconfig.xml" /vendor/etc/perf/thermalbreakboostconfig.xml
bind_mount "$MODDIR/system/vendor/etc/perf/perfboostsconfig.xml" /vendor/etc/perf/perfboostsconfig.xml
bind_mount "$MODDIR/system/vendor/etc/display/thermallevel_to_fps.xml" /vendor/etc/display/thermallevel_to_fps.xml
bind_mount "$MODDIR/system/vendor/etc/lm/QGPE.xml" /vendor/etc/lm/QGPE.xml
bind_mount "$MODDIR/system/vendor/etc/pwr/GamePowerOptFeature.xml" /vendor/etc/pwr/GamePowerOptFeature.xml
bind_mount "$MODDIR/system/vendor/etc/pwr/PowerFeatureConfig.xml" /vendor/etc/pwr/PowerFeatureConfig.xml
# Product overrides
bind_mount "$MODDIR/system/product/etc/displayconfig/thermal_brightness_control.xml" /product/etc/displayconfig/thermal_brightness_control.xml
bind_mount "$MODDIR/system/product/etc/displayconfig/common_multi_factor_thermal_brightness_control.xml" /product/etc/displayconfig/common_multi_factor_thermal_brightness_control.xml
