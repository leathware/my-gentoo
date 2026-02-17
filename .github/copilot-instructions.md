# Copilot instructions for my-gentoo

## What this repo is
A post-install manual for **Gentoo minimal OpenRC** targeting AMD hardware
(9800X3D + RX 7800 XT + X870 Taichi Lite). Two desktop paths: **KDE Plasma**
(full) and **DWM / suckless** (minimal).

## Repo layout
- `configs/kde/make.conf` / `configs/dwm/make.conf` — make.conf templates with profile-specific USE flags.
- `scripts/setup-makeconf.sh` — Bash script that deploys a template, runs `cpuid2cpuflags`, and injects `CPU_FLAGS_X86`.
- `docs/01-post-install-base.md` — Common steps after a fresh install (services, firmware, user, audio, networking).
- `docs/02-kernel-customization.md` — Custom kernel config for the exact hardware.
- `docs/03-kde-plasma-setup.md` — Full KDE Plasma desktop guide.
- `docs/04-dwm-suckless-setup.md` — DWM + st + dmenu suckless guide.
- `README.md` — Project hub and quick-start.

## Conventions
- All commands assume **OpenRC** (never `systemctl`); use `rc-update` / `rc-service`.
- `emerge` commands always include `-a` (ask) for safety.
- make.conf templates use `-march=native`; the script handles CPU flag detection.
- DWM guide relies on Portage `savedconfig` for suckless config.h workflow.
- Docs are numbered sequentially; new guides should continue the numbering scheme.

## Editing guidance
- When adding packages, note the exact `emerge` atom and any required USE flags or `/etc/portage/package.use` entries.
- Keep per-profile USE flags in the matching `configs/*/make.conf`; global advice goes in the docs.
- The setup script must stay POSIX-ish bash (`set -euo pipefail`), root-only, and idempotent (backs up existing make.conf).
- Reference hardware specifics (kernel config symbols, firmware blob names, PCI device IDs) when they matter.
- If adding a new desktop profile, create `configs/<name>/make.conf` and a corresponding `docs/` guide.
