#!/system/bin/sh
# HyperCore v4.0 — Default Profile
# Restores balanced settings when exiting a game

LOG_TAG="HyperCore-Default"
log_msg() { log -t "$LOG_TAG" "$1"; }
log_msg "RESTORE: switching to default profile"

# ============================================================
# 1. GPU — Balanced (save battery when not gaming)
# ============================================================
GPU="/sys/class/kgsl/kgsl-3d0"
if [ -d "$GPU" ]; then
    echo 1 > "$GPU/force_clk_on" 2>/dev/null
    echo 1 > "$GPU/force_bus_on" 2>/dev/null
    echo 0 > "$GPU/force_rail_on" 2>/dev/null
    echo 0 > "$GPU/force_no_nap" 2>/dev/null
    echo 2 > "$GPU/devfreq/adrenoboost" 2>/dev/null
    echo 58 > "$GPU/idle_timer" 2>/dev/null
    echo 0 > "$GPU/throttling" 2>/dev/null
    log_msg "GPU: balanced mode, rail released"
fi

# ============================================================
# 2. CPU Governor — Balanced ramp
# ============================================================
for pol in /sys/devices/system/cpu/cpufreq/policy*; do
    if [ -d "$pol/schedutil" ]; then
        echo 0 > "$pol/schedutil/up_rate_limit_us" 2>/dev/null
        echo 8000 > "$pol/schedutil/down_rate_limit_us" 2>/dev/null
    fi
done
log_msg "CPU governor: balanced ramp profile"

# ============================================================
# 3. DRAM / L3 — Lower frequency floor (save power)
# ============================================================
for bw in /sys/class/devfreq/*cpu-llcc-ddr-bw*; do
    [ -f "$bw/min_freq" ] && echo 547000 > "$bw/min_freq" 2>/dev/null
done
for l3 in /sys/class/devfreq/*cpu-l3-lat*; do
    [ -f "$l3/min_freq" ] && echo 614400 > "$l3/min_freq" 2>/dev/null
done
log_msg "DRAM/L3: balanced frequency floor"

# ============================================================
# 4. Re-enable deep C-states on little cores (battery)
# ============================================================
for cpu in 0 1 2; do
    for state in /sys/devices/system/cpu/cpu${cpu}/cpuidle/state*/disable; do
        echo 0 > "$state" 2>/dev/null
    done
done
# Keep big/prime in shallow sleep (same as boot default)
for cpu in 3 4 5 6 7; do
    for state in /sys/devices/system/cpu/cpu${cpu}/cpuidle/state*/disable; do
        state_dir=$(dirname "$state")
        state_name=$(cat "${state_dir}/name" 2>/dev/null)
        case "$state_name" in
            *rail*|*pc*|*C4*|*C3*)
                echo 1 > "$state" 2>/dev/null
                ;;
            *)
                echo 0 > "$state" 2>/dev/null
                ;;
        esac
    done
done
log_msg "C-states: little cores deep sleep re-enabled"

# ============================================================
# 5. Scheduler — Balanced latency
# ============================================================
echo 250000 > /proc/sys/kernel/sched_migration_cost_ns 2>/dev/null
echo 4000000 > /proc/sys/kernel/sched_latency_ns 2>/dev/null
echo 500000 > /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null
echo 750000 > /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null

echo 5 > /proc/sys/walt/sched_min_task_util_for_colocation 2>/dev/null
echo 5 > /proc/sys/walt/sched_min_task_util_for_boost 2>/dev/null

log_msg "Default profile ACTIVE"
