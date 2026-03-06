#!/system/bin/sh
# HyperCore v4.0 — Intelligent Performance Engine
# Dynamic game-aware profiles + iOS-style frame consistency
# Device: Xiaomi 14 Civi (chenfeng) — SM8635 (cliffs)
# CPU: 3x A520 (little, 2016MHz) + 4x A720 (mid, 2803MHz) + 1x X4 (prime, 3014MHz)

MODDIR=${0%/*}
LOG_TAG="HyperCore"
log_msg() { log -t "$LOG_TAG" "$1"; }

# Wait for boot
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    /system/bin/sleep 1
done
/system/bin/sleep 5

log_msg "v4.0 starting — boot complete"

# ============================================================
# §1. ENABLE DISABLED QUALCOMM FEATURES
# ============================================================
# Stock ROM disables these on cliffs — biggest smoothness wins
resetprop ro.vendor.perf.ss true
resetprop ro.vendor.perf.ssv2 true
resetprop ro.vendor.perf.splh scroll
resetprop ro.vendor.perf.lal true
resetprop ro.vendor.perf.lgl true
resetprop vendor.perf.topAppRenderThreadBoost.enable true
resetprop ro.vendor.perf.enable.prekill true
resetprop ro.vendor.perf.enable.prefapps true
resetprop ro.vendor.qti.sys.fw.bg_apps_limit 96
log_msg "§1 Qualcomm features enabled"

# ============================================================
# §2. CPU GOVERNOR TUNING (balanced default — gaming.sh overrides)
# ============================================================
for cpu_path in /sys/devices/system/cpu/cpufreq/policy*; do
    if [ -d "$cpu_path/schedutil" ]; then
        echo 0 > "$cpu_path/schedutil/rate_limit_us" 2>/dev/null
        echo 0 > "$cpu_path/schedutil/up_rate_limit_us" 2>/dev/null
        echo 8000 > "$cpu_path/schedutil/down_rate_limit_us" 2>/dev/null
        echo 0 > "$cpu_path/schedutil/pl" 2>/dev/null
    fi
done
log_msg "§2 CPU governor tuned"

# ============================================================
# §3. I/O SCHEDULER
# ============================================================
for block in /sys/block/sda /sys/block/sdb /sys/block/dm-*; do
    if [ -d "$block/queue" ]; then
        echo 64 > "$block/queue/read_ahead_kb" 2>/dev/null
        echo 0 > "$block/queue/iostats" 2>/dev/null
        echo 0 > "$block/queue/add_random" 2>/dev/null
        echo 64 > "$block/queue/nr_requests" 2>/dev/null
    fi
done
log_msg "§3 I/O tuned"

# ============================================================
# §4. UFS STORAGE — Disable auto-hibernate
# ============================================================
for ufs_clk in /sys/class/scsi_host/host*/auto_hibern8; do
    echo 0 > "$ufs_clk" 2>/dev/null
done
log_msg "§4 UFS auto-hibernate disabled"

# ============================================================
# §5. MEMORY / VM
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
log_msg "§5 VM tuned"

# ============================================================
# §6. KERNEL SCHEDULER (balanced default)
# ============================================================
echo 250000 > /proc/sys/kernel/sched_migration_cost_ns 2>/dev/null
echo 0 > /proc/sys/kernel/sched_tunable_scaling 2>/dev/null
echo 4000000 > /proc/sys/kernel/sched_latency_ns 2>/dev/null
echo 500000 > /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null
echo 750000 > /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null
echo 5 > /proc/sys/walt/sched_min_task_util_for_colocation 2>/dev/null
echo 5 > /proc/sys/walt/sched_min_task_util_for_boost 2>/dev/null
log_msg "§6 Scheduler tuned"

# ============================================================
# §7. GPU (balanced default — gaming.sh overrides)
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
log_msg "§7 GPU balanced"

# ============================================================
# §8. DRAM / L3 FREQUENCY FLOOR (balanced default)
# ============================================================
for bw_path in /sys/class/devfreq/*cpu-llcc-ddr-bw*; do
    [ -f "$bw_path/min_freq" ] && echo 547000 > "$bw_path/min_freq" 2>/dev/null
done
for l3_path in /sys/class/devfreq/*cpu-l3-lat*; do
    [ -f "$l3_path/min_freq" ] && echo 614400 > "$l3_path/min_freq" 2>/dev/null
done
log_msg "§8 DRAM/L3 floor set"

# ============================================================
# §9. NETWORK
# ============================================================
if grep -q bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
    echo bbr > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
fi
echo 0 > /proc/sys/net/ipv4/tcp_slow_start_after_idle 2>/dev/null
echo 3 > /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null
log_msg "§9 Network tuned"

# ============================================================
# §10. DISABLE KERNEL DEBUG OVERHEAD
# ============================================================
echo "0 0 0 0" > /proc/sys/kernel/printk 2>/dev/null
echo 0 > /proc/sys/kernel/panic_on_oops 2>/dev/null
echo 0 > /proc/sys/kernel/panic 2>/dev/null
echo 0 > /sys/kernel/tracing/tracing_on 2>/dev/null
echo 0 > /sys/kernel/debug/tracing/tracing_on 2>/dev/null
log_msg "§10 Debug overhead disabled"

# ============================================================
# §11. ZRAM — LZ4 if available
# ============================================================
for zram in /sys/block/zram*; do
    if [ -f "$zram/comp_algorithm" ]; then
        grep -q lz4 "$zram/comp_algorithm" 2>/dev/null && \
            echo lz4 > "$zram/comp_algorithm" 2>/dev/null
    fi
done
log_msg "§11 zRAM tuned"

# ============================================================
# §12. CPUSET / STUNE
# ============================================================
[ -f /dev/stune/top-app/schedtune.boost ] && echo 5 > /dev/stune/top-app/schedtune.boost 2>/dev/null
[ -f /dev/stune/top-app/schedtune.prefer_idle ] && echo 1 > /dev/stune/top-app/schedtune.prefer_idle 2>/dev/null
[ -f /dev/cpuset/top-app/cpus ] && echo 0-7 > /dev/cpuset/top-app/cpus 2>/dev/null
[ -f /dev/cpuset/background/cpus ] && echo 0-2 > /dev/cpuset/background/cpus 2>/dev/null
[ -f /dev/cpuset/system-background/cpus ] && echo 0-2 > /dev/cpuset/system-background/cpus 2>/dev/null
[ -f /dev/cpuset/restricted/cpus ] && echo 0-2 > /dev/cpuset/restricted/cpus 2>/dev/null
log_msg "§12 cpuset/stune configured"

# ============================================================
# §13. iOS-STYLE FRAME CONSISTENCY (NEW in v4.0)
# ============================================================
# These props make SurfaceFlinger behave more like iOS Core Animation:
# - Never drop refresh rate after touch ends
# - No backpressure stalls (SF doesn't wait for slow apps)
# - Latch unsignaled buffers (display frame even if fence not signaled)
resetprop debug.sf.latch_unsignaled 1
resetprop debug.sf.auto_latch_unsignaled 1
resetprop debug.sf.set_idle_timer_ms 0
resetprop ro.surface_flinger.set_touch_timer_ms 0
resetprop ro.surface_flinger.set_display_power_timer_ms 0
resetprop debug.sf.enable_gl_backpressure 0

# UI rendering pipeline
resetprop debug.hwui.renderer skiagl
resetprop debug.renderengine.backend skiaglthreaded
resetprop debug.hwui.render_thread true
resetprop persist.sys.ui.hw 1
log_msg "§13 Frame consistency props set"

# ============================================================
# §14. PROCESS PRIORITY BOOST (SF, HWC, Audio, Camera)
# ============================================================
SF_PID=$(pidof surfaceflinger 2>/dev/null)
[ -n "$SF_PID" ] && chrt -f -p 90 "$SF_PID" 2>/dev/null

HWC_PID=$(pidof android.hardware.composer.default 2>/dev/null)
[ -z "$HWC_PID" ] && HWC_PID=$(pidof vendor.qti.hardware.display.composer-service 2>/dev/null)
[ -n "$HWC_PID" ] && chrt -f -p 89 "$HWC_PID" 2>/dev/null

AUDIO_PID=$(pidof audioserver 2>/dev/null)
[ -n "$AUDIO_PID" ] && chrt -f -p 88 "$AUDIO_PID" 2>/dev/null

CAM_PID=$(pidof cameraserver 2>/dev/null)
[ -n "$CAM_PID" ] && chrt -f -p 87 "$CAM_PID" 2>/dev/null
log_msg "§14 Process priorities boosted"

# ============================================================
# §15. IRQ AFFINITY
# ============================================================
for irq_dir in /proc/irq/*/; do
    irq_name=$(cat "${irq_dir}actions" 2>/dev/null)
    case "$irq_name" in
        *kgsl*|*adreno*|*gpu*)
            echo 80 > "${irq_dir}smp_affinity" 2>/dev/null ;;
        *sde*|*mdss*|*display*)
            echo 78 > "${irq_dir}smp_affinity" 2>/dev/null ;;
        *touch*|*goodix*|*fts*|*synaptics*|*atmel*|*nvt*|*xiaomi*|*focaltech*|*gtp*)
            echo f8 > "${irq_dir}smp_affinity" 2>/dev/null ;;
    esac
