#!/system/bin/sh
# HyperCore v2.0 - Kernel-level Performance Tuning
# Runs at late_start service phase (after boot completes)
# All changes are runtime sysfs writes — no kernel binary modification
# Device: Xiaomi 14 Civi (chenfeng) — SM8635 (cliffs/pineapple)

MODDIR=${0%/*}

# Wait for boot to complete
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    /system/bin/sleep 1
done

# ============================================================
# 1. CPU GOVERNOR TUNING (schedutil)
# ============================================================
# Reduce rate limiting so governor responds faster to load changes
# Stock: 500us up, 20000us down — too slow for gaming
for cpu_path in /sys/devices/system/cpu/cpufreq/policy*; do
    if [ -d "$cpu_path/schedutil" ]; then
        # Faster ramp-up (react to load spikes instantly)
        echo 0 > "$cpu_path/schedutil/rate_limit_us" 2>/dev/null
        echo 0 > "$cpu_path/schedutil/up_rate_limit_us" 2>/dev/null
        # Slightly slower ramp-down (hold high freq longer)
        echo 4000 > "$cpu_path/schedutil/down_rate_limit_us" 2>/dev/null
        # Disable predictive load (use actual load only)
        echo 0 > "$cpu_path/schedutil/pl" 2>/dev/null
    fi
done

# ============================================================
# 2. I/O SCHEDULER TUNING
# ============================================================
# Reduce I/O latency for game asset loading
for block in /sys/block/sda /sys/block/sdb /sys/block/dm-*; do
    if [ -d "$block/queue" ]; then
        # Lower read-ahead for lower latency (stock: 128-256KB)
        echo 64 > "$block/queue/read_ahead_kb" 2>/dev/null
        # Disable I/O stats collection (reduces overhead)
        echo 0 > "$block/queue/iostats" 2>/dev/null
        # Disable add_random (reduces entropy overhead per I/O)
        echo 0 > "$block/queue/add_random" 2>/dev/null
        # Set nr_requests lower for responsiveness
        echo 64 > "$block/queue/nr_requests" 2>/dev/null
    fi
done

# ============================================================
# 3. MEMORY / VM TUNING
# ============================================================
# Reduce swappiness — keep game data in RAM, don't swap to zRAM
echo 60 > /proc/sys/vm/swappiness 2>/dev/null

# More aggressive dirty page writeback (don't let dirty pages pile up)
echo 10 > /proc/sys/vm/dirty_ratio 2>/dev/null
echo 5 > /proc/sys/vm/dirty_background_ratio 2>/dev/null

# Shorter dirty page expiry (flush faster)
echo 1000 > /proc/sys/vm/dirty_expire_centisecs 2>/dev/null
echo 500 > /proc/sys/vm/dirty_writeback_centisecs 2>/dev/null

# Prefer reclaiming dentry/inode caches over page cache
echo 100 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null

# Disable page compaction proactiveness (reduces random latency spikes)
echo 0 > /proc/sys/vm/compaction_proactiveness 2>/dev/null

# Disable watermark boosting (prevents unnecessary memory reclaim)
echo 0 > /proc/sys/vm/watermark_boost_factor 2>/dev/null

# ============================================================
# 4. KERNEL SCHEDULER TUNING
# ============================================================
# Reduce scheduler migration cost (faster task migration between cores)
echo 250000 > /proc/sys/kernel/sched_migration_cost_ns 2>/dev/null

# Disable gentle fair sleepers (wake tasks faster)
echo 0 > /proc/sys/kernel/sched_tunable_scaling 2>/dev/null

# Reduce scheduler latency for more responsive task switching
echo 4000000 > /proc/sys/kernel/sched_latency_ns 2>/dev/null
echo 500000 > /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null
echo 750000 > /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null

# ============================================================
# 5. GPU TUNING (Adreno via sysfs)
# ============================================================
GPU_PATH="/sys/class/kgsl/kgsl-3d0"
if [ -d "$GPU_PATH" ]; then
    # Set GPU governor to performance during gaming
    # (msm-adreno-tz is stock, but we can tune its aggressiveness)
    echo 1 > "$GPU_PATH/force_clk_on" 2>/dev/null
    echo 0 > "$GPU_PATH/bus_split" 2>/dev/null
    echo 1 > "$GPU_PATH/force_bus_on" 2>/dev/null
    echo 1 > "$GPU_PATH/force_rail_on" 2>/dev/null
    # Disable GPU NAP and power saving
    echo 0 > "$GPU_PATH/force_no_nap" 2>/dev/null
    # Set idle timer shorter (keep GPU awake longer between frames)
    echo 64 > "$GPU_PATH/idle_timer" 2>/dev/null
    # Disable throttling
    echo 0 > "$GPU_PATH/throttling" 2>/dev/null
    # Set Adreno boost level (0=off, 1=low, 2=medium, 3=high)
    echo 3 > "$GPU_PATH/devfreq/adrenoboost" 2>/dev/null
fi

# ============================================================
# 6. NETWORK TUNING (lower latency for online gaming)
# ============================================================
# TCP congestion control — use BBR if available (better for gaming)
if grep -q bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
    echo bbr > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
fi

# Disable TCP slow start after idle (maintain throughput)
echo 0 > /proc/sys/net/ipv4/tcp_slow_start_after_idle 2>/dev/null

# Enable TCP fast open
echo 3 > /proc/sys/net/ipv4/tcp_fastopen 2>/dev/null

# ============================================================
# 7. DISABLE KERNEL DEBUGGING OVERHEAD
# ============================================================
# Disable printk during runtime (reduces logging overhead)
echo "0 0 0 0" > /proc/sys/kernel/printk 2>/dev/null

# Disable kernel panic on oops (don't crash, just log)
echo 0 > /proc/sys/kernel/panic_on_oops 2>/dev/null
echo 0 > /proc/sys/kernel/panic 2>/dev/null

# ============================================================
# 8. ZRAM TUNING
# ============================================================
# If zRAM exists, optimize compression algorithm
for zram in /sys/block/zram*; do
    if [ -f "$zram/comp_algorithm" ]; then
        # lz4 is faster than lzo for decompression (lower latency)
        if grep -q lz4 "$zram/comp_algorithm" 2>/dev/null; then
            echo lz4 > "$zram/comp_algorithm" 2>/dev/null
        fi
    fi
done

# ============================================================
# 9. STUNE / CPUSET BOOST (if available)
# ============================================================
# Boost top-app scheduling group
if [ -f /dev/stune/top-app/schedtune.boost ]; then
    echo 10 > /dev/stune/top-app/schedtune.boost 2>/dev/null
    echo 1 > /dev/stune/top-app/schedtune.prefer_idle 2>/dev/null
fi

# Ensure top-app has access to all CPU cores
if [ -f /dev/cpuset/top-app/cpus ]; then
    echo 0-7 > /dev/cpuset/top-app/cpus 2>/dev/null
fi

# Restrict background apps to efficiency cores only
if [ -f /dev/cpuset/background/cpus ]; then
    echo 0-3 > /dev/cpuset/background/cpus 2>/dev/null
fi
