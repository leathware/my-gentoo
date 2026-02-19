# my-gentoo

Post-install manual for a **Gentoo minimal OpenRC** system on AMD hardware.  
Covers two desktop paths — **full KDE Plasma** and **minimal DWM / suckless** — with
hardware-tuned `make.conf` configs, a CPU-flags setup script, and a custom kernel
guide.

> **Important:** During the Gentoo install, select the right **desktop profile**:
> - **DWM** → `default/linux/amd64/23.0/desktop` (plain desktop — no KDE/Qt bloat)
> - **KDE** → `default/linux/amd64/23.0/desktop/plasma` (adds KDE/Qt USE flags)
>
> This avoids circular dependency issues when applying desktop USE flags later.

## Hardware target

| Component | Model |
|---|---|
| CPU | AMD Ryzen 9 9800X3D (Zen 5, 8C/16T) |
| GPU | AMD Radeon RX 7800 XT (RDNA 3) |
| Board | ASRock X870 Taichi Lite (AM5) |
| Optical | DVD reader (SATA) |
| Init | OpenRC |

## Quick start

```bash
# On your freshly installed Gentoo box (desktop profile already set):
git clone https://github.com/leathware/my-gentoo.git
cd my-gentoo

# Deploy make.conf with auto-detected CPU flags:
sudo ./scripts/setup-makeconf.sh          # interactive — asks KDE or DWM
sudo ./scripts/setup-makeconf.sh kde      # deploy KDE make.conf
sudo ./scripts/setup-makeconf.sh dwm      # deploy DWM make.conf

# Then run these yourself (see docs for full explanations):
emerge --ask --update --deep --newuse @world
emerge --ask --depclean
revdep-rebuild
env-update && source /etc/profile
```

## Guides (read in order)

| # | Guide | What it covers |
|---|---|---|
| 0 | [make.conf Master Reference](docs/00-make-conf-reference.html) | Every make.conf setting explained, KDE vs DWM comparison, package.use guide |
| 1 | [Post-Install Base](docs/01-post-install-base.html) | @world rebuild, services, firmware, user, networking, audio, DVD |
| 2 | [Kernel Customization](docs/02-kernel-customization.html) | Building a custom kernel for 9800X3D + 7800 XT (AMDGPU, NVMe, audio, USB, BT) |
| 3a | [KDE Plasma Setup](docs/03-kde-plasma-setup.html) | Full Plasma desktop, SDDM, Wayland, apps, theming |
| 3b | [DWM / Suckless Setup](docs/04-dwm-suckless-setup.html) | dwm + st + dmenu, savedconfig workflow, patches, companion tools |

## Repository layout

```
configs/
  kde/make.conf          # make.conf template — KDE Plasma profile
  dwm/make.conf          # make.conf template — DWM suckless profile
scripts/
  setup-makeconf.sh      # Deploys make.conf + auto-detects CPU flags
docs/
  00-make-conf-reference.html     # master make.conf reference (single source of truth)
  01-post-install-base.html
  02-kernel-customization.html
  03-kde-plasma-setup.html
  04-dwm-suckless-setup.html
```

## License

Do whatever you want with this. No warranty.