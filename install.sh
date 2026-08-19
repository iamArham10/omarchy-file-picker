#!/usr/bin/env bash
# ==============================================================================
# Omarchy File Picker - Installation & Setup Script
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="arh.file-picker"
TARGET_PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
LOCAL_BIN="$HOME/.local/bin"
CONFIG_FILE="$HOME/.config/omarchy/file-picker.json"

echo "================================================="
echo "   Installing Omarchy File Picker ($PLUGIN_ID)   "
echo "================================================="

# 1. Validate plugin directory
if command -v omarchy-plugin-validate >/dev/null 2>&1; then
  echo "==> Validating plugin manifest..."
  omarchy-plugin-validate "$SCRIPT_DIR"
  echo "    ✓ Manifest is valid."
fi

# 2. Link/Copy plugin to ~/.config/omarchy/plugins/
mkdir -p "$HOME/.config/omarchy/plugins"
if [[ "$SCRIPT_DIR" != "$TARGET_PLUGIN_DIR" ]]; then
  echo "==> Linking plugin to $TARGET_PLUGIN_DIR..."
  rm -rf "$TARGET_PLUGIN_DIR"
  ln -sf "$SCRIPT_DIR" "$TARGET_PLUGIN_DIR"
fi

# 3. Create default configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "==> Initializing configuration at $CONFIG_FILE..."
  mkdir -p "$(dirname "$CONFIG_FILE")"
  cp "$SCRIPT_DIR/default-config.json" "$CONFIG_FILE"
  echo "    ✓ Config created."
else
  echo "    ✓ Existing config found at $CONFIG_FILE"
fi

# 4. Link CLI binary to ~/.local/bin
mkdir -p "$LOCAL_BIN"
echo "==> Linking binary to $LOCAL_BIN/omarchy-file-picker..."
ln -sf "$SCRIPT_DIR/bin/omarchy-file-picker" "$LOCAL_BIN/omarchy-file-picker"
chmod +x "$SCRIPT_DIR/bin/omarchy-file-picker" "$SCRIPT_DIR/scan.sh"

# 5. Rescan and enable plugin in Omarchy Shell
if command -v omarchy-shell >/dev/null 2>&1; then
  echo "==> Notifying Omarchy Shell..."
  omarchy-shell -q shell rescanPlugins 2>/dev/null || true
  if command -v omarchy-plugin-enable >/dev/null 2>&1; then
    omarchy-plugin-enable "$PLUGIN_ID" 2>/dev/null || true
  fi
  echo "    ✓ Shell plugin enabled."
fi

echo ""
echo "================================================="
echo "   Installation Successful!                      "
echo "================================================="
echo ""
echo "Try running:"
echo "  omarchy-file-picker          # Toggles GUI overlay"
echo "  omarchy-file-picker --tui    # Interactive terminal fzf picker"
echo "  omarchy-file-picker --config # Edit search folders & categories"
echo ""
echo "To bind to SUPER + I in ~/.config/hypr/bindings.lua:"
echo '  o.bind("SUPER + I", "File picker", "omarchy-shell shell toggle arh.file-picker")'
echo ""
echo "Or for the floating terminal fzf window:"
echo '  o.bind("SUPER + I", "Fuzzy file picker", "alacritty --title fzf-picker -e omarchy-file-picker --tui")'
echo ""
