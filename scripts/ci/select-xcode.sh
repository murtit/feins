#!/usr/bin/env bash
# Wählt das neueste installierte Xcode auf dem Runner (oder XCODE_VERSION, falls gesetzt).
set -euo pipefail

if [[ -n "${XCODE_VERSION:-}" ]]; then
  candidate="/Applications/Xcode_${XCODE_VERSION}.app"
else
  candidate=$(ls -d /Applications/Xcode_*.app | sed -E 's#.*/Xcode_([0-9.]+)\.app#\1 &#' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1 | cut -d' ' -f2)
fi

echo "Verwende $candidate"
sudo xcode-select -s "$candidate/Contents/Developer"
xcodebuild -version
