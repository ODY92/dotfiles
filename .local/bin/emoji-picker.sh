#!/usr/bin/env bash
pkill -x rofi && exit 0

S="$HOME/.local/state/caelestia/scheme.json"
T="$HOME/.config/matugen/templates/rofi-emoji.rasi"
O="$HOME/.config/rofi/emoji.rasi"

hex() {
  local v
  v=$(jq -r --arg k "$1" '.colours[$k] // empty' "$S" 2>/dev/null)
  v=${v:-$2}
  echo "#${v#\#}"
}

sed \
  -e "s|{{colors.surface.default.hex}}|$(hex surface 0c0e12)|g" \
  -e "s|{{colors.surface_container_high.default.hex}}|$(hex surfaceContainerHigh 1c2026)|g" \
  -e "s|{{colors.on_surface.default.hex}}|$(hex onSurface e1e5ef)|g" \
  -e "s|{{colors.on_surface_variant.default.hex}}|$(hex onSurfaceVariant a7abb4)|g" \
  -e "s|{{colors.primary.default.hex}}|$(hex primary afc9eb)|g" \
  -e "s|{{colors.on_primary.default.hex}}|$(hex onPrimary 28425e)|g" \
  "$T" > "$O"

exec rofimoji --action type copy --hidden-descriptions --selector-args="-theme $O"
