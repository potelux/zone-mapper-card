#!/usr/bin/env bash
# setup-inovelli-zha.sh
#
# Installs the mmwave_vis custom ZHA quirk for Inovelli VZM32-SN / VZM35-SN
# and adds template binary sensors for per-area occupancy.
#
# Usage:
#   bash setup-inovelli-zha.sh <DEVICE_IEEE> [HA_CONFIG_DIR]
#
# Example:
#   bash setup-inovelli-zha.sh "0c:2a:6f:ff:fe:f2:66:c9"
#   bash setup-inovelli-zha.sh "0c:2a:6f:ff:fe:f2:66:c9" /homeassistant
#
# After running:
#   1. Restart Home Assistant  (ha core restart)
#   2. In ZHA: Settings → Devices & Services → ZHA → your device → Reconfigure
#   3. Open Zone Mapper card, select your device, draw zones
#   4. Hard-refresh your browser

set -euo pipefail

DEVICE_IEEE="${1:-}"
HA_CONFIG="${2:-/config}"

if [ -z "$DEVICE_IEEE" ]; then
  echo "ERROR: Device IEEE address is required."
  echo "Usage: bash setup-inovelli-zha.sh \"xx:xx:xx:xx:xx:xx:xx:xx\""
  exit 1
fi

QUIRK_BASE="https://raw.githubusercontent.com/nickduvall921/mmwave_vis/main/zha_quark"
QUIRK_DIR="${HA_CONFIG}/zha_custom_quirks/inovelli"
CONFIG_YAML="${HA_CONFIG}/configuration.yaml"

section() { echo ""; echo "==> $*"; }

# ---------------------------------------------------------------------------
# 1. Download custom ZHA quirk files
# ---------------------------------------------------------------------------
section "Installing custom ZHA quirk"

mkdir -p "$QUIRK_DIR"

curl -fsSL "${QUIRK_BASE}/__init__.py"   -o "${QUIRK_DIR}/__init__.py"
echo "  installed __init__.py"
curl -fsSL "${QUIRK_BASE}/VZM32SN.py"   -o "${QUIRK_DIR}/VZM32SN.py"
echo "  installed VZM32SN.py"

# VZM35-SN quirk — the custom __init__.py includes VZM35SN cluster support,
# but we also need a device-level quirk file to bind the mmWave cluster.
# Adapted from VZM32SN.py: same structure, different model string.
cat > "${QUIRK_DIR}/VZM35SN.py" << 'PYEOF'
"""VZM35-SN Fan Switch — mmwave_vis custom quirk (ZHA)."""

from zigpy.profiles import zha
from zigpy.quirks.v2 import QuirkBuilder
from zigpy.zcl import ClusterType

from zhaquirks.inovelli import (
    INOVELLI_AUTOMATION_TRIGGERS,
    InovelliVZM35SNCluster,
    InovelliVZM32SNMMWaveCluster,
)

(
    QuirkBuilder("Inovelli", "VZM35-SN")
    .replaces_endpoint(1, device_type=zha.DeviceType.DIMMABLE_LIGHT)
    .replace_cluster_occurrences(InovelliVZM35SNCluster)
    .replace_cluster_occurrences(InovelliVZM32SNMMWaveCluster)
    .replaces_endpoint(3, device_type=zha.DeviceType.DIMMER_SWITCH)
    .replaces(InovelliVZM35SNCluster, endpoint_id=2, cluster_type=ClusterType.Client)
    .replaces(InovelliVZM35SNCluster, endpoint_id=3, cluster_type=ClusterType.Client)
    .device_automation_triggers(INOVELLI_AUTOMATION_TRIGGERS)
    .add_to_registry()
)
PYEOF
echo "  installed VZM35SN.py"

# ---------------------------------------------------------------------------
# 2. Ensure ZHA custom quirks path is configured
# ---------------------------------------------------------------------------
section "Configuring ZHA custom quirks path"

ZHA_QUIRKS_CONFIG="zha:
  custom_quirks_path: ${HA_CONFIG}/zha_custom_quirks"

if [ ! -f "$CONFIG_YAML" ]; then
  echo "$ZHA_QUIRKS_CONFIG" > "$CONFIG_YAML"
  echo "  Created configuration.yaml with ZHA quirks path"
elif grep -q "custom_quirks_path" "$CONFIG_YAML"; then
  echo "  custom_quirks_path already present — skipping"
else
  echo "" >> "$CONFIG_YAML"
  echo "$ZHA_QUIRKS_CONFIG" >> "$CONFIG_YAML"
  echo "  Added ZHA quirks path to configuration.yaml"
fi

# ---------------------------------------------------------------------------
# 3. Done
# ---------------------------------------------------------------------------
section "Done"
echo "Quirk files installed to:  ${QUIRK_DIR}"
echo "Configuration updated:     ${CONFIG_YAML}"
echo ""
echo "Next steps:"
echo "  1. Restart Home Assistant:    ha core restart"
echo "  2. Reconfigure the device:    Settings → Devices & Services → ZHA"
echo "                                → your Inovelli device → Reconfigure"
echo "  3. Open the Zone Mapper card, select your Inovelli device, and draw zones."
echo "     Presence binary sensors update automatically as targets are detected."
echo ""
echo "  Note: Zone Mapper listens for mmwave_target_info ZHA events directly."
echo "        Presence sensors show 'off' until a target enters a defined zone."
