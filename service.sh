#!/system/bin/sh
# HyperCore v3.0 — Intelligent Performance + Battery Balance
# iOS-style: smooth UI, constant gaming FPS, battery efficient
# Device: Xiaomi 14 Civi (chenfeng) — SM8635 (cliffs)
# CPU: 3x A520 (little, 2016MHz) + 4x A720 (mid, 2803MHz) + 1x X4 (prime, 3014MHz)

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
# Balanced: fast ramp-up, moderate ramp-down (not instant like v2.1)
# This saves battery during idle while still being responsive
for cpu_path in /sys/devices/system/cpu/cpufreq/policy*; do
    if [ -d "$cpu_path/schedutil" ]; then
        echo 0 > "$cpu_path/schedutil/rate_limit_us" 2>/dev/null
        echo 0 > "$cpu_path/schedutil/up_rate_limit_us" 2>/dev/null
        # Moderate ramp-down: 8ms (v2.1 was 4ms, stock was 20ms)
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
# 4. UFS STORAGE TUNING (NEW in v3.0)
# ============================================================
# Disable UFS clock gating for lower storage latency
# This is a meaningful win for app launch and game asset loading
UFS_PATH="/sys/devices/platform/soc"
for ufs in "$UFS_PATH"/*/host*/scsi_host/host*; do
    if [ -d "$ufs" ]; then
        # Disable auto-hibernate (keeps UFS link active)
        echo 0 > "$ufs/auto_hibern8" 2>/dev/null 
    fi
done
# Direct UFS sysfs tuning
for ufs_clk in /sys/class/scsi_host/host*/auto_hibern8; do
    echo 0 > "$ufs_clk" 2>/dev/null
done

# ============================================================
# 5. MEMORY / VM TUNING (balanced for battery)
# ============================================================
# Higher swappiness than v2.1 (60→80) — use zRAM more to save battery
# iOS aggressively compresses memory rather than keeping everything hot
echo 80 > /proc/sys/vm/swappiness 2>/dev/null

echo 15 > /proc/sys/vm/dirty_ratio 2>/dev/null
echo 5 > /proc/sys/vm/dirty_background_ratio 2>/dev/null
echo 1500 > /proc/sys/vm/dirty_expire_centisecs 2>/dev/null
echo 500 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null
echo 100 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
echo 0 > /proc/sys/vm/compaction_proactiveness 2>/dev/null
echo 0 > /proc/sys/vm/watermark_boost_factor 2>/dev/null

# Page cluster: read 8 pages at once from swap (better zRAM throughput)
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
# 7. GPU TUNING (balanced — not always-on max like v2.1)
# ============================================================
GPU_PATH="/sys/class/kgsl/kgsl-3d0"
if [ -d "$GPU_PATH" ]; then
    # Keep GPU clocks ready but don't force always-on
    echo 1 > "$GPU_PATH/force_clk_on" 2>/dev/null
    echo 0 > "$GPU_PATH/bus_split" 2>/dev/null
    echo 1 > "$GPU_PATH/force_bus_on" 2>/dev/null
    # DON'T force rail on (saves power when GPU idle) — v2.1 had this on
    echo 0 > "$GPU_PATH/force_rail_on" 2>/dev/null
    echo 0 > "$GPU_PATH/force_no_nap" 2>/dev/null
    # Moderate idle timer (v2.1: 64ms, stock: 80ms, v3.0: 58ms)
    echo 58 > "$GPU_PATH/idle_timer" 2>/dev/null
    echo 0 > "$GPU_PATH/throttling" 2>/dev/null
    # Adreno boost: medium (v2.1: 3/high, v3.0: 2/medium — saves battery)
    echo 2 > "$GPU_PATH/devfreq/adrenoboost" 2>/dev/null
fi

