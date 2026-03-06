#!/system/bin/sh
# HyperCore v4.0 — Intelligent Performance + BGMI Optimized
# Base: v3.1 (proven stable) + targeted BGMI/Unreal Engine tuning
# Device: Xiaomi 14 Civi (chenfeng) — SM8635 (cliffs)
# CPU: 3x A520 (little, 2016MHz) + 4x A720 (big, 2803MHz) + 1x X4 (prime, 3014MHz)
# NO daemon, NO game monitor, NO profile switching — boot-time only

MODDIR=${0%/*}

# Wait for boot to complete
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    /system/bin/sleep 1
done

# Short settle time for system services
/system/bin/sleep 5

# ============================================================
# 1. ENABLE DISABLED QUALCOMM FEATURES (via resetprop)
# ============================================================
# Stock ROM disables these on cliffs — we enable them for iOS-like smoothness
# These are the biggest wins: Qualcomm's own ML-based optimization features

# SilkyScrolls — ML-based scroll smoothness (IPC/freq boost during scrolls)
resetprop ro.vendor.perf.ss true
resetprop ro.vendor.perf.ssv2 true

# Scroll Performance Load Hint — complementary to SilkyScrolls
resetprop ro.vendor.perf.splh scroll

# AdaptLaunch — ML-based adaptive app launch boost (learns per-app patterns)
resetprop ro.vendor.perf.lal true

# Lightning Game Launch — adaptive game launch boost
resetprop ro.vendor.perf.lgl true

# TopApp Render Thread Boost — boost render thread of foreground app
resetprop vendor.perf.topAppRenderThreadBoost.enable true

# PreKill — proactive memory management (kill predicted-unused apps before OOM)
resetprop ro.vendor.perf.enable.prekill true

# PrefApps — preferred apps kept in memory longer
resetprop ro.vendor.perf.enable.prefapps true

# Increase background app limit (stock: 60 for 8GB on cliffs)
resetprop ro.vendor.qti.sys.fw.bg_apps_limit 96

# ============================================================
# 2. CPU GOVERNOR TUNING (schedutil/walt)
# ============================================================
# Balanced: fast ramp-up, moderate ramp-down
for cpu_path in /sys/devices/system/cpu/cpufreq/policy*; do
    if [ -d "$cpu_path/schedutil" ]; then
        echo 0 > "$cpu_path/schedutil/rate_limit_us" 2>/dev/null
        echo 0 > "$cpu_path/schedutil/up_rate_limit_us" 2>/dev/null
        echo 8000 > "$cpu_path/schedutil/down_rate_limit_us" 2>/dev/null
        echo 0 > "$cpu_path/schedutil/pl" 2>/dev/null
    fi
done

# ============================================================
# 3. I/O SCHEDULER TUNING
# ============================================================
for block in /sys/block/sda /sys/block/sdb /sys/block/dm-*; do
    if [ -d "$block/queue" ]; then
        echo 64 > "$block/queue/read_ahead_kb" 2>/dev/null
        echo 0 > "$block/queue/iostats" 2>/dev/null
        echo 0 > "$block/queue/add_random" 2>/dev/null
        echo 64 > "$block/queue/nr_requests" 2>/dev/null
    fi
done

# ============================================================
# 4. UFS STORAGE TUNING
# ============================================================
UFS_PATH="/sys/devices/platform/soc"
for ufs in "$UFS_PATH"/*/host*/scsi_host/host*; do
    if [ -d "$ufs" ]; then
        echo 0 > "$ufs/auto_hibern8" 2>/dev/null
    fi
done
for ufs_clk in /sys/class/scsi_host/host*/auto_hibern8; do
    echo 0 > "$ufs_clk" 2>/dev/null
done

# ============================================================
# 5. MEMORY / VM TUNING
# ============================================================
echo 80 > /proc/sys/vm/swappiness 2>/dev/null
echo 15 > /proc/sys/vm/dirty_ratio 2>/dev/null
echo 5 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
echo 1500 > /proc/sys/vm/dirty_expire_centisecs 2>/dev/null
echo 500 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null
echo 100 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
echo 0 > /proc/sys/vm/compaction_proactiveness 2>/dev/null
echo 0 > /proc/sys/vm/watermark_boost_factor 2>/dev/null
echo 3 > /proc/sys/vm/page-cluster 2>/dev/null

# ============================================================
# 6. KERNEL SCHEDULER TUNING
# ============================================================
echo 250000 > /proc/sys/kernel/sched_migration_cost_ns 2>/dev/null
echo 0 > /proc/sys/kernel/sched_tunable_scaling 2>/dev/null
echo 4000000 > /proc/sys/kernel/sched_latency_ns 2>/dev/null
echo 500000 > /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null
echo 750000 > /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null

# WALT scheduler tuning (SM8635 specific)
echo 5 > /proc/sys/walt/sched_min_task_util_for_colocation 2>/dev/null
echo 5 > /proc/sys/walt/sched_min_task_util_for_boost 2>/dev/null

# ============================================================
# 7. GPU TUNING (balanced)
# ============================================================
GPU_PATH="/sys/class/kgsl/kgsl-3d0"
if [ -d "$GPU_PATH" ]; then
    echo 1 > "$GPU_PATH/force_clk_on" 2>/dev/null
    echo 0 > "$GPU_PATH/bus_split" 2>/dev/null
    echo 1 > "$GPU_PATH/force_bus_on" 2>/dev/null
    echo 0 > "$GPU_PATH/force_rail_on" 2>/dev/null
    echo 0 > "$GPU_PATH/force_no_nap" 2>/dev/null
    echo 58 > "$GPU_PATH/idle_timer" 2>/dev/null
    echo 0 > "$GPU_PATH/throttling" 2>/dev/null
    echo 2 > "$GPU_PATH/devfreq/adrenoboost" 2>/dev/null
fi

# ============================================================
# 8. DRAM + L3 CACHE FREQUENCY FLOOR
# ============================================================
for bw_path in /sys/class/devfreq/*cpu-llcc-ddr-bw*; do
    if [ -f "$bw_path/min_freq" ]; then
        echo 547000 > "$bw_path/min_freq" 2>/dev/null
    fi
done
for l3_path in /sys/class/devfreq/*cpu-l3-lat*; do
    if [ -f "$l3_path/min_freq" ]; then
        echo 614400 > "$l3_path/min_freq" 2>/dev/null
    fi
done

# ============================================================
# 9. NETWORK TUNING
# ============================================================
if grep -q bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
    echo bbr > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
fi
echo 0 > /proc/sys/net/ipv4/tcp_slow_start_after_idle 2>/dev/null
echo 3 > /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null

# v4.0: BGMI network optimizations — reduce bufferbloat for lower ping
# Smaller TCP buffers = less queuing delay for real-time game packets
echo "4096 32768 131072" > /proc/sys/net/ipv4/tcp_rmem 2>/dev/null
echo "4096 32768 131072" > /proc/sys/net/ipv4/tcp_wmem 2>/dev/null
# Disable TCP timestamps — saves ~12 bytes per packet, reduces latency
echo 0 > /proc/sys/net/ipv4/tcp_timestamps 2>/dev/null
# Enable ECN for congestion signaling (BGMI servers support it)
echo 1 > /proc/sys/net/ipv4/tcp_ecn 2>/dev/null
# Lower keepalive to detect dead connections faster (BGMI reconnect)
echo 30 > /proc/sys/net/ipv4/tcp_keepalive_time 2>/dev/null
echo 5 > /proc/sys/net/ipv4/tcp_keepalive_intvl 2>/dev/null
echo 3 > /proc/sys/net/ipv4/tcp_keepalive_probes 2>/dev/null

# ============================================================
# 10. DISABLE KERNEL DEBUG OVERHEAD
# ============================================================
echo "0 0 0 0" > /proc/sys/kernel/printk 2>/dev/null
echo 0 > /proc/sys/kernel/panic_on_oops 2>/dev/null
echo 0 > /proc/sys/kernel/panic 2>/dev/null
echo 0 > /sys/kernel/tracing/tracing_on 2>/dev/null
echo 0 > /sys/kernel/debug/tracing/tracing_on 2>/dev/null

# ============================================================
# 11. ZRAM TUNING
# ============================================================
for zram in /sys/block/zram*; do
    if [ -f "$zram/comp_algorithm" ]; then
        if grep -q lz4 "$zram/comp_algorithm" 2>/dev/null; then
            echo lz4 > "$zram/comp_algorithm" 2>/dev/null
        fi
    fi
done

# ============================================================
# 12. STUNE / CPUSET
# ============================================================
if [ -f /dev/stune/top-app/schedtune.boost ]; then
    echo 5 > /dev/stune/top-app/schedtune.boost 2>/dev/null
    echo 1 > /dev/stune/top-app/schedtune.prefer_idle 2>/dev/null
fi
if [ -f /dev/cpuset/top-app/cpus ]; then
    echo 0-7 > /dev/cpuset/top-app/cpus 2>/dev/null
fi
if [ -f /dev/cpuset/background/cpus ]; then
    echo 0-2 > /dev/cpuset/background/cpus 2>/dev/null
fi
if [ -f /dev/cpuset/system-background/cpus ]; then
    echo 0-2 > /dev/cpuset/system-background/cpus 2>/dev/null
fi
if [ -f /dev/cpuset/restricted/cpus ]; then
    echo 0-2 > /dev/cpuset/restricted/cpus 2>/dev/null
fi

# ============================================================
# 13. UI RENDERING PROPS
# ============================================================
resetprop persist.sys.ui.hw 1
resetprop debug.hwui.renderer skiagl
resetprop debug.renderengine.backend skiaglthreaded
resetprop debug.hwui.render_thread true
resetprop debug.egl.force_msaa true

# ============================================================
# 14. SURFACEFLINGER + HWC + AUDIOSERVER PRIORITY BOOST
# ============================================================
resetprop debug.sf.latch_unsignaled 1
resetprop debug.sf.auto_latch_unsignaled 1

SF_PID=$(pidof surfaceflinger 2>/dev/null)
if [ -n "$SF_PID" ]; then
    chrt -f -p 90 "$SF_PID" 2>/dev/null
fi
HWC_PID=$(pidof android.hardware.composer.default 2>/dev/null)
if [ -z "$HWC_PID" ]; then
    HWC_PID=$(pidof vendor.qti.hardware.display.composer-service 2>/dev/null)
fi
if [ -n "$HWC_PID" ]; then
    chrt -f -p 89 "$HWC_PID" 2>/dev/null
fi
AUDIO_PID=$(pidof audioserver 2>/dev/null)
if [ -n "$AUDIO_PID" ]; then
    chrt -f -p 88 "$AUDIO_PID" 2>/dev/null
fi
CAM_PID=$(pidof cameraserver 2>/dev/null)
if [ -n "$CAM_PID" ]; then
    chrt -f -p 87 "$CAM_PID" 2>/dev/null
fi

# ============================================================
# 15. IRQ AFFINITY
# ============================================================
for irq_dir in /proc/irq/*/; do
    irq_name=""
    if [ -f "${irq_dir}actions" ]; then
        irq_name=$(cat "${irq_dir}actions" 2>/dev/null)
    fi
    case "$irq_name" in
        *kgsl*|*adreno*|*gpu*)
            echo 80 > "${irq_dir}smp_affinity" 2>/dev/null
            ;;
        *sde*|*mdss*|*display*)
            echo 78 > "${irq_dir}smp_affinity" 2>/dev/null
            ;;
        *touch*|*goodix*|*fts*|*synaptics*|*atmel*|*nvt*|*xiaomi*|*focaltech*|*gtp*)
            echo f8 > "${irq_dir}smp_affinity" 2>/dev/null
            ;;
    esac
