#!/bin/zsh
# Regenerate AppIcon.icns from scripts/make-icon.swift.
set -euo pipefail
cd "$(dirname "$0")/.."
swift scripts/make-icon.swift
iconutil -c icns build/BetterFasterShorter.iconset -o AppIcon.icns
rm -rf build/BetterFasterShorter.iconset
echo "wrote AppIcon.icns"
