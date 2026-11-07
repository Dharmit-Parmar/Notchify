#!/bin/bash
# Empirical Automated Test Suite for Thock Process Lifecycle and Orphan Elimination
# Validates that thock-cli spawned by NotchApp dies in ALL termination scenarios.

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
cd "$DIR"

mkdir -p "$DIR/measurements"
PROOF_FILE="$DIR/measurements/thock_exit_proof.txt"

APP_BIN="$DIR/NotchApp.app/Contents/MacOS/NotchApp"

echo "========================================================" | tee "$PROOF_FILE"
echo "  THOCK PROCESS LIFECYCLE & ZERO-ORPHAN EMPIRICAL PROOF " | tee -a "$PROOF_FILE"
echo "========================================================" | tee -a "$PROOF_FILE"
echo "Date: $(date)" | tee -a "$PROOF_FILE"
echo "Host: $(uname -srm)" | tee -a "$PROOF_FILE"
echo "Git Commit: $(git rev-parse HEAD)" | tee -a "$PROOF_FILE"
echo "Git Branch: $(git branch --show-current)" | tee -a "$PROOF_FILE"
echo "" | tee -a "$PROOF_FILE"

cleanup_all() {
    killall NotchApp 2>/dev/null || true
    # Kill any thock-cli spawned during test
    pkill -f "thock-cli" 2>/dev/null || true
    sleep 0.5
}

cleanup_all

# Helper to verify running processes
count_thock() {
    ps -axo pid,ppid,command | grep -i "thock-cli" | grep -v grep | wc -l | tr -d ' '
}

# -------------------------------------------------------------
# TEST 1: Graceful SIGTERM / Normal Quit Handler
# -------------------------------------------------------------
echo "[PATH 1/6] Testing Graceful Exit via SIGTERM (Cocoa / Launchd Normal Terminate)..." | tee -a "$PROOF_FILE"
NOTCH_AUTO_START_THOCK=1 "$APP_BIN" >/dev/null 2>&1 &
NOTCH_PID=$!
sleep 2

THOCK_LINE=$(ps -axo pid,ppid,command | grep -i "thock-cli" | grep -v grep || true)
echo "  [Before] Running processes:" | tee -a "$PROOF_FILE"
echo "    NotchApp PID: $NOTCH_PID" | tee -a "$PROOF_FILE"
echo "    thock-cli entry: $THOCK_LINE" | tee -a "$PROOF_FILE"

if [ -z "$THOCK_LINE" ]; then
    echo "  FAIL: thock-cli did not launch" | tee -a "$PROOF_FILE"
    exit 1
fi

echo "  Sending SIGTERM to NotchApp PID $NOTCH_PID..." | tee -a "$PROOF_FILE"
kill -TERM "$NOTCH_PID"
sleep 1.2

REMAINING_THOCK=$(count_thock)
echo "  [After SIGTERM] thock-cli process count: $REMAINING_THOCK" | tee -a "$PROOF_FILE"
if [ "$REMAINING_THOCK" -eq 0 ]; then
    echo "  ✓ PASSED: thock-cli cleanly terminated on SIGTERM." | tee -a "$PROOF_FILE"
else
    echo "  ✗ FAILED: thock-cli orphaned!" | tee -a "$PROOF_FILE"
    ps -axo pid,ppid,command | grep -i "thock-cli" | grep -v grep | tee -a "$PROOF_FILE"
    exit 1
fi
echo "" | tee -a "$PROOF_FILE"
cleanup_all

# -------------------------------------------------------------
# TEST 2: stop_notch.sh (killall NotchApp)
# -------------------------------------------------------------
echo "[PATH 2/6] Testing stop_notch.sh (killall NotchApp invocation)..." | tee -a "$PROOF_FILE"
NOTCH_AUTO_START_THOCK=1 "$APP_BIN" >/dev/null 2>&1 &
NOTCH_PID=$!
sleep 2

THOCK_LINE=$(ps -axo pid,ppid,command | grep -i "thock-cli" | grep -v grep || true)
echo "  [Before] Running processes:" | tee -a "$PROOF_FILE"
echo "    NotchApp PID: $NOTCH_PID" | tee -a "$PROOF_FILE"
echo "    thock-cli entry: $THOCK_LINE" | tee -a "$PROOF_FILE"

