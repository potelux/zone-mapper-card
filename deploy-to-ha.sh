#!/usr/bin/env bash
# deploy-to-ha.sh
#
# Run this script while SSH'd into your Home Assistant server to deploy
# the zone-mapper custom component and Lovelace card.
#
# Usage:
#   bash deploy-to-ha.sh [HA_CONFIG_DIR]
#
# HA_CONFIG_DIR defaults to /config (standard for HA OS / Supervised / Docker).
# Pass a different path if your setup differs, e.g.:
#   bash deploy-to-ha.sh /homeassistant

set -euo pipefail

CARD_BRANCH="inovelli-zigbee-mmwave-support"
COMPONENT_BRANCH="Main"
CARD_REPO="potelux/zone-mapper-card"
COMPONENT_REPO="potelux/zone-mapper"
RAW="https://raw.githubusercontent.com"
HA_CONFIG="${1:-/config}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
download() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  curl -fsSL "$url" -o "$dest"
}

section() { echo ""; echo "==> $*"; }

# ---------------------------------------------------------------------------
# 1. Custom component
# ---------------------------------------------------------------------------
section "Deploying custom component  (zone_mapper)"

COMP_BASE="${RAW}/${COMPONENT_REPO}/${COMPONENT_BRANCH}/custom_components/zone_mapper"
COMP_DEST="${HA_CONFIG}/custom_components/zone_mapper"

# Back up existing installation if present
if [ -d "$COMP_DEST" ]; then
  COMP_BAK="${COMP_DEST}.bak"
  rm -rf "$COMP_BAK"
  cp -r "$COMP_DEST" "$COMP_BAK"
  echo "Backup saved to: ${COMP_BAK}"
fi

mkdir -p "${COMP_DEST}/translations"

COMPONENT_FILES=(
  "__init__.py"
  "binary_sensor.py"
  "config_flow.py"
  "const.py"
  "manifest.json"
  "sensor.py"
  "services.yaml"
  "translations/en.json"
)

for f in "${COMPONENT_FILES[@]}"; do
  echo "  downloading ${f}"
  download "${COMP_BASE}/${f}" "${COMP_DEST}/${f}"
done

echo "Custom component installed to: ${COMP_DEST}"

# ---------------------------------------------------------------------------
# 2. Lovelace card
# ---------------------------------------------------------------------------
section "Deploying Lovelace card  (zone-mapper-card)"

CARD_URL="${RAW}/${CARD_REPO}/${CARD_BRANCH}/dist/zone-mapper-card.js"

# HACS path takes priority; fall back to manual path.
HACS_PATH="${HA_CONFIG}/www/community/zone-mapper-card/zone-mapper-card.js"
MANUAL_PATH="${HA_CONFIG}/www/zone-mapper-card.js"

if [ -f "$HACS_PATH" ]; then
  CARD_DEST="$HACS_PATH"
elif [ -f "$MANUAL_PATH" ]; then
  CARD_DEST="$MANUAL_PATH"
else
  # Neither path exists — install to the HACS location by default.
  CARD_DEST="$HACS_PATH"
  echo "No existing card found; installing to: ${CARD_DEST}"
fi

if [ -f "$CARD_DEST" ]; then
  cp "$CARD_DEST" "${CARD_DEST}.bak"
  echo "Backup saved to: ${CARD_DEST}.bak"
fi

download "$CARD_URL" "$CARD_DEST"
echo "Card installed to: ${CARD_DEST}"

# ---------------------------------------------------------------------------
# 3. Next steps
# ---------------------------------------------------------------------------
section "Done"
echo "Restart Home Assistant to load the updated custom component:"
echo "  ha core restart          # HA OS / Supervised"
echo "  docker restart homeassistant   # Docker"
echo ""
echo "Then hard-refresh your browser (Ctrl+Shift+R) to reload the card."
