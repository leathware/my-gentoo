#!/usr/bin/env bash
# setup-makeconf.sh — Deploy a hardware-tuned make.conf for KDE or DWM profiles.
# Run as root on the target Gentoo box.
#
# What this script does (and ONLY this):
#   1. Asks which desktop you want (KDE or DWM)
#   2. Installs cpuid2cpuflags if missing
#   3. Detects your CPU flags (CPU_FLAGS_X86)
#   4. Backs up your existing make.conf
#   5. Deploys the profile-specific make.conf with CPU flags injected
#
# It does NOT run emerge, change your eselect profile, or touch @world.
# You do those steps yourself — see the docs for the commands.
#
# Usage:
#   ./scripts/setup-makeconf.sh              # interactive — asks KDE or DWM
#   ./scripts/setup-makeconf.sh kde          # deploy KDE make.conf
#   ./scripts/setup-makeconf.sh dwm          # deploy DWM make.conf
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
# cpuid2cpuflags reads your CPU's feature flags (SSE, AVX, AES, etc.) and
# outputs them in the format Portage expects. Packages use these flags to
# enable optimised code paths at compile time.
if ! command -v cpuid2cpuflags &>/dev/null; then
    warn "cpuid2cpuflags not found — installing…"
    # --oneshot means "install but don't add to @world" — it's a build tool,
    # not something you need to track for updates.
    emerge --oneshot --quiet app-portage/cpuid2cpuflags
fi

# ── Gather CPU flags ────────────────────────────────────────────────
info "Detecting CPU flags…"
CPU_FLAGS="$(cpuid2cpuflags)"      # e.g. "CPU_FLAGS_X86: aes avx …"
# Normalise: the tool prints "CPU_FLAGS_X86: flags" — turn it into make.conf format
CPU_FLAGS_LINE="${CPU_FLAGS//: /=\"}\""   # CPU_FLAGS_X86="aes avx …"
info "Detected: $CPU_FLAGS_LINE"

# ── Back up existing make.conf ──────────────────────────────────────
# Always keep a timestamped backup so you can roll back if something
# goes wrong. The backup lives right next to the original.
if [[ -f "$MAKECONF_TARGET" ]]; then
    BACKUP="${MAKECONF_TARGET}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$MAKECONF_TARGET" "$BACKUP"
    info "Backed up current make.conf → $BACKUP"
fi

# ── Deploy template and inject CPU flags ─────────────────────────────
# Copy the profile template over /etc/portage/make.conf, then replace the
# placeholder comment with the real CPU flags detected above.
cp "$PROFILE_CONF" "$MAKECONF_TARGET"
sed -i "s|^# CPU_FLAGS_X86=.*|${CPU_FLAGS_LINE}|" "$MAKECONF_TARGET"

info "Installed ${PROFILE} make.conf → $MAKECONF_TARGET"

# ── Done — tell the user what to do next ─────────────────────────────
echo ""
info "make.conf deployed. Review it:"
echo "  cat $MAKECONF_TARGET"
echo ""
info "Next steps (run these yourself):"
echo ""
if [[ "$PROFILE" == "kde" ]]; then
    echo "  # 1. Switch to the desktop/plasma profile:"
    echo "  eselect profile list"
    echo "  eselect profile set <N>   # pick desktop/plasma or desktop/plasma/openrc"
    echo ""
fi
echo "  # $(if [[ "$PROFILE" == "kde" ]]; then echo "2"; else echo "1"; fi). Update @world with the new USE flags:"
echo "  emerge --ask --update --deep --newuse @world"
echo ""
echo "  # $(if [[ "$PROFILE" == "kde" ]]; then echo "3"; else echo "2"; fi). Clean up orphaned packages:"
echo "  emerge --ask --depclean"
echo ""
echo "  # $(if [[ "$PROFILE" == "kde" ]]; then echo "4"; else echo "3"; fi). Check for broken library links:"
echo "  revdep-rebuild"
echo ""
echo "  # $(if [[ "$PROFILE" == "kde" ]]; then echo "5"; else echo "4"; fi). Refresh the environment:"
echo "  env-update && source /etc/profile"
echo ""
if [[ "$PROFILE" == "kde" ]]; then
    info "Then follow: docs/03-kde-plasma-setup.html"
else
    info "Then follow: docs/04-dwm-suckless-setup.html"
fi
