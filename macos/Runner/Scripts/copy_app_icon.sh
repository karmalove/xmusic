#!/bin/bash
# Ensure the pre-masked AppIcon.icns is what Launchpad uses.
set -euo pipefail
SRC="${SRCROOT}/Runner/Resources/AppIcon.icns"
DST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/AppIcon.icns"
if [[ -f "$SRC" ]]; then
  cp -f "$SRC" "$DST"
  echo "Installed AppIcon.icns ($(wc -c < "$SRC") bytes)"
else
  echo "warning: missing $SRC" >&2
fi
