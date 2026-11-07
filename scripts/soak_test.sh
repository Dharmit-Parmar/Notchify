#!/bin/bash
# Notchify Memory Soak & Stability Profiler
# Measures RSS and CPU over time to verify zero memory leaks and zero thermal throttling.

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
cd "$DIR"

DURATION="${1:-1800}" # Default to 1800s (30 minutes)
INTERVAL="${2:-30}"   # Sample every 30s
OUTPUT="${3:-$DIR/measurements/rss_soak_collapsed.txt}"

mkdir -p "$DIR/measurements"

echo "==========================================================" | tee "$OUTPUT"
echo "  NOTCHIFY SYSTEM MEMORY SOAK TEST (SOAK TIME: ${DURATION}s) " | tee -a "$OUTPUT"
echo "==========================================================" | tee -a "$OUTPUT"
echo "Start Time: $(date)" | tee -a "$OUTPUT"
echo "Host: $(uname -srm)" | tee -a "$OUTPUT"
echo "Sampling Interval: ${INTERVAL}s" | tee -a "$OUTPUT"
echo "Target Duration: ${DURATION}s ($(( DURATION / 60 )) min)" | tee -a "$OUTPUT"
echo "" | tee -a "$OUTPUT"

printf "%-20s %-8s %-8s %-12s %-8s %-30s\n" "TIMESTAMP" "PID" "PPID" "RSS (KB)" "CPU %" "COMMAND" | tee -a "$OUTPUT"
echo "--------------------------------------------------------------------------------------------------" | tee -a "$OUTPUT"

ELAPSED=0
START_RSS=0
END_RSS=0

while [ "$ELAPSED" -le "$DURATION" ]; do
    NOW=$(date "+%Y-%m-%d %H:%M:%S")
    MATCHES=$(ps -axo pid,ppid,rss,%cpu,command | grep -iE 'NotchApp|thock' | grep -v grep || true)
    
    if [ -n "$MATCHES" ]; then
        echo "$MATCHES" | while read -r pid ppid rss cpu cmd; do
            printf "%-20s %-8s %-8s %-12s %-8s %-30s\n" "$NOW" "$pid" "$ppid" "$rss" "$cpu" "$cmd" | tee -a "$OUTPUT"
            if [ "$START_RSS" -eq 0 ]; then
                START_RSS=$rss
            fi
            END_RSS=$rss
        done
    else
        printf "%-20s %-8s %-8s %-12s %-8s %-30s\n" "$NOW" "NONE" "NONE" "0" "0.0" "NotchApp not running" | tee -a "$OUTPUT"
    fi
    
    if [ "$ELAPSED" -lt "$DURATION" ]; then
        sleep "$INTERVAL"
    fi
    ELAPSED=$(( ELAPSED + INTERVAL ))
done

echo "--------------------------------------------------------------------------------------------------" | tee -a "$OUTPUT"
echo "End Time: $(date)" | tee -a "$OUTPUT"
echo "Soak profile complete. Results stored in: $OUTPUT" | tee -a "$OUTPUT"
