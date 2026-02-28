#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
setup_default_terminal() {
  echo "Setting kitty as the default terminal for Thunar and CLI apps..."

  # 1. Configure XFCE/Exo (Thunar's primary helper)
  # This handles "Open Terminal Here" and "Open with [CLI App]"
  HELPER_DIR="$HOME/.config/xfce4"
  mkdir -p "$HELPER_DIR"
  # Prefer exo-preferred-applications when available (XFCE/Thunar)
  if command -v exo-preferred-applications >/dev/null 2>&1; then
    exo-preferred-applications --set TerminalEmulator kitty >/dev/null 2>&1 || true
  fi

  # Ensure helpers.rc exists and has a [Default] section
  if [ ! -f "$HELPER_DIR/helpers.rc" ]; then
    printf "[Default]\n" >"$HELPER_DIR/helpers.rc"
  elif ! grep -q '^\[Default\]$' "$HELPER_DIR/helpers.rc"; then
    printf "[Default]\n%s" "$(cat "$HELPER_DIR/helpers.rc")" >"$HELPER_DIR/helpers.rc"
  fi

  # Update TerminalEmulator entry in [Default] section
  if grep -q '^TerminalEmulator=' "$HELPER_DIR/helpers.rc"; then
    sed -i 's|^TerminalEmulator=.*|TerminalEmulator=kitty|' "$HELPER_DIR/helpers.rc"
  else
    sed -i '/^\[Default\]$/a TerminalEmulator=kitty' "$HELPER_DIR/helpers.rc"
  fi
  echo "TerminalEmulator=kitty" >>"$HELPER_DIR/helpers.rc"

  # 2. Create a User-Level "xterm" Shim
  # Many older .desktop files and scripts have 'xterm' hardcoded.
  # By placing this in ~/.local/bin, we intercept those calls.
  BIN_DIR="$HOME/.local/bin"
  mkdir -p "$BIN_DIR"
  if ! printf "%s" "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    echo "Warning: $BIN_DIR is not in PATH for this session. GUI apps may still use /usr/bin/xterm."
  fi

  cat <<EOF >"$BIN_DIR/xterm"
#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
#
# Shim to redirect xterm calls to kitty 
# Resolves Open with (vim/neovim/etc) opening in xterm 
args=()
pass_through=()
while [ \$# -gt 0 ]; do
  case "\$1" in
    -e)
      shift
      if [ \$# -gt 0 ]; then
        pass_through+=("\$@")
      fi
      break
      ;;
    -T|-title|-geometry|-bg|-fg|-fs|-fa|-fn)
      # Skip common xterm-only flags and their values
      shift
      [ \$# -gt 0 ] && shift
      ;;
    -class|-name)
      shift
      [ \$# -gt 0 ] && shift
      ;;
    -hold|-ls|-sb|-sk|-sr|-s)
      # Ignore boolean flags that kitty doesn't understand
      shift
      ;;
    *)
      args+=("\$1")
      shift
      ;;
  esac
done

if [ \${#pass_through[@]} -gt 0 ]; then
  exec kitty "\${args[@]}" -- "\${pass_through[@]}"
else
  exec kitty "\${args[@]}"
fi
EOF
  chmod +x "$BIN_DIR/xterm"

  # 3. Update GLib/GIO Default Terminal (for GNOME-based backends)
  # Some distros use gsettings to define the terminal schema.
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.default-applications.terminal exec 'kitty' 2>/dev/null || true
  fi

  # 4. Refresh Mime Database
  # Ensures Thunar sees the changes to terminal handling immediately.
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database ~/.local/share/applications 2>/dev/null || true
  fi

  echo "Default terminal set to kitty successfully."
}

setup_default_terminal
