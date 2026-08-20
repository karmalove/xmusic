#!/bin/bash
set -euo pipefail

APP_PATH="${1:-/Applications/XMUSIC.app}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH"
  echo "Usage: $0 [/path/to/XMUSIC.app]"
  exit 1
fi

echo "Refreshing icon cache for: $APP_PATH"

sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null || true
sudo find /private/var/folders/ \
  \( -name com.apple.dock.iconcache -o -name com.apple.iconservices \) \
  -exec rm -rf {} + 2>/dev/null || true

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "$APP_PATH"

touch "$APP_PATH"
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true

echo "Done. Open Launchpad again to verify the icon."
