#!/bin/bash
#
# change-avatar.sh - install a per-user profile picture for the Pixie SDDM
# greeter.
#
# Usage:
#   change-avatar.sh <username> <image>     install/replace a user's avatar
#   change-avatar.sh --remove <username>    remove a user's avatar
#   change-avatar.sh --list                 list installed avatars
#
# What it does:
#   1. Validates the username and the image file (type checked, never trusted).
#   2. Normalizes the image: EXIF auto-orient, stripped metadata and scaled to
#      fit inside a 512x512 box (aspect preserved, never upscaled). Huge/odd
#      input lands as a small clean PNG; the circular framing and aspect-fill
#      center crop stay in the theme (Main.qml Canvas), so the design layout is
#      untouched regardless of the source image shape.
#   3. Installs it into the shared SDDM assets dir (where the greeter already
#      reads its wallpaper from) and records it in avatars/avatars.json.
#
# The greeter runs as an unprivileged user and cannot read $HOME, exactly like
# the wallpaper sync - which is why avatars are copied to the shared dir.
#
# Examples:
#   ./change-avatar.sh satoru ~/Pictures/me.png
#   sudo change-avatar.sh satoru ~/Pictures/me.png   (when the assets dir is root-owned)

set -u -o pipefail

# ----------------------------------------------------------------------------
# Defaults (overridable for tests / Nix-like installs via env)
# ----------------------------------------------------------------------------
THEME_DIR="${PIXIE_THEME_DIR:-/usr/share/sddm/themes/pixie}"
ASSETS_DIR="${PIXIE_ASSETS_DIR:-/var/lib/sddm/pixie}"
AVATAR_DIR="${ASSETS_DIR}/avatars"
THEME_CONF="${THEME_DIR}/theme.conf"
AVATAR_MAX=512

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[0;33m'; NC='\033[0m'
msg() { printf "${BLUE}==>${NC} %s\n" "$*"; }
ok()  { printf "${GREEN} ==>${NC} %s\n" "$*"; }
warn(){ printf "${YELLOW} ==>${NC} %s\n" "$*"; }
die() { printf "${RED} ==>${NC} %s\n" "$*" >&2; exit 1; }

usage() {
    sed -n '2,12p' "$SELF" 2>/dev/null | sed 's/^# \{0,1\}//'
    exit 0
}

# ----------------------------------------------------------------------------
# Privilege handling - mirror scripts/update-wallpaper.sh: re-exec via sudo
# only when our writes would fail as the current user.
# ----------------------------------------------------------------------------
needs_privileges() {
    [ "$(id -u)" -eq 0 ] && return 1
    if [ "${ACTION}" = "list" ]; then return 1; fi
    if [ -d "$ASSETS_DIR" ]; then [ -w "$ASSETS_DIR" ] || return 0
    else [ -d "/var/lib/sddm" ] && [ -w "/var/lib/sddm" ] || return 0; fi
    [ -f "$THEME_CONF" ] && [ -w "$THEME_CONF" ] || return 0
    return 1
}

escalate() {
    [ -x "$(command -v sudo)" ] || die "target not writable and sudo unavailable - run as root."
    msg "Writing needs root access - retrying via sudo..."
    if [ -t 0 ]; then
        exec sudo -E env PATH="$PATH" PIXIE_THEME_DIR="$THEME_DIR" PIXIE_ASSETS_DIR="$ASSETS_DIR" -- "$SELF" "$@"
    fi
    die "cannot prompt for sudo (no tty) - run this script directly with sudo."
}

# ----------------------------------------------------------------------------
# Work
# ----------------------------------------------------------------------------
validate_args() {  # dry validation, runs BEFORE any privilege escalation
    case "${ACTION}" in
        install)
            cleanup_user "$AVATAR_USER" >/dev/null
            [ -n "$AVATAR_IMAGE" ] || die "no image given."
            [ -f "$AVATAR_IMAGE" ] || die "Image file not found: $AVATAR_IMAGE"
            [ -r "$AVATAR_IMAGE" ] || die "Image file not readable: $AVATAR_IMAGE"
            local ftype; ftype="$(image_type_of "$AVATAR_IMAGE")"
            case "$ftype" in
                *jpeg|*jpg|*png|*gif|*webp|*bmp|*heif|*tiff) ;;
                *) die "Not a recognized image ($AVATAR_IMAGE, type: ${ftype:-unknown})." ;;
            esac
            ;;
        remove) cleanup_user "$REMOVE_USER" >/dev/null ;;
    esac
}

cleanup_user() {  # validate username -> echo it, or die
    local user="$1"
    printf '%s' "$user" | grep -qE '^[A-Za-z_][A-Za-z0-9_-]{0,31}$' \
        || die "invalid username '$user' (expected POSIX-ish: [A-Za-z_][A-Za-z0-9_-]{0,31})"
    printf '%s' "$user"
}

image_type_of() {  # echo lowercase mime type of an image, empty when unknown
    local f="$1"
    if command -v magick >/dev/null 2>&1; then
        magick identify -ping -format '%m' -- "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]'
    elif command -v identify >/dev/null 2>&1; then
        identify -ping -format '%m' -- "$f" 2>/dev/null | tr '[:upper:]' '[:lower:]'
    elif command -v file >/dev/null 2>&1; then
        file -b --mime-type -- "$f" 2>/dev/null | cut -d/ -f2
    fi
}