done
log_msg "§15 IRQ affinity set"

# ============================================================
# §16. DALVIK/ART VM
# ============================================================
resetprop dalvik.vm.heapsize 512m
resetprop dalvik.vm.heapgrowthlimit 256m
resetprop dalvik.vm.heapminfree 8m
resetprop dalvik.vm.heapmaxfree 32m
resetprop dalvik.vm.heaptargetutilization 0.75
resetprop dalvik.vm.dex2oat-threads 8
resetprop pm.dexopt.install speed-profile
resetprop pm.dexopt.bg-dexopt speed-profile
log_msg "§16 Dalvik/ART tuned"

# ============================================================
# §17. TOUCH RESPONSIVENESS + GOODIX 480Hz HTSR
# ============================================================
resetprop persist.sys.scrollingcache 3
resetprop touch.pressure.scale 0.001

# Goodix high touch sampling rate
HTSR_FILE="/sys/devices/platform/goodix_ts.0/switch_report_rate"
[ -f "$HTSR_FILE" ] && echo 1 > "$HTSR_FILE" 2>/dev/null

# Goodix game mode + disable idle
for gts in /sys/devices/platform/goodix_ts.0; do
    [ -f "$gts/game_mode" ] && echo 1 > "$gts/game_mode" 2>/dev/null
    [ -f "$gts/idle_enable" ] && echo 0 > "$gts/idle_enable" 2>/dev/null
