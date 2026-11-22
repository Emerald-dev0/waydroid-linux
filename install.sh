#!/usr/bin/env bash
#
# waydroid-linux setup script
#
# Installs the helper scripts and desktop entry, and verifies that the host
# has the prerequisites Waydroid needs. Works across distros; detects the
# package manager and prints distro-correct install hints.
#
# Usage:
#   ./install.sh            # install scripts to ~/.local/bin + desktop entry
#   ./install.sh --check    # only verify prerequisites, don't install
#   ./install.sh --distro   # print detected distro + family
#
set -euo pipefail

BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;32m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[install]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[install]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Distro detection
# ---------------------------------------------------------------------------
DISTRO_NAME=""
DISTRO_FAMILY=""   # debian | arch | fedora | suse | unknown
PKG_INSTALL=""     # function name for install hints

detect_distro() {
    local id="" like=""
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        id="${ID:-}"
        like="${ID_LIKE:-}"
    fi

    DISTRO_NAME="${PRETTY_NAME:-${NAME:-unknown}}"

    case "$id" in
        debian|ubuntu|linuxmint|pop|elementary|zorin|neon|raspbian|kali)
            DISTRO_FAMILY="debian" ;;
        arch|manjaro|endeavouros|garuda|artix)
            DISTRO_FAMILY="arch" ;;
        fedora|rhel|centos|rocky|almalinux)
            DISTRO_FAMILY="fedora" ;;
        opensuse*|sles)
            DISTRO_FAMILY="suse" ;;
        *)
            # fall back to ID_LIKE matching
            case "$like" in
                *debian*|*ubuntu*) DISTRO_FAMILY="debian" ;;
                *arch*)            DISTRO_FAMILY="arch" ;;
                *fedora*|*rhel*)   DISTRO_FAMILY="fedora" ;;
                *suse*)            DISTRO_FAMILY="suse" ;;
                *)                 DISTRO_FAMILY="unknown" ;;
            esac
            ;;
    esac

    # map family -> install hint function
    case "$DISTRO_FAMILY" in
        debian) PKG_INSTALL="hint_debian" ;;
        arch)   PKG_INSTALL="hint_arch" ;;
        fedora) PKG_INSTALL="hint_fedora" ;;
        suse)   PKG_INSTALL="hint_suse" ;;
        *)      PKG_INSTALL="hint_unknown" ;;
    esac
}

hint_debian() {
    # $1 = logical name, rest = package names (may differ per distro)
    local name="$1"; shift
    warn "  sudo apt install $*"
}
hint_arch() {
    local name="$1"; shift
    warn "  # Arch: install from AUR (yay -S $*) or official repos"
    warn "  yay -S $*"
}
hint_fedora() {
    local name="$1"; shift
    warn "  # Fedora: enable the Waydroid COPR repo first:"
    warn "  sudo dnf copr enable waydroid/stable  # or: waydroid/stable"
    warn "  sudo dnf install $*"
}
hint_suse() {
    local name="$1"; shift
    warn "  # openSUSE: use the Waydroid community repo (one-click or zypper)"
    warn "  sudo zypper install $*"
}
hint_unknown() {
    local name="$1"; shift
    warn "  # Unknown distro — see https://docs.waydro.id/usage/install-on-desktops"
    warn "  # Install: $*"
}

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
check_prereqs() {
    local missing=0

    log "Detected distro: $DISTRO_NAME ($DISTRO_FAMILY family)"
    log "Checking prerequisites..."

    if ! command -v waydroid >/dev/null 2>&1; then
        warn "waydroid not found. Install it:"
        $PKG_INSTALL "waydroid" waydroid
        missing=1
    fi

    if ! command -v weston >/dev/null 2>&1; then
        warn "weston not found. Install it:"
        $PKG_INSTALL "weston" weston
        missing=1
    fi

    if ! command -v adb >/dev/null 2>&1; then
        warn "adb not found (needed for waydroid-emu). Install it:"
        $PKG_INSTALL "adb" android-tools adb
        missing=1
    fi

    if ! systemctl is-enabled waydroid-container >/dev/null 2>&1; then
        warn "waydroid-container service is not enabled. Enable it:"
        warn "  sudo systemctl enable --now waydroid-container"
        missing=1
    fi

    # binder module (only a hard failure if the module doesn't exist at all)
    if ! lsmod | grep -q "^binder"; then
        if ! modinfo binder_linux >/dev/null 2>&1; then
            warn "binder_linux kernel module is NOT available on this kernel."
            warn "  Waydroid cannot work without it. You may need a newer/ HWE kernel."
            warn "  Check: https://docs.waydro.id/usage/install-on-desktops"
            missing=1
        else
            warn "binder kernel module is not currently loaded (Waydroid loads it on demand)."
            warn "  To load now: sudo modprobe binder_linux"
        fi
    fi

    # SELinux note (Fedora/RHEL)
    if [ "$DISTRO_FAMILY" = "fedora" ] && command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
        warn "SELinux is enforcing — Waydroid may need a policy tweak:"
        warn "  sudo ausearch -c 'waydroid' --raw | audit2allow -M waydroid"
        warn "  sudo semodule -i waydroid.pp"
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
    detect_distro
    case "${1:-}" in
        --check) check_prereqs ;;
        --distro) log "$DISTRO_NAME ($DISTRO_FAMILY family)"; command -v waydroid >/dev/null && log "waydroid: installed" || log "waydroid: NOT installed" ;;
        ""|--install) check_prereqs; install ;;
        -h|--help)
            sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
            ;;
        *) die "Unknown option: $1 (try --help)" ;;
    esac
}

main "$@"