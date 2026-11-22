#!/usr/bin/env bash
#
# waydroid-linux setup script
#
# Installs the helper scripts and desktop entry, and verifies that the host
# has the prerequisites Waydroid needs. Designed for Debian/Ubuntu/Linux Mint.
#
# Usage:
#   ./install.sh            # install scripts to ~/.local/bin + desktop entry
#   ./install.sh --check    # only verify prerequisites, don't install
#
set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;32m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[install]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[install]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
check_prereqs() {
    local missing=0

    log "Checking prerequisites..."

    if ! command -v waydroid >/dev/null 2>&1; then
        warn "waydroid not found. Install it first:"
        warn "  sudo apt install waydroid   # Debian/Ubuntu/Mint"
        warn "  # or see https://docs.waydro.id/usage/install-on-desktops"
        missing=1
    fi

    if ! command -v weston >/dev/null 2>&1; then
        warn "weston not found. Install it:"
        warn "  sudo apt install weston"
        missing=1
    fi

    if ! command -v adb >/dev/null 2>&1; then
        warn "adb not found (needed for waydroid-emu). Install it:"
        warn "  sudo apt install adb"
        warn "  # or: sudo apt install android-sdk-platform-tools"
        missing=1
    fi

    if ! systemctl is-enabled waydroid-container >/dev/null 2>&1; then
        warn "waydroid-container service is not enabled. Enable it:"
        warn "  sudo systemctl enable --now waydroid-container"
        missing=1
    fi

    # binder module
    if ! lsmod | grep -q "^binder"; then
        warn "binder kernel module is not loaded. Load it:"
        warn "  sudo modprobe binder_linux"
        warn "  echo binder_linux | sudo tee /etc/modules-load.d/binder.conf"
    fi

    if [ "$missing" -eq 1 ]; then
        die "Missing prerequisites. Fix the items above and re-run."
    fi

    log "All prerequisites look good."
}

# ---------------------------------------------------------------------------
# Install
# ---------------------------------------------------------------------------
install() {
    mkdir -p "$BIN_DIR" "$DESKTOP_DIR"

    log "Installing scripts to $BIN_DIR"
    install -m 0755 "$SCRIPT_DIR/bin/waydroid-ui"   "$BIN_DIR/waydroid-ui"
    install -m 0755 "$SCRIPT_DIR/bin/waydroid-emu"  "$BIN_DIR/waydroid-emu"
    install -m 0755 "$SCRIPT_DIR/bin/waydroid-tune" "$BIN_DIR/waydroid-tune"

    log "Installing desktop entry to $DESKTOP_DIR"
    sed "s|__BIN_DIR__|$BIN_DIR|g" \
        "$SCRIPT_DIR/desktop/waydroid-ui.desktop.in" \
        > "$DESKTOP_DIR/waydroid-ui.desktop"

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
    fi

    log "Done. Installed:"
    log "  - waydroid-ui   (windowed Android on X11)"
    log "  - waydroid-emu  (headless Android + ADB for automation)"
    log "  - waydroid-tune (optional CPU governor tuning)"
    log ""
    log "Launch 'Waydroid' from your app menu, or run 'waydroid-emu start'."
}

main() {
    case "${1:-}" in
        --check) check_prereqs ;;
        ""|--install) check_prereqs; install ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
            ;;
        *) die "Unknown option: $1 (try --help)" ;;
    esac
}

main "$@"