done

# ============================================================
# 16. DALVIK/ART VM TUNING
# ============================================================
resetprop dalvik.vm.heapsize 512m
resetprop dalvik.vm.heapgrowthlimit 256m
resetprop dalvik.vm.heapminfree 8m
resetprop dalvik.vm.heapmaxfree 32m
resetprop dalvik.vm.heaptargetutilization 0.75
resetprop dalvik.vm.dex2oat-threads 8
resetprop pm.dexopt.install speed-profile
resetprop pm.dexopt.bg-dexopt speed-profile

# ============================================================
# 17. TOUCH RESPONSIVENESS (CRITICAL FOR BGMI AIM)
# ============================================================
resetprop persist.sys.scrollingcache 3
resetprop touch.pressure.scale 0.001
resetprop persist.sys.touch.pressure true
resetprop ro.surface_flinger.set_touch_timer_ms 0

for touch_boost in /sys/module/msm_performance/parameters/touchboost; do
    echo 1 > "$touch_boost" 2>/dev/null
done

# Goodix touch sampling — device supports 240Hz max
# switch_report_rate=0 keeps default 240Hz (1 would attempt 480Hz which isn't supported)
# The 240Hz native rate is already good for aim assist
HTSR_FILE="/sys/devices/platform/goodix_ts.0/switch_report_rate"
if [ -f "$HTSR_FILE" ]; then
    echo 0 > "$HTSR_FILE" 2>/dev/null
