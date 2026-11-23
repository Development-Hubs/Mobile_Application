#!/usr/bin/env bash
# Downloads the Doha photograph used on the sign-in and home screens (see assets/photos/CREDITS.md).
set -euo pipefail
cd "$(dirname "$0")/.."
[ -s assets/photos/doha.jpg ] && exit 0
curl -fsSL -A "OneSourceConnect-build/1.0" -o assets/photos/doha.jpg \
  "https://commons.wikimedia.org/wiki/Special:FilePath/DohaSkylineAtNight.jpg?width=1200" \
  || { rm -f assets/photos/doha.jpg; echo "Photo not downloaded; the app will draw the skyline."; }
