#!/usr/bin/env bash
# setup-makeconf.sh — Deploy a hardware-tuned make.conf for KDE or DWM profiles.
# Run as root on the target Gentoo box.
# Usage: ./scripts/setup-makeconf.sh [kde|dwm]
set -euo pipefail

# ── Colour helpers ───────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { printf "${GREEN}>>>${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}>>>${NC} %s\n" "$*"; }
die()   { printf "${RED}ERROR:${NC} %s\n" "$*" >&2; exit 1; }

# ── Pre-flight checks ───────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Must be run as root (or via sudo)."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"             # one level up from scripts/
MAKECONF_TARGET="/etc/portage/make.conf"

# ── Choose profile ───────────────────────────────────────────────────
PROFILE="${1:-}"
if [[ -z "$PROFILE" ]]; then
    echo ""
    echo "Which desktop profile do you want?"
    echo "  1) kde   — Full KDE Plasma desktop"
    echo "  2) dwm   — Minimal suckless (dwm/st/dmenu)"
    echo ""
    read -rp "Enter choice [1/2]: " choice
    case "$choice" in
        1|kde)  PROFILE="kde" ;;
        2|dwm)  PROFILE="dwm" ;;
        *)      die "Invalid choice: $choice" ;;
    esac
fi

PROFILE_CONF="${REPO_DIR}/configs/${PROFILE}/make.conf"
[[ -f "$PROFILE_CONF" ]] || die "Profile config not found: $PROFILE_CONF"

info "Selected profile: $PROFILE"

# ── Install cpuid2cpuflags if missing ────────────────────────────────
if ! command -v cpuid2cpuflags &>/dev/null; then
    warn "cpuid2cpuflags not found — installing…"
    emerge --oneshot --quiet app-portage/cpuid2cpuflags
fi

# ── Gather CPU flags ────────────────────────────────────────────────
info "Detecting CPU flags…"
CPU_FLAGS="$(cpuid2cpuflags)"      # e.g. "CPU_FLAGS_X86: aes avx …"
# Normalise: the tool prints "CPU_FLAGS_X86: flags" — turn it into make.conf format
CPU_FLAGS_LINE="${CPU_FLAGS//: /=\"}\""   # CPU_FLAGS_X86="aes avx …"
info "Detected: $CPU_FLAGS_LINE"

# ── Back up existing make.conf ──────────────────────────────────────
if [[ -f "$MAKECONF_TARGET" ]]; then
    BACKUP="${MAKECONF_TARGET}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$MAKECONF_TARGET" "$BACKUP"
    info "Backed up current make.conf → $BACKUP"
fi

# ── Deploy template and inject CPU flags ─────────────────────────────
cp "$PROFILE_CONF" "$MAKECONF_TARGET"

# Replace the placeholder comment with the real CPU flags line
sed -i "s|^# CPU_FLAGS_X86=.*|${CPU_FLAGS_LINE}|" "$MAKECONF_TARGET"

info "Installed ${PROFILE} make.conf → $MAKECONF_TARGET"

# ── Deploy package.use overrides (if the profile ships one) ─────────
PROFILE_PKGUSE="${REPO_DIR}/configs/${PROFILE}/package.use"
PKGUSE_DIR="/etc/portage/package.use"

if [[ -f "$PROFILE_PKGUSE" ]]; then
    # Ensure the package.use directory exists (Portage accepts a dir here)
    mkdir -p "$PKGUSE_DIR"
    cp "$PROFILE_PKGUSE" "${PKGUSE_DIR}/99-${PROFILE}-profile"
    info "Installed package.use overrides → ${PKGUSE_DIR}/99-${PROFILE}-profile"
fi

echo ""
info "Next steps:"
echo "  1. Review:       less $MAKECONF_TARGET"
echo "  2. Update world: emerge --ask --update --deep --newuse @world"
echo ""
