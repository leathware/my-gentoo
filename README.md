# my-gentoo

Post-install manual for a **Gentoo minimal OpenRC** system on AMD hardware.  
Covers two desktop paths — **full KDE Plasma** and **minimal DWM / suckless** — with
hardware-tuned `make.conf` configs, a CPU-flags setup script, and a custom kernel
guide.

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
# On your freshly installed Gentoo box:
git clone https://github.com/leathware/my-gentoo.git
cd my-gentoo

# Deploy the right make.conf (interactive — asks kde or dwm, inserts CPU flags)
sudo ./scripts/setup-makeconf.sh
```

## Guides (read in order)

| # | Guide | What it covers |
|---|---|---|
| 1 | [Post-Install Base](docs/01-post-install-base.html) | Profile, make.conf, @world rebuild, services, firmware, user, networking, audio, DVD |
| 2 | [Kernel Customization](docs/02-kernel-customization.html) | Building a custom kernel for 9800X3D + 7800 XT (AMDGPU, NVMe, audio, USB, BT) |
| 3a | [KDE Plasma Setup](docs/03-kde-plasma-setup.html) | Full Plasma desktop, SDDM, Wayland, apps, theming |
| 3b | [DWM / Suckless Setup](docs/04-dwm-suckless-setup.html) | dwm + st + dmenu, savedconfig workflow, patches, companion tools |

## Repository layout

```
configs/
  kde/make.conf          # make.conf template — KDE Plasma profile
  dwm/make.conf          # make.conf template — DWM suckless profile
scripts/
  setup-makeconf.sh      # Deploys make.conf + auto-detects CPU_FLAGS_X86
docs/
  01-post-install-base.html
  02-kernel-customization.html
  03-kde-plasma-setup.html       # includes KDE make.conf
  04-dwm-suckless-setup.html     # includes DWM make.conf
```

## License

Do whatever you want with this. No warranty.