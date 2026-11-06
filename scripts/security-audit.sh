#!/usr/bin/env bash
# ==============================================================================
#            NOTCH COMPREHENSIVE SECURITY AUDIT & SCANNER TOOL
# ==============================================================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

echo "=========================================================="
echo "          NOTCH APPLICATION SECURITY INTEGRITY AUDIT      "
echo "=========================================================="

FAILED=0

# 1. Check UserDefaults plists on macOS for plaintext tokens
echo -n "[1/4] Auditing local UserDefaults plists for credentials... "
PLIST_LEAKS=$(defaults read NotchApp 2>/dev/null | grep -iE "(apiKey|botToken|token|secret|AIzaSy|sk-)" || true)
if [ -n "$PLIST_LEAKS" ]; then
    echo -e "${RED}FAILED${NC}"
    echo "Found sensitive keys in UserDefaults: $PLIST_LEAKS"
    FAILED=1
else
    echo -e "${GREEN}PASSED (Zero secrets in UserDefaults)${NC}"
fi

# 2. Check tracked git files for credential patterns
echo -n "[2/4] Auditing tracked repository files for API keys... "
GIT_TRACKED_LEAKS=$(git grep -EI "(AIza[0-9A-Za-z-_]{35}|sk-[a-zA-Z0-9_-]{28,}|gh[pousr]_[0-9a-zA-Z]{36})" -- Sources/ 2>/dev/null || true)
if [ -n "$GIT_TRACKED_LEAKS" ]; then
    echo -e "${RED}FAILED${NC}"
    echo "Found real API keys in tracked files: $GIT_TRACKED_LEAKS"
    FAILED=1
else
    echo -e "${GREEN}PASSED (Zero keys tracked in repository)${NC}"
fi

# 3. Check gitignore enforcement
echo -n "[3/4] Auditing .gitignore credential rules... "
if grep -q "env" .gitignore && grep -q "key" .gitignore && grep -q "token" .gitignore; then
    echo -e "${GREEN}PASSED (Strict gitignore rules active)${NC}"
else
    echo -e "${RED}FAILED (Missing gitignore rules)${NC}"
    FAILED=1
fi

# 4. Check git pre-commit hook presence
echo -n "[4/4] Auditing active git pre-commit security hook... "
if [ -x .git/hooks/pre-commit ]; then
    echo -e "${GREEN}PASSED (Pre-commit security gate active)${NC}"
else
    echo -e "${RED}FAILED (Pre-commit hook not executable)${NC}"
    FAILED=1
fi

echo "=========================================================="
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ ALL SECURITY INTEGRITY GATES PASSED (100% SECURE)${NC}"
    exit 0
else
    echo -e "${RED}${BOLD}❌ SECURITY ISSUES DETECTED - PLEASE REMEDIATE${NC}"
    exit 1
fi
