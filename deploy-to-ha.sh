#!/usr/bin/env bash
# deploy-to-ha.sh
#
# Run this script while SSH'd into your Home Assistant server to deploy
# the zone-mapper-card from the inovelli-zigbee-mmwave-support branch.
#
# Usage:
#   bash deploy-to-ha.sh [HA_CONFIG_DIR]
#
# HA_CONFIG_DIR defaults to /config (standard for HA OS / Supervised / Docker).
# Pass a different path if your setup differs, e.g.:
#   bash deploy-to-ha.sh /homeassistant

set -euo pipefail

BRANCH="inovelli-zigbee-mmwave-support"
RAW_URL="https://raw.githubusercontent.com/potelux/zone-mapper-card/${BRANCH}/dist/zone-mapper-card.js"
HA_CONFIG="${1:-/config}"

# Resolve where the card lives: HACS path takes priority, then manual path.
HACS_PATH="${HA_CONFIG}/www/community/zone-mapper-card/zone-mapper-card.js"
MANUAL_PATH="${HA_CONFIG}/www/zone-mapper-card.js"

if [ -f "$HACS_PATH" ]; then
  DEST="$HACS_PATH"
elif [ -f "$MANUAL_PATH" ]; then
  DEST="$MANUAL_PATH"
else
  echo "ERROR: Could not find zone-mapper-card.js in either of:"
  echo "  $HACS_PATH"
  echo "  $MANUAL_PATH"
  echo ""
  echo "If the card is installed somewhere else, copy manually:"
  echo "  curl -fsSL \"$RAW_URL\" -o /path/to/zone-mapper-card.js"
  exit 1
fi

echo "Deploying zone-mapper-card (branch: ${BRANCH})"
echo "  Source : ${RAW_URL}"
echo "  Target : ${DEST}"
echo ""

# Back up the existing file before overwriting.
cp "$DEST" "${DEST}.bak"
echo "Backup saved to: ${DEST}.bak"

curl -fsSL "$RAW_URL" -o "$DEST"
echo "Done. Hard-refresh your browser (Ctrl+Shift+R) to load the updated card."
