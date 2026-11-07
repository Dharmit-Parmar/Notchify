#!/usr/bin/env bash
# ==============================================================================
#            NOTCH COMPREHENSIVE TEST SUITE RUNNER
# ==============================================================================
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}==========================================================${NC}"
echo -e "${BLUE}${BOLD}       RUNNING ALL NOTCHAPP AUTOMATED TEST SUITES         ${NC}"
echo -e "${BLUE}${BOLD}==========================================================${NC}"

# 1. Main Verification Suite (74 tests)
echo -e "\n${BOLD}[1/4] Running 74-Test Verification Suite via SPM (NotchTests)...${NC}"
swift run NotchTests

# 2. Kinematic Rig Acceptance Tests
echo -e "\n${BOLD}[2/4] Running Kinematic Rig & Roaming Acceptance Tests...${NC}"
swift Tests/KinematicAcceptanceTests.swift

# 3. Companion Production Pose Checks
echo -e "\n${BOLD}[3/4] Running Companion Production Pose Checks...${NC}"
swiftc -o /tmp/pose_checks Tests/CompanionProductionPoseChecks.swift Sources/Modules/Companion/KinematicSkeleton.swift Sources/Modules/Companion/CompanionTypes.swift Sources/Modules/Companion/KinematicEngine.swift -parse-as-library
/tmp/pose_checks
rm -f /tmp/pose_checks

# 4. Security Audit Integrity Gate
echo -e "\n${BOLD}[4/4] Running Security Audit Integrity Gate...${NC}"
./scripts/security-audit.sh

echo -e "\n${GREEN}${BOLD}==========================================================${NC}"
echo -e "${GREEN}${BOLD}   ✓ ALL TEST SUITES & SECURITY CHECKS PASSED (100%)      ${NC}"
echo -e "${GREEN}${BOLD}==========================================================${NC}"