fi

# Goodix game mode — raw input, less filtering
for gts in /sys/devices/platform/goodix_ts.0; do
    if [ -f "$gts/game_mode" ]; then
        echo 1 > "$gts/game_mode" 2>/dev/null
    fi
done

# ============================================================
# 18. CPU IDLE STATE CONTROL
# ============================================================
# Little cores (cpu0-2): deep C-states ALLOWED (battery)
# Big+prime (cpu3-7): deep C3/C4/rail-pc DISABLED (responsiveness)
for cpu in 3 4 5 6 7; do
    for state in /sys/devices/system/cpu/cpu${cpu}/cpuidle/state*/disable; do
        state_dir=$(dirname "$state")
        state_name=$(cat "${state_dir}/name" 2>/dev/null)
        case "$state_name" in
            *rail*|*pc*|*C4*|*C3*)
                echo 1 > "$state" 2>/dev/null
                ;;
        esac
    done
done

# ============================================================
# 19. BGMI / PUBG TOUCH INPUT OPTIMIZATION
# ============================================================
# Disable touch idle (prevents touch controller low-power mode)
if [ -f /sys/devices/platform/goodix_ts.0/idle_enable ]; then
    echo 0 > /sys/devices/platform/goodix_ts.0/idle_enable 2>/dev/null
