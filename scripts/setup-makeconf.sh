#!/usr/bin/env bash
# setup-makeconf.sh — Deploy a hardware-tuned make.conf for KDE or DWM profiles.
# Run as root on the target Gentoo box.
#
# Prerequisite: you selected the OpenRC *desktop* profile during the Gentoo
# install (e.g. default/linux/amd64/23.0/desktop or desktop/openrc).
# This keeps the USE-flag delta small and avoids circular dependency issues.
#
# What this script does:
#   1. Asks which desktop you want (KDE or DWM)
#   2. Checks your eselect profile is a desktop profile
#   3. For KDE: auto-upgrades the profile to desktop/plasma
#   4. Detects your CPU flags (CPU_FLAGS_X86) using cpuid2cpuflags
#   5. Backs up your existing make.conf
#   6. Deploys the profile-specific make.conf with CPU flags injected
#   7. Offers to run emerge --update --deep --newuse @world
#
# Usage:
#   ./scripts/setup-makeconf.sh              # interactive — asks KDE or DWM
#   ./scripts/setup-makeconf.sh kde          # skip profile question (still prompts for @world)
#   ./scripts/setup-makeconf.sh dwm          # skip profile question (still prompts for @world)
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

# ── Verify the eselect profile looks right ───────────────────────────
# The eselect profile controls which base USE flags Portage enables.
# A "desktop" profile pre-enables flags like X, dbus, elogind — if you're
# on the minimal profile instead, the @world update would need to flip
# hundreds of flags at once, which often causes circular dependency errors.
info "Checking current eselect profile…"
CURRENT_PROFILE="$(eselect profile show | tail -1 | xargs)"
info "Active profile: $CURRENT_PROFILE"

if ! echo "$CURRENT_PROFILE" | grep -qE 'desktop'; then
    warn "Your current profile does not look like a desktop profile."
    warn "This guide assumes you selected the OpenRC desktop profile during install."
    warn "  e.g.  default/linux/amd64/23.0/desktop"
    echo ""
    warn "If you are on a minimal profile, the @world update may hit circular"
    warn "dependency errors. Consider running:"
    warn "  eselect profile list"
    warn "  eselect profile set <N>   # pick desktop or desktop/openrc"
    echo ""
    read -rp "Continue anyway? [y/N]: " confirm
    case "$confirm" in
        [yY]|[yY][eE][sS]) ;;
        *) die "Aborting. Set a desktop profile first, then re-run." ;;
    esac
fi

# ── For KDE: upgrade to desktop/plasma profile ──────────────────────
# The plasma sub-profile adds KDE/Qt USE flags at the profile level,
# so you don't have to carry them all in make.conf. The script auto-detects
# the right profile number from eselect output.
if [[ "$PROFILE" == "kde" ]] && ! echo "$CURRENT_PROFILE" | grep -qE 'plasma'; then
    info "KDE selected — upgrading eselect profile to desktop/plasma…"

    PLASMA_NUM=""
    PLASMA_NAME=""
    while IFS= read -r line; do
        # Extract the profile number from lines like: [14]  default/.../desktop/plasma (stable)
        # Using sed instead of grep -oP for portability (pcre USE flag may not be set)
        local_num="$(echo "$line" | sed -n 's/.*\[\([0-9]*\)\].*/\1/p')"
        local_name="$(echo "$line" | sed 's/.*\] *//' | sed 's/ *(.*//' | xargs)"
        [[ -z "$local_num" ]] && continue

        # Prefer desktop/plasma/openrc, fall back to desktop/plasma
        if echo "$local_name" | grep -qE 'desktop/plasma/openrc$'; then
            PLASMA_NUM="$local_num"; PLASMA_NAME="$local_name"; break
        elif echo "$local_name" | grep -qE 'desktop/plasma$' && [[ -z "$PLASMA_NUM" ]]; then
            PLASMA_NUM="$local_num"; PLASMA_NAME="$local_name"
        fi
    done < <(eselect profile list)

    if [[ -n "$PLASMA_NUM" ]]; then
        info "Switching to: $PLASMA_NAME (index $PLASMA_NUM)"
        eselect profile set "$PLASMA_NUM"
    else
        warn "Could not find a desktop/plasma profile. Continuing with current profile."
        warn "You may want to set it manually:  eselect profile list"
    fi
fi

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

# ── Update @world ────────────────────────────────────────────────────
# @world is Portage's set of all explicitly installed packages plus their
# dependencies. Updating it with --newuse tells Portage to rebuild any
# package whose USE flags changed (because of the new make.conf).
echo ""
info "make.conf deployed. Ready to update @world with new USE flags."
echo ""
info "Review the result:"
echo "  less $MAKECONF_TARGET"
echo ""
read -rp "Update @world now? [Y/n]: " confirm
case "$confirm" in
    [nN]|[nN][oO])
        info "Skipped. Run manually when ready:"
        echo "  emerge --ask --update --deep --newuse @world"
        ;;
    *)
        info "Updating @world…"
        # --ask    → show what will be merged and ask for confirmation
        # --update → update packages to latest available versions
        # --deep   → check the ENTIRE dependency tree, not just top-level
        # --newuse → rebuild packages whose USE flags changed
        emerge --ask --update --deep --newuse @world

        # ── Cleanup ─────────────────────────────────────────────────
        # depclean removes packages that are no longer required by anything
        # in your @world set (orphaned dependencies from old USE flags).
        info "Cleaning orphaned packages…"
        emerge --ask --depclean

        # revdep-rebuild scans installed libraries and rebuilds any package
        # that links against a library that no longer exists (broken .so links).
        if ! command -v revdep-rebuild &>/dev/null; then
            emerge --oneshot app-portage/gentoolkit
        fi
        info "Checking for broken library links…"
        revdep-rebuild

        # env-update regenerates /etc/env.d cache files (ld.so.conf, PATH, etc.)
        info "Refreshing environment…"
        env-update

        echo ""
        info "Done! @world is up to date."
        info "Run 'source /etc/profile' or open a new shell to pick up env changes."
        ;;
esac

echo ""
info "Next steps:"
if [[ "$PROFILE" == "kde" ]]; then
    echo "  → Follow docs/03-kde-plasma-setup.html"
else
    echo "  → Follow docs/04-dwm-suckless-setup.html"
fi