# ----------------------------------------------------------------------------
# theme.conf key handling (avatar_<username> keys) - mirrors update-wallpaper.sh
# ----------------------------------------------------------------------------
ini_escape() { printf '%s' "$1" | sed -e 's/[\\\\|&]/\\\\&/g'; }

set_key() {   # set_key FILE KEY [VALUE]   (in place, appends when missing)
    local file="$1" key="$2" val="${3-}"
    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=$(ini_escape "$val")|" "$file"
    else
        printf '%s=%s\n' "$key" "$val" >> "$file"
    fi
}

get_key() { grep -m1 "^${2}=" "$1" 2>/dev/null | cut -d= -f2- ; }

avatar_key_of() { printf 'avatar_%s' "$1"; }

avatar_entries() {  # list every avatar_<user>=path from theme.conf
    [ -f "$THEME_CONF" ] || return 0
    grep -E '^avatar_[A-Za-z_][A-Za-z0-9_-]*=' "$THEME_CONF" 2>/dev/null | sort
}

do_list() {
    local out; out="$(avatar_entries)"
    if [ -z "$out" ]; then msg "No per-user avatars recorded in $THEME_CONF."; exit 0; fi
    printf '%s\n' "$out"
}

do_remove() {
    local user; user="$(cleanup_user "$REMOVE_USER")"
    local key; key="$(avatar_key_of "$user")"
    if [ -f "$THEME_CONF" ] && grep -qE "^${key}=" "$THEME_CONF"; then
        sed -i "/^${key}=/d" "$THEME_CONF"
    fi
    if [ -f "${AVATAR_DIR}/${user}.png" ]; then rm -f -- "${AVATAR_DIR}/${user}.png"; fi
    ok "Removed avatar for '$user' (falls back to the bundled default/icon)."
}

do_install() {
    local user; user="$(cleanup_user "$AVATAR_USER")"
    local img="$AVATAR_IMAGE"

    # ---- Validate the user actually exists (best effort, cosmetic) ----
    if command -v getent >/dev/null 2>&1 && ! getent passwd "$user" >/dev/null 2>&1; then
        warn "User '$user' is not a system account (installing anyway - SDDM shows what you pick)."
    fi

    # ---- Validate the image ----
    [ -f "$img" ] || die "Image file not found: $img"
    [ -r "$img" ] || die "Image file not readable: $img"
    local ftype; ftype="$(image_type_of "$img")"
    case "$ftype" in
        *jpeg|*jpg|*png|*gif|*webp|*bmp|*heif|*tiff) ;;
        *) die "Not a recognized image ($img, type: ${ftype:-unknown})." ;;
    esac

    # ---- Normalize: auto-orient, strip, scale to fit 512x512 (no upscale) ----
    mkdir -p -- "$AVATAR_DIR"
    chmod 0755 -- "$AVATAR_DIR" 2>/dev/null || true
    local dst="${AVATAR_DIR}/${user}.png"
    local tmp; tmp="$(mktemp "${AVATAR_DIR}/.incoming-${user}-XXXXXX.png")"

    if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
        local conv=(convert); command -v magick >/dev/null 2>&1 && conv=(magick)
        "${conv[@]}" "$img" -auto-orient -strip -resize "${AVATAR_MAX}x${AVATAR_MAX}>" \
            -define png:compression-level=9 "PNG24:$tmp" \
            || { rm -f -- "$tmp"; die "Image processing failed for: $img"; }
    else
        warn "ImageMagick not found - installing unprocessed copy as PNG."
        cp -f -- "$img" "$tmp" || { rm -f -- "$tmp"; die "Copy failed."; }
    fi
    chmod 0644 -- "$tmp"

    # ---- Ship it atomically: image first, then the theme.conf key ----
    mv -f -- "$tmp" "$dst"
    set_key "$THEME_CONF" "$(avatar_key_of "$user")" "$dst"
    ok "Avatar for '$user' installed: $dst"
    ok "theme.conf: $(avatar_key_of "$user")=$dst (used on the next lock/login screen)."

    if command -v magick >/dev/null 2>&1 || command -v identify >/dev/null 2>&1; then
        local dims; dims="$( (command -v magick >/dev/null 2>&1 && magick identify -ping -format '%wx%h' -- "$dst" 2>/dev/null) || identify -ping -format '%wx%h' -- "$dst" 2>/dev/null)"
        msg "Stored as ${dims} PNG; the greeter keeps the circular design layout."
    fi
    msg "On the next lock/login screen the avatar replaces the bundled default."
}

main() {
    export SELF="${BASH_SOURCE[0]}"
    ACTION="install"; AVATAR_USER=""; AVATAR_IMAGE=""; REMOVE_USER=""

    case "${1:-}" in
        ""|-h|--help) usage ;;
        --list) ACTION="list" ;;
        --remove) [ $# -eq 2 ] || die "usage: $SELF --remove <username>"; ACTION="remove"; REMOVE_USER="$2" ;;
        *) [ $# -eq 2 ] || die "usage: $SELF <username> <image>  (or --remove <username> / --list)"; AVATAR_USER="$1"; AVATAR_IMAGE="$2" ;;
    esac

    if [ "${ACTION}" = "list" ]; then do_list; exit 0; fi
    validate_args
    if needs_privileges; then escalate "$@"; fi
    if [ "${ACTION}" = "remove" ]; then do_remove; else do_install; fi
    exit 0
}

main "$@"
