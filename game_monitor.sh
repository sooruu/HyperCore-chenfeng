#!/system/bin/sh
# HyperCore v4.0 — Game Monitor Daemon
# Watches foreground app and switches between gaming/default profiles
# Started by service.sh, runs as background daemon

MODDIR=${0%/*}
GAMES_CONF="$MODDIR/games.conf"
GAMING_PROFILE="$MODDIR/profiles/gaming.sh"
DEFAULT_PROFILE="$MODDIR/profiles/default.sh"
LOG_TAG="HyperCore-Monitor"

log_msg() { log -t "$LOG_TAG" "$1"; }

# Load game list into memory (skip comments and blank lines)
load_games() {
    GAME_LIST=""
    if [ -f "$GAMES_CONF" ]; then
        while IFS= read -r line; do
            line=$(echo "$line" | sed 's/#.*//' | tr -d ' \t\r')
            [ -n "$line" ] && GAME_LIST="$GAME_LIST $line"
        done < "$GAMES_CONF"
    fi
    log_msg "Loaded $(echo $GAME_LIST | wc -w) games from config"
}

is_game() {
    local pkg="$1"
    for game in $GAME_LIST; do
        [ "$pkg" = "$game" ] && return 0
    done
    return 1
}

get_foreground_app() {
    # Method 1: dumpsys (most reliable)
    local fg=$(dumpsys activity activities 2>/dev/null | \
        grep -E "mResumedActivity|mFocusedActivity" | \
        head -1 | \
        sed 's/.*u0 \(.*\)\/.*/\1/' | \
        sed 's/.*{\S* \S* \(.*\)\/.*/\1/' | \
        tr -d ' \r')

    # Method 2: fallback via window focus
    if [ -z "$fg" ] || echo "$fg" | grep -q "mResumed"; then
        fg=$(dumpsys window 2>/dev/null | \
            grep -E "mCurrentFocus|mFocusedApp" | \
            head -1 | \
            sed 's/.*{[^ ]* [^ ]* \([^/]*\).*/\1/' | \
            sed 's/.*u0 \([^/]*\).*/\1/' | \
            tr -d ' \r}')
    fi

    echo "$fg"
}

# ============================================================
# MAIN LOOP
# ============================================================
load_games

CURRENT_STATE="default"  # default or gaming
CURRENT_GAME=""
POLL_INTERVAL=3          # seconds between checks (balanced CPU usage)
RETRY_PIN_COUNT=0
MAX_RETRY_PIN=3

log_msg "Game monitor started (polling every ${POLL_INTERVAL}s)"

while true; do
    FG_APP=$(get_foreground_app)

    if [ -n "$FG_APP" ] && is_game "$FG_APP"; then
        # Game is in foreground
        if [ "$CURRENT_STATE" != "gaming" ] || [ "$CURRENT_GAME" != "$FG_APP" ]; then
            # New game detected or switched games
            log_msg "Game detected: $FG_APP"
            CURRENT_STATE="gaming"
            CURRENT_GAME="$FG_APP"
            RETRY_PIN_COUNT=0
            sh "$GAMING_PROFILE" "$FG_APP" &
        elif [ "$RETRY_PIN_COUNT" -lt "$MAX_RETRY_PIN" ]; then
            # Re-pin render threads (they may spawn late)
            GAME_PID=$(pidof "$FG_APP" 2>/dev/null)
            if [ -n "$GAME_PID" ]; then
                HAS_RENDER=0
                for tid_dir in /proc/$GAME_PID/task/*/; do
                    tname=$(cat "${tid_dir}comm" 2>/dev/null)
                    case "$tname" in
                        RenderThread|GLThread*|UnityMain|UnityGfx*|GameThread)
                            HAS_RENDER=1
                            tid=$(basename "$tid_dir")
                            taskset -p f8 "$tid" 2>/dev/null
                            chrt -f -p 2 "$tid" 2>/dev/null
                            echo 80 > "/proc/$GAME_PID/task/$tid/sched_uclamp_min" 2>/dev/null
                            ;;
                    esac
                done
                [ "$HAS_RENDER" -eq 1 ] && RETRY_PIN_COUNT=$((RETRY_PIN_COUNT + 1))
            fi
        fi
    else
        # No game in foreground
        if [ "$CURRENT_STATE" = "gaming" ]; then
            log_msg "Game exited: $CURRENT_GAME → restoring default"
            CURRENT_STATE="default"
            CURRENT_GAME=""
            RETRY_PIN_COUNT=0
            sh "$DEFAULT_PROFILE" &
        fi
    fi

    /system/bin/sleep "$POLL_INTERVAL"
done