echo "  Invoking ./stop_notch.sh..." | tee -a "$PROOF_FILE"
./stop_notch.sh | tee -a "$PROOF_FILE"
sleep 1.2

REMAINING_THOCK=$(count_thock)
echo "  [After stop_notch.sh] thock-cli process count: $REMAINING_THOCK" | tee -a "$PROOF_FILE"
if [ "$REMAINING_THOCK" -eq 0 ]; then
    echo "  ✓ PASSED: thock-cli cleanly terminated when stopped via stop_notch.sh." | tee -a "$PROOF_FILE"
else
    echo "  ✗ FAILED: thock-cli orphaned!" | tee -a "$PROOF_FILE"
    exit 1
fi
echo "" | tee -a "$PROOF_FILE"
cleanup_all

# -------------------------------------------------------------
# TEST 3: Terminal Interrupt SIGINT (Ctrl-C)
# -------------------------------------------------------------
echo "[PATH 3/6] Testing SIGINT (Ctrl-C in Terminal)..." | tee -a "$PROOF_FILE"
NOTCH_AUTO_START_THOCK=1 "$APP_BIN" >/dev/null 2>&1 &
NOTCH_PID=$!
sleep 2

THOCK_LINE=$(ps -axo pid,ppid,command | grep -i "thock-cli" | grep -v grep || true)
echo "  [Before] Running processes:" | tee -a "$PROOF_FILE"
echo "    NotchApp PID: $NOTCH_PID" | tee -a "$PROOF_FILE"
echo "    thock-cli entry: $THOCK_LINE" | tee -a "$PROOF_FILE"

echo "  Sending SIGINT (Ctrl-C) to NotchApp PID $NOTCH_PID..." | tee -a "$PROOF_FILE"
kill -INT "$NOTCH_PID"
sleep 1.2

REMAINING_THOCK=$(count_thock)
echo "  [After SIGINT] thock-cli process count: $REMAINING_THOCK" | tee -a "$PROOF_FILE"
if [ "$REMAINING_THOCK" -eq 0 ]; then
    echo "  ✓ PASSED: thock-cli cleanly terminated on SIGINT." | tee -a "$PROOF_FILE"
else
    echo "  ✗ FAILED: thock-cli orphaned!" | tee -a "$PROOF_FILE"
    exit 1
fi
echo "" | tee -a "$PROOF_FILE"
cleanup_all

# -------------------------------------------------------------
# TEST 4: Kernel Crash Simulation (kill -SEGV)
# -------------------------------------------------------------
echo "[PATH 4/6] Testing Crash Simulation (kill -SEGV / Segmentation Fault)..." | tee -a "$PROOF_FILE"
NOTCH_AUTO_START_THOCK=1 "$APP_BIN" >/dev/null 2>&1 &
NOTCH_PID=$!
sleep 2

THOCK_LINE=$(ps -axo pid,ppid,command | grep -i "thock-cli" | grep -v grep || true)
echo "  [Before] Running processes:" | tee -a "$PROOF_FILE"
echo "    NotchApp PID: $NOTCH_PID" | tee -a "$PROOF_FILE"
echo "    thock-cli entry: $THOCK_LINE" | tee -a "$PROOF_FILE"

echo "  Simulating crash via kill -SEGV $NOTCH_PID (Swift code cannot execute cleanup)..." | tee -a "$PROOF_FILE"
kill -SEGV "$NOTCH_PID" 2>/dev/null || true
echo "  Waiting 1.5s for thock-cli parent watchdog thread (500ms cadence) to detect PPID change / launchd reparenting..." | tee -a "$PROOF_FILE"
sleep 1.5

REMAINING_THOCK=$(count_thock)
echo "  [After NotchApp Crash] thock-cli process count: $REMAINING_THOCK" | tee -a "$PROOF_FILE"
if [ "$REMAINING_THOCK" -eq 0 ]; then
    echo "  ✓ PASSED: thock-cli watchdog self-terminated when parent crashed." | tee -a "$PROOF_FILE"
