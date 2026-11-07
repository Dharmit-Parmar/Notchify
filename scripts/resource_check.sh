#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "=========================================================================="
echo "          BUILDING NOTCHIFY RELEASE TARGET FOR RESOURCE CHECK             "
echo "=========================================================================="
swift build -c release

echo ""
python3 "$DIR/scripts/resource_check.py"