# ============================================================
# 8. DRAM FREQUENCY FLOOR (NEW in v3.0)
# ============================================================
# Set minimum DDR frequency to prevent deep sleep latency spikes
# This is what makes iOS feel "instant" — memory bus never fully sleeps
for bw_path in /sys/class/devfreq/*cpu-llcc-ddr-bw*; do
    if [ -f "$bw_path/min_freq" ]; then
        echo 547000 > "$bw_path/min_freq" 2>/dev/null
    fi
done

# L3 cache frequency floor
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

# ============================================================
# 10. DISABLE KERNEL DEBUG OVERHEAD
# ============================================================
echo "0 0 0 0" > /proc/sys/kernel/printk 2>/dev/null
echo 0 > /proc/sys/kernel/panic_on_oops 2>/dev/null
echo 0 > /proc/sys/kernel/panic 2>/dev/null

# Disable kernel tracing
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
# 12. STUNE / CPUSET (balanced — background gets efficiency cores)
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
# Restrict background to little cores only (saves battery)
if [ -f /dev/cpuset/restricted/cpus ]; then
    echo 0-2 > /dev/cpuset/restricted/cpus 2>/dev/null
fi

# ============================================================
# 13. UI RENDERING PROPS (same as v2.1 — these are always good)
# ============================================================
resetprop persist.sys.ui.hw 1
resetprop debug.hwui.renderer skiagl
resetprop debug.renderengine.backend skiaglthreaded
resetprop debug.hwui.render_thread true
resetprop debug.egl.force_msaa true
resetprop debug.sf.disable_backpressure 1

# ============================================================
# 14. SURFACEFLINGER + HWC + AUDIOSERVER PRIORITY BOOST
# ============================================================
resetprop debug.sf.latch_unsignaled 1
resetprop debug.sf.auto_latch_unsignaled 1

# SurfaceFlinger — SCHED_FIFO 99 (real-time, highest)
SF_PID=$(pidof surfaceflinger 2>/dev/null)
if [ -n "$SF_PID" ]; then
    chrt -f -p 99 "$SF_PID" 2>/dev/null
fi

# HWC (Hardware Composer) — SCHED_FIFO 98
HWC_PID=$(pidof android.hardware.composer.default 2>/dev/null)
if [ -z "$HWC_PID" ]; then
    HWC_PID=$(pidof vendor.qti.hardware.display.composer-service 2>/dev/null)
fi
if [ -n "$HWC_PID" ]; then
    chrt -f -p 98 "$HWC_PID" 2>/dev/null
fi

# AudioServer — SCHED_FIFO 97 (NEW in v3.0 — prevents audio glitches)
AUDIO_PID=$(pidof audioserver 2>/dev/null)
if [ -n "$AUDIO_PID" ]; then
    chrt -f -p 97 "$AUDIO_PID" 2>/dev/null
fi

# CameraServer — SCHED_FIFO 96 (NEW in v3.0 — smoother viewfinder)
CAM_PID=$(pidof cameraserver 2>/dev/null)
if [ -n "$CAM_PID" ]; then
    chrt -f -p 96 "$CAM_PID" 2>/dev/null
fi

# ============================================================
# 15. IRQ AFFINITY (NEW in v3.0)
# ============================================================
# Pin performance-critical IRQs to big/prime cores
# Touch controller, display, GPU interrupts → performance cores
for irq_dir in /proc/irq/*/; do
    irq_name=""
    if [ -f "${irq_dir}actions" ]; then
        irq_name=$(cat "${irq_dir}actions" 2>/dev/null)
    fi
    case "$irq_name" in
        *kgsl*|*adreno*|*gpu*)
            # GPU IRQs → prime core (cpu7)
            echo 80 > "${irq_dir}smp_affinity" 2>/dev/null
            ;;
        *sde*|*mdss*|*display*)
            # Display IRQs → big cores (cpu3-6)
            echo 78 > "${irq_dir}smp_affinity" 2>/dev/null
            ;;
        *touch*|*goodix*|*fts*|*synaptics*|*atmel*|*nvt*)
            # Touch IRQs → big cores for lowest input latency
            echo 78 > "${irq_dir}smp_affinity" 2>/dev/null
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
# 17. TOUCH RESPONSIVENESS
# ============================================================
resetprop persist.sys.scrollingcache 3
resetprop touch.pressure.scale 0.001
resetprop persist.sys.touch.pressure true

for touch_boost in /sys/module/msm_performance/parameters/touchboost; do
    echo 1 > "$touch_boost" 2>/dev/null
done

# ============================================================
# 18. CPU IDLE STATE CONTROL (NEW in v3.0)
# ============================================================
# Disable deepest C-states on big/prime cores to reduce wake latency
# Little cores (cpu0-2) keep deep sleep for battery
# Big cores (cpu3-6) and prime (cpu7) stay in shallow sleep
for cpu in 3 4 5 6 7; do
    for state in /sys/devices/system/cpu/cpu${cpu}/cpuidle/state*/disable; do
        state_dir=$(dirname "$state")
        state_name=$(cat "${state_dir}/name" 2>/dev/null)
        case "$state_name" in
            *rail*|*pc*|*C4*|*C3*)
                # Disable deep C-states on performance cores
                echo 1 > "$state" 2>/dev/null
                ;;
        esac
    done
done

# ============================================================
# 19. DISABLE XIAOMI TELEMETRY
# ============================================================
for proc in com.miui.analytics com.miui.daemon; do
    PID=$(pidof "$proc" 2>/dev/null)
    if [ -n "$PID" ]; then
        kill -9 "$PID" 2>/dev/null
    fi
done