done
log_msg "§17 Touch 480Hz HTSR enabled"

# ============================================================
# §18. CPU IDLE — Disable deep C-states on big/prime
# ============================================================
for cpu in 3 4 5 6 7; do
    for state in /sys/devices/system/cpu/cpu${cpu}/cpuidle/state*/disable; do
        state_dir=$(dirname "$state")
        state_name=$(cat "${state_dir}/name" 2>/dev/null)
        case "$state_name" in
            *rail*|*pc*|*C4*|*C3*)
                echo 1 > "$state" 2>/dev/null ;;
        esac
    done
done
log_msg "§18 Deep C-states disabled on big/prime"

# ============================================================
# §19. DISABLE TELEMETRY (clean approach)
# ============================================================
pm disable com.miui.analytics 2>/dev/null
pm disable com.miui.daemon 2>/dev/null
log_msg "§19 Telemetry disabled"

# ============================================================
# §20. START GAME MONITOR DAEMON (NEW in v4.0)
# ============================================================
# Kill any existing instance
EXISTING=$(pidof -s game_monitor.sh 2>/dev/null)
[ -n "$EXISTING" ] && kill "$EXISTING" 2>/dev/null

# Start daemon in background
nohup sh "$MODDIR/game_monitor.sh" > /dev/null 2>&1 &
log_msg "§20 Game monitor daemon started (PID: $!)"

log_msg "=== HyperCore v4.0 boot sequence complete ==="
