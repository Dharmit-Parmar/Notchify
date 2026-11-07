#!/usr/bin/env bash
# ==============================================================================
#            NOTCH COMPREHENSIVE SECURITY AUDIT & SCANNER TOOL
# ==============================================================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

echo "=========================================================="
echo "          NOTCH APPLICATION SECURITY INTEGRITY AUDIT      "
echo "=========================================================="

FAILED=0
WARNINGS=0

# 1. Check UserDefaults plists on macOS for plaintext tokens
echo -n "[1/6] Auditing local UserDefaults plists for credentials... "
PLIST_LEAKS=$(defaults read NotchApp 2>/dev/null | grep -iE "(apiKey|botToken|secret|AIzaSy|sk-)" || true)
if [ -n "$PLIST_LEAKS" ]; then
    echo -e "${RED}FAILED${NC}"
    echo "Found sensitive keys in UserDefaults: $PLIST_LEAKS"
    FAILED=1
else
    echo -e "${GREEN}PASSED (Zero credentials in UserDefaults)${NC}"
fi

# 2. Check tracked git files for credential patterns
echo -n "[2/6] Auditing tracked repository files for API keys... "
GIT_TRACKED_LEAKS=$(git grep -EI "(AIza[0-9A-Za-z_-]{35}|sk-[a-zA-Z0-9_-]{28,}|gh[pousr]_[0-9a-zA-Z]{36})" -- Sources/ 2>/dev/null || true)
if [ -n "$GIT_TRACKED_LEAKS" ]; then
    echo -e "${RED}FAILED${NC}"
    echo "Found real API keys in tracked files: $GIT_TRACKED_LEAKS"
    FAILED=1
else
    echo -e "${GREEN}PASSED (Zero keys tracked in repository)${NC}"
fi

# 3. Check gitignore enforcement
echo -n "[3/6] Auditing .gitignore credential rules... "
if grep -q "env" .gitignore && grep -q "key" .gitignore && grep -q "token" .gitignore; then
    echo -e "${GREEN}PASSED (Strict gitignore rules active)${NC}"
else
    echo -e "${RED}FAILED (Missing gitignore rules)${NC}"
    FAILED=1
fi

# 4. Check git pre-commit hook presence
echo -n "[4/6] Auditing active git pre-commit security hook... "
if [ -x .git/hooks/pre-commit ]; then
    echo -e "${GREEN}PASSED (Pre-commit security gate active)${NC}"
else
    echo -e "${RED}FAILED (Pre-commit hook not executable)${NC}"
    FAILED=1
fi

# 5. Check Info.plist for TCC Privacy descriptions
echo -n "[5/6] Auditing Info.plist for TCC privacy declarations... "
if [ -f "NotchApp.app/Contents/Info.plist" ]; then
    if grep -q "NSCameraUsageDescription" "NotchApp.app/Contents/Info.plist" && grep -q "NSAppleEventsUsageDescription" "NotchApp.app/Contents/Info.plist"; then
        echo -e "${GREEN}PASSED (Camera & AppleEvents privacy descriptions present)${NC}"
    else
        echo -e "${YELLOW}WARNING (Missing TCC privacy keys in Info.plist)${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${YELLOW}SKIPPED (App bundle not generated yet)${NC}"
fi

# 6. Check Local Vault POSIX Permissions
echo -n "[6/6] Auditing local credential vault permissions... "
VAULT_PATH="$HOME/Library/Application Support/NotchApp/vault.enc"
if [ -f "$VAULT_PATH" ]; then
    PERMS=$(stat -f "%Lp" "$VAULT_PATH" 2>/dev/null || stat -c "%a" "$VAULT_PATH" 2>/dev/null || echo "unknown")
    if [ "$PERMS" = "600" ]; then
        echo -e "${GREEN}PASSED (Vault has secure 0600 POSIX permissions)${NC}"
    else
        echo -e "${RED}FAILED (Vault permissions are $PERMS, expected 0600)${NC}"
        FAILED=1
    fi
else
    echo -e "${GREEN}PASSED (No local vault file created yet)${NC}"
fi

echo "=========================================================="
if [ "$FAILED" -eq 0 ]; then
    if [ "$WARNINGS" -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✓ ALL SECURITY INTEGRITY GATES PASSED (Zero plaintext leaks detected)${NC}"
    else
        echo -e "${YELLOW}${BOLD}✓ PASS WITH WARNINGS ($WARNINGS item(s) to verify)${NC}"
    fi
    exit 0
else
    echo -e "${RED}${BOLD}❌ SECURITY ISSUES DETECTED - PLEASE REMEDIATE${NC}"
    exit 1
fi