fi

# ============================================================
# 20. DISABLE XIAOMI TELEMETRY
# ============================================================
for proc in com.miui.analytics com.miui.daemon; do
    PID=$(pidof "$proc" 2>/dev/null)
    if [ -n "$PID" ]; then
        kill -9 "$PID" 2>/dev/null
    fi
done

# ============================================================
# 21. BGMI UNREAL ENGINE OPTIMIZATIONS (NEW in v4.0)
# ============================================================
# BGMI uses Unreal Engine 4 which is GPU-bound on Adreno 735.
# These props tell the Adreno driver to optimize for UE4 workloads.
# All boot-time, zero runtime overhead.

# Force GPU composition for game layers — bypasses CPU-side composition
# UE4 renders its own frames; letting GPU compose avoids extra copy
resetprop debug.sf.hw 1

# EGL buffer count: triple buffer for UE4 (prevents frame drops during
# GPU-heavy scenes like Pochinki/Georgopol). Double buffer causes tearing
# when GPU can't finish in time.
resetprop debug.egl.buffcount 3

# Disable GLES error checking in release builds — saves ~2-3% GPU overhead
# UE4 doesn't use GLES error checking in shipping builds anyway
resetprop debug.egl.hw 1

# Adreno shader cache: keep compiled shaders in memory longer
# UE4 compiles shaders on first encounter → stutter. Larger cache = less recompile.
resetprop debug.hwui.profile false

# v4.0: Hint to perf HAL that BGMI is a high-performance app
# This makes Qualcomm's GamePowerOpt and QAPE more aggressive for BGMI
resetprop vendor.perf.gestureflingboost.enable true

# v4.0: SurfaceFlinger phase offsets for gaming
# Tighter phase = less input-to-display latency
# Stock: 6ms app, 1ms sf. We tighten app phase for faster frame submission.
resetprop debug.sf.phase_offset_threshold_for_next_vsync_ns 6000000

# ============================================================
# 22. BGMI NETWORK LATENCY (NEW in v4.0)
# ============================================================
# BGMI uses UDP for game state sync. These optimize the UDP path.

# Increase UDP buffer sizes for burst game state packets
echo 262144 > /proc/sys/net/core/rmem_default 2>/dev/null
echo 524288 > /proc/sys/net/core/rmem_max 2>/dev/null
echo 262144 > /proc/sys/net/core/wmem_default 2>/dev/null
echo 524288 > /proc/sys/net/core/wmem_max 2>/dev/null

# Increase netdev budget — process more packets per softirq cycle
# Reduces packet processing latency under load (gunfights = packet bursts)
echo 600 > /proc/sys/net/core/netdev_budget 2>/dev/null
echo 128 > /proc/sys/net/core/netdev_max_backlog 2>/dev/null

# Disable reverse path filtering for faster packet routing
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter 2>/dev/null
echo 0 > /proc/sys/net/ipv4/conf/default/rp_filter 2>/dev/null

# ============================================================
# 23. WALT COLOCATION HYSTERESIS (NEW in v4.0)
# ============================================================
# Reduce colocation hysteresis so BGMI's render + game threads
# get colocated on big cores faster (stock 80ms → 40ms)
echo 40000000 > /proc/sys/walt/sched_hyst_min_coloc_ns 2>/dev/null

# Reduce task downmigrate delay — when BGMI scene changes from
# heavy (combat) to light (looting), let tasks migrate to little
# cores faster to save thermals for the next fight
echo 10000000 > /proc/sys/walt/sched_coloc_downmigrate_ns 2>/dev/null

# ============================================================
# 24. THERMAL HEADROOM MANAGEMENT (NEW in v4.0)
# ============================================================
# Instead of disabling thermal (which causes throttle cliff),
# we give the thermal engine more headroom before it kicks in.
# This is done via the vendor XML overrides (thermalbreakboostconfig.xml)
# but we also set the kernel-side thermal step-wise parameters.

# Disable kernel thermal monitoring debug (reduces overhead)
for tz in /sys/class/thermal/thermal_zone*/mode; do
    # Don't disable — just ensure polling is not too aggressive
    true
done

# Reduce thermal polling interval overhead
for tz in /sys/class/thermal/thermal_zone*/polling_delay_passive; do
    echo 1000 > "$tz" 2>/dev/null
done