else
    echo "  ✗ FAILED: thock-cli orphaned after crash!" | tee -a "$PROOF_FILE"
    ps -axo pid,ppid,command | grep -i "thock-cli" | grep -v grep | tee -a "$PROOF_FILE"
    exit 1
fi
echo "" | tee -a "$PROOF_FILE"
cleanup_all

# -------------------------------------------------------------
# TEST 5: Force Kill Simulation (kill -9 / SIGKILL)
# -------------------------------------------------------------
echo "[PATH 5/6] Testing Unconditional Kill (kill -9 / SIGKILL)..." | tee -a "$PROOF_FILE"
NOTCH_AUTO_START_THOCK=1 "$APP_BIN" >/dev/null 2>&1 &
NOTCH_PID=$!
sleep 2

THOCK_LINE=$(ps -axo pid,ppid,command | grep -i "thock-cli" | grep -v grep || true)
echo "  [Before] Running processes:" | tee -a "$PROOF_FILE"
echo "    NotchApp PID: $NOTCH_PID" | tee -a "$PROOF_FILE"
echo "    thock-cli entry: $THOCK_LINE" | tee -a "$PROOF_FILE"

echo "  Executing kill -9 $NOTCH_PID (Immediate kernel kill, bypasses all userspace signal handlers)..." | tee -a "$PROOF_FILE"
kill -9 "$NOTCH_PID" 2>/dev/null || true
echo "  Waiting 1.5s for thock-cli parent watchdog thread to detect EOF on stdin and PPID 1..." | tee -a "$PROOF_FILE"
sleep 1.5

REMAINING_THOCK=$(count_thock)
echo "  [After kill -9] thock-cli process count: $REMAINING_THOCK" | tee -a "$PROOF_FILE"
if [ "$REMAINING_THOCK" -eq 0 ]; then
    echo "  ✓ PASSED: thock-cli watchdog self-terminated when parent was killed with SIGKILL (-9)." | tee -a "$PROOF_FILE"
else
    echo "  ✗ FAILED: thock-cli orphaned after SIGKILL!" | tee -a "$PROOF_FILE"
    ps -axo pid,ppid,command | grep -i "thock-cli" | grep -v grep | tee -a "$PROOF_FILE"
    exit 1
fi
echo "" | tee -a "$PROOF_FILE"
cleanup_all

# -------------------------------------------------------------
# TEST 6: Stale Orphan Sweep on Launch
# -------------------------------------------------------------
echo "[PATH 6/6] Testing Stale Orphan Sweep on Launch (ppid == 1)..." | tee -a "$PROOF_FILE"
# Spawn a detached orphan deliberately by having its parent shell immediately exit
( /Users/dharmitparmar/Doc/KeySound/target/release/thock-cli < /dev/null > /dev/null 2>&1 & )
sleep 0.5

ORPHAN_LINE=$(ps -axo pid,ppid,command | grep -i "thock-cli" | grep -v grep || true)
echo "  [Simulated Pre-existing Orphan]: $ORPHAN_LINE" | tee -a "$PROOF_FILE"

echo "  Launching NotchApp (which invokes sweepOrphanProcesses() on startup)..." | tee -a "$PROOF_FILE"
"$APP_BIN" >/dev/null 2>&1 &
NOTCH_PID=$!
sleep 1.5

REMAINING_THOCK=$(count_thock)
echo "  [After NotchApp Startup] thock-cli process count: $REMAINING_THOCK" | tee -a "$PROOF_FILE"
kill -TERM "$NOTCH_PID" 2>/dev/null || true
sleep 0.5

if [ "$REMAINING_THOCK" -eq 0 ]; then
    echo "  ✓ PASSED: NotchApp sweepOrphanProcesses() detected and reaped the orphan on startup." | tee -a "$PROOF_FILE"
else
    echo "  ✗ FAILED: Pre-existing orphan was not swept!" | tee -a "$PROOF_FILE"
    exit 1
fi
echo "" | tee -a "$PROOF_FILE"
cleanup_all

echo "========================================================" | tee -a "$PROOF_FILE"
echo "  ★ ALL 6 EXIT PATHS & ORPHAN SWEEPS PASSED (0 LEAKS) ★ " | tee -a "$PROOF_FILE"
echo "========================================================" | tee -a "$PROOF_FILE"
