#!/bin/bash
#
# Pixie SDDM - one-shot privileged integration bootstrap for CachyOS/Arch.
#
# What it does (all system-side, all in this single sudo invocation):
#   1. Backs up and updates the installed theme (/usr/share/sddm/themes/pixie):
#      copies the current Main.qml and appends any missing wallpaper/matugen
#      keys to theme.conf (existing user customisations are preserved).
#   2. Creates the SDDM-readable shared wallpaper dir /var/lib/sddm/pixie (755).
#   3. Installs the root-owned, fixed /usr/local/bin/pixie-sddm-sync helper.
#   4. Installs /etc/sudoers.d/pixie-sddm-sync (440, visudo-validated) that
#      allows passwordless execution of that ONE helper only.
#   5. Runs the real wallpaper sync once for the present wallpaper.
# The systemd user units are installed afterwards as the normal user
# (no privileges needed) - see the notes this script prints at the end.
#
# Usage:  sudo ./scripts/system/bootstrap.sh
set -eu -o pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd -P)"
THEME_DIR="/usr/share/sddm/themes/pixie"
ASSETS_DIR="/var/lib/sddm/pixie"
HELPER="/usr/local/bin/pixie-sddm-sync"
SUDOERS_FILE="/etc/sudoers.d/pixie-sddm-sync"

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[0;33m'; NC='\033[0m'
msg()  { printf "${BLUE}==>${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}==>${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}==>${NC} %s\n" "$*"; }
die()  { printf "${RED}Error:${NC} %s\n" "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run with sudo:  sudo $0"
[ -f "$REPO/Main.qml" ] || die "Run from the pixie-sddm repository (Main.qml not found next to scripts/system)."
[ -d "$THEME_DIR" ] || die "Pixie SDDM is not installed at $THEME_DIR - run ./install.sh in the repo first."
DEPLOY_USER="${SUDO_USER:-}"
[ -n "$DEPLOY_USER" ] && [ "$DEPLOY_USER" != "root" ] || die "Could not determine the invoking user (run via 'sudo' from your normal account)."

# ---------------------------------------------------------------------------
# 1. Theme files: new Main.qml, merged theme.conf keys
# ---------------------------------------------------------------------------
msg "Updating installed theme in $THEME_DIR..."
cp -f -- "$REPO/Main.qml" "$THEME_DIR/Main.qml"
chmod 644 "$THEME_DIR/Main.qml"
if [ -d "$REPO/components" ]; then
    mkdir -p -- "$THEME_DIR/components"
    cp -rf -- "$REPO/components/." "$THEME_DIR/components/"
fi
if [ -d "$REPO/assets/fonts" ]; then
    mkdir -p -- "$THEME_DIR/assets"
    cp -rf -- "$REPO/assets/fonts" "$THEME_DIR/assets/" 2>/dev/null || true
fi
if [ -d "$REPO/scripts" ]; then
    mkdir -p -- "$THEME_DIR/scripts"
    cp -rf -- "$REPO/scripts/." "$THEME_DIR/scripts/"
    chmod 755 "$THEME_DIR/scripts" "$THEME_DIR/scripts/update-wallpaper.sh"
fi

THEME_CONF="$THEME_DIR/theme.conf"
STAMP="$(date +%Y%m%d-%H%M%S)"
if ! grep -q "^wallpaper=" "$THEME_CONF" 2>/dev/null; then
    cp -f -- "$THEME_CONF" "$THEME_CONF.bak.$STAMP"
    ok "Backed up the old theme.conf to $(basename "$THEME_CONF").bak.$STAMP"
fi

set_key() {  # set_key FILE KEY VALUE - replaces in place, appends when missing
    local file="$1" key="$2" val="$3"
    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=$(printf '%s' "$val" | sed -e 's/[\\|&]/\\\\&/g')|" "$file"
    else
        printf '%s=%s\n' "$key" "$val" >> "$file"
    fi
}
set_key "$THEME_CONF" "wallpaper"       ""
set_key "$THEME_CONF" "matugen"         "false"
set_key "$THEME_CONF" "matugenAccent"   "$(grep -m1 '^accentColor=' "$THEME_CONF" | cut -d= -f2-)"
set_key "$THEME_CONF" "matugenBackground" "$(grep -m1 '^backgroundColor=' "$THEME_CONF" | cut -d= -f2-)"
set_key "$THEME_CONF" "matugenText"     "$(grep -m1 '^textColor=' "$THEME_CONF" | cut -d= -f2-)"
ok "theme.conf now carries wallpaper/matugen keys (existing values preserved)."

# ---------------------------------------------------------------------------
# 2. Shared, SDDM-readable wallpaper directory
# ---------------------------------------------------------------------------
msg "Preparing $ASSETS_DIR ..."
mkdir -p -- "$ASSETS_DIR"
chmod 0755 "$ASSETS_DIR"
ok "Shared wallpaper dir ready (root:root, 755 - greeter can read it)."

# ---------------------------------------------------------------------------
# 3. Fixed helper in /usr/local/bin
# ---------------------------------------------------------------------------
msg " Installing $HELPER (root-owned, takes no arguments) ..."
install -o root -g root -m 0755 "$REPO/scripts/system/pixie-sddm-sync" "$HELPER"
ok "Helper installed."

# ---------------------------------------------------------------------------
# 4. sudoers drop-in for passwordless runs of exactly that ONE helper
# ---------------------------------------------------------------------------
msg "Installing $SUDOERS_FILE ..."
printf '%s ALL=(root) NOPASSWD: /usr/local/bin/pixie-sddm-sync\n' "$DEPLOY_USER" > "$SUDOERS_FILE"
chmod 0440 "$SUDOERS_FILE"
chown root:root "$SUDOERS_FILE"
if command -v visudo >/dev/null 2>&1 && ! visudo -c >/dev/null 2>&1; then
    die "sudoers validation failed; removing the drop-in to keep sudo intact. Check $SUDOERS_FILE."
fi
ok "sudoers entry validated: user '$DEPLOY_USER' may run '$HELPER' (passwordless, no other privileges)."

# ---------------------------------------------------------------------------
# 5. First real sync (this is not a dry run)
# ---------------------------------------------------------------------------
STATE_FILE="$(getent passwd "$DEPLOY_USER" | cut -d: -f6)/.local/state/quickshell/user/generated/wallpaper/path.txt"
if [ -r "$STATE_FILE" ] && [ -s "$STATE_FILE" ]; then
    WALL="$(tr -d '\r\n' <"$STATE_FILE")"
    if [ -n "$WALL" ] && [ -f "$WALL" ]; then
        msg "Running the real wallpaper sync for: $WALL"
        HOME="$(getent passwd "$DEPLOY_USER" | cut -d: -f6)" "$REPO/scripts/update-wallpaper.sh" --theme-dir "$THEME_DIR" --assets-dir "$ASSETS_DIR" "$WALL" || \
            warn "First sync failed - see the message above. The hook will retry on the next wallpaper change."
    else
        warn "Wallpaper state file present but the wallpaper is missing/empty; skipping first sync."
    fi
else
    warn "No wallpaper state file found ($STATE_FILE); the hook will sync on the next wallpaper change."
fi

# ---------------------------------------------------------------------------
# Done - user-side steps
# ---------------------------------------------------------------------------
echo ""
ok "System-side integration complete. Final step (as your user, no sudo):"
echo "  ~/.config/systemd/user/pixie-sddm-sync.path and .service are provided in"
echo "  $REPO/scripts/system/. Install and enable them with:"
echo ""
echo "    install -Dm644 $REPO/scripts/system/pixie-sddm-sync.path   ~/.config/systemd/user/pixie-sddm-sync.path"
echo "    install -Dm644 $REPO/scripts/system/pixie-sddm-sync.service ~/.config/systemd/user/pixie-sddm-sync.service"
echo "    systemctl --user daemon-reload && systemctl --user enable --now pixie-sddm-sync.path"
echo ""
echo "  Preview the greeter:  sddm-greeter-qt6 --test-mode --theme $THEME_DIR"
