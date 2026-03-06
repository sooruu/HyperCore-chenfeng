#!/system/bin/sh
# HyperCore v4.0 — Gaming Profile
# Activated when a game from games.conf is in foreground
# Arg: $1 = game package name

GAME_PKG="$1"
LOG_TAG="HyperCore-Gaming"

log_msg() { log -t "$LOG_TAG" "$1"; }
log_msg "ACTIVATE: $GAME_PKG"

# ============================================================
# 1. GPU — Full Boost (rail on, max adrenoboost, no nap)
# ============================================================
GPU="/sys/class/kgsl/kgsl-3d0"
if [ -d "$GPU" ]; then
    echo 1 > "$GPU/force_clk_on" 2>/dev/null
    echo 1 > "$GPU/force_bus_on" 2>/dev/null
    echo 1 > "$GPU/force_rail_on" 2>/dev/null
    echo 1 > "$GPU/force_no_nap" 2>/dev/null
    echo 3 > "$GPU/devfreq/adrenoboost" 2>/dev/null
    echo 34 > "$GPU/idle_timer" 2>/dev/null
    echo 0 > "$GPU/throttling" 2>/dev/null
    log_msg "GPU: full boost, rail locked, adrenoboost=3"
fi

# ============================================================
# 2. CPU Governor — Aggressive ramp-up, slow ramp-down
# ============================================================
for pol in /sys/devices/system/cpu/cpufreq/policy*; do
    if [ -d "$pol/schedutil" ]; then
        echo 0 > "$pol/schedutil/up_rate_limit_us" 2>/dev/null
        echo 20000 > "$pol/schedutil/down_rate_limit_us" 2>/dev/null
    fi
done
log_msg "CPU governor: gaming ramp profile"

# ============================================================
# 3. Render Thread Pinning + SCHED_FIFO + uclamp
# ============================================================
# Wait briefly for game process to fully start
/system/bin/sleep 3

GAME_PID=$(pidof "$GAME_PKG" 2>/dev/null)
if [ -n "$GAME_PID" ]; then
    # Find render threads (RenderThread, GLThread, UnityMain, UE4, mali)
    RENDER_TIDS=""
    for tid_dir in /proc/$GAME_PID/task/*/; do
        tid=$(basename "$tid_dir")
        tname=$(cat "${tid_dir}comm" 2>/dev/null)
        case "$tname" in
            RenderThread|GLThread*|UnityMain|UnityGfx*|GameThread|mali-*|hwui-*|FrameThread*)
                RENDER_TIDS="$RENDER_TIDS $tid"
                ;;
        esac
    done

    if [ -n "$RENDER_TIDS" ]; then
        for tid in $RENDER_TIDS; do
            # Pin to big (cpu3-6) + prime (cpu7) = 0xF8
            taskset -p f8 "$tid" 2>/dev/null
            # SCHED_FIFO priority 2 (below SF=90, HWC=89)
            chrt -f -p 2 "$tid" 2>/dev/null
            # uclamp_min 80% — CPU freq floor during frame work
            echo 80 > "/proc/$GAME_PID/task/$tid/sched_uclamp_min" 2>/dev/null
            log_msg "Pinned tid=$tid ($(cat /proc/$GAME_PID/task/$tid/comm 2>/dev/null)) → big+prime, FIFO:2, uclamp:80"
        done
    fi

    # Main game thread — also boost
    taskset -p f8 "$GAME_PID" 2>/dev/null
    chrt -f -p 1 "$GAME_PID" 2>/dev/null
    echo 70 > "/proc/$GAME_PID/sched_uclamp_min" 2>/dev/null
    log_msg "Main PID=$GAME_PID boosted"
fi

# ============================================================
# 4. DRAM / L3 — Higher frequency floor during gaming
# ============================================================
for bw in /sys/class/devfreq/*cpu-llcc-ddr-bw*; do
    [ -f "$bw/min_freq" ] && echo 1555000 > "$bw/min_freq" 2>/dev/null
done
for l3 in /sys/class/devfreq/*cpu-l3-lat*; do
    [ -f "$l3/min_freq" ] && echo 1017600 > "$l3/min_freq" 2>/dev/null
done
log_msg "DRAM/L3: gaming frequency floor"

# ============================================================
# 5. Disable deep C-states on ALL cores during gaming
# ============================================================
for cpu in 0 1 2 3 4 5 6 7; do
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
log_msg "C-states: deep sleep disabled on all cores"

# ============================================================
# 6. Touch — Maximum sensitivity
# ============================================================
# Goodix HTSR already enabled at boot, but ensure game mode is on
for gts in /sys/devices/platform/goodix_ts.0; do
    [ -f "$gts/game_mode" ] && echo 1 > "$gts/game_mode" 2>/dev/null
    [ -f "$gts/idle_enable" ] && echo 0 > "$gts/idle_enable" 2>/dev/null
done

# ============================================================
# 7. Scheduler — Tighter latency for gaming
# ============================================================
echo 100000 > /proc/sys/kernel/sched_migration_cost_ns 2>/dev/null
echo 2000000 > /proc/sys/kernel/sched_latency_ns 2>/dev/null
echo 300000 > /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null
echo 500000 > /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null

# WALT — more aggressive boost during gaming
echo 1 > /proc/sys/walt/sched_min_task_util_for_colocation 2>/dev/null
echo 1 > /proc/sys/walt/sched_min_task_util_for_boost 2>/dev/null

log_msg "Gaming profile ACTIVE for $GAME_PKG"
