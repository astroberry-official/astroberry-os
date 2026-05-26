# Astroberry OS
Astroberry OS is an operating system for controlling astronomy equipment. It has been primarily built for 64-bit Raspberry Pi 4 and Raspberry Pi 5. Since version 3.2 the system also supports amd64 / x86_64 devices. Download system images from [astroberry.io](https://astroberry.io/download/).

[![Astroberry OS](.github/video-thumbnail.jpg)](http://www.youtube.com/watch?v=S5cMd0XJ1Hk "Astroberry OS")

This repository provides comprehensive set of tools for automated building of Astroberry OS. See [ARCHITECTURE](docs/ARCHITECTURE.md) for details.

## Astroberry OS Features 🔭

| Feature | Status | 
| ------------- | ------------ | 
| Built on top of [Raspberry Pi OS](https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2026-04-21/2026-04-21-raspios-trixie-arm64-lite.img.xz) for **arm64** | [![astroberry-os-release-arm64](https://github.com/astroberry-official/astroberry-os/actions/workflows/astroberry-os-release-arm64.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/astroberry-os-release-arm64.yml) |
| Built on top of [Debian Trixie](http://deb.debian.org/debian/) for **amd64** | [![astroberry-os-release-amd64](https://github.com/astroberry-official/astroberry-os/actions/workflows/astroberry-os-release-amd64.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/astroberry-os-release-amd64.yml) |
| Custom system modifications including **wireless hotspot**, **file sharing**, **remote desktop** via web interface and VNC clients, and [more...](https://github.com/astroberry-official/astroberry-os-sysmod) | [![astroberry-os-sysmod](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-astroberry-os-sysmod.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-astroberry-os-sysmod.yml) |
| Guide Star Catalog (GSC) for simulating star fields | [![gsc](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-gsc.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-gsc.yml) |
| [INDI framework](https://github.com/indilib/indi) with official device drivers | [![indi-core](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-indi-core.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-indi-core.yml) |
| [INDI 3rd party](https://github.com/indilib/indi-3rdparty) libraries | [![indi-3rdparty-libs](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-indi-3rdparty-libs.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-indi-3rdparty-libs.yml) |
| [INDI 3rd party](https://github.com/indilib/indi-3rdparty) device drivers | [![indi-3rdparty-drivers](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-indi-3rdparty-drivers.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-indi-3rdparty-drivers.yml) |
| [KStars](https://invent.kde.org/education/kstars) planetarium software | [![kstars](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-kstars.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-kstars.yml) |
| [PHD2](https://github.com/OpenPHDGuiding/phd2) for autoguiding | [![phd2](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-phd2.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-phd2.yml) |
| [PHD Log Viewer](https://github.com/agalasso/phdlogview) for guiding performance analysis | [![phdlogview](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-phdlogview.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-phdlogview.yml) |
| [StellarSolver](https://github.com/rlancaste/stellarsolver) for field solving | [![stellarsolver](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-stellarsolver.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-stellarsolver.yml) |
| New generation web-based [Astroberry Manager](https://github.com/astroberry-official/astroberry-manager/) | [![astroberry-manager](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-astroberry-manager.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-astroberry-manager.yml) |
| Python 3 [INDI client](https://github.com/indilib/pyindi-client) | [![python3-indi-client](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-indi-client.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-indi-client.yml) |
| Python 3 [INDI web interface](https://github.com/knro/indiwebmanager) | [![python3-indiweb](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-indiweb.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-indiweb.yml) |
| Python 3 [GPSD client](https://github.com/tfeldmann/gpsdclient) | [![python3-gpsdclient](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-gpsdclient.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-gpsdclient.yml) |
| Python 3 [YR weather client](https://github.com/ZeroWave022/yr-weather) | [![python3-yr-weather](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-yr-weather.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-yr-weather.yml) |
| [XFCE Desktop Environment](https://www.xfce.org/) | Upstream Build |
| [Astrometry](https://astrometry.net/) for field solving | Upstream Build |
| [ASTAP](https://www.astrosharp.it/astap.html) for field solving | Upstream Build |
| [Gnome Predict](https://oz9aec.dk/gpredict/) for satellite tracking | Upstream Build |
| [FireCapture](https://www.firecapture.de/) for planetary imaging | Upstream Build |
| [SER Player](https://free-astro.org/index.php?title=SER_Player) for viewing captured planetary video | Upstream Build |
| [AstroDMX](https://www.astrodmx-capture.org.uk/) capture software | Upstream Build |
| [CCDCiel](https://www.ap-i.net/ccdciel/en/start) capture software | Upstream Build |
| [Siril](https://www.siril.org/) for DSO image processing | Upstream Build |

## Install Astroberry OS 🏃

### Quick install
The easiest way to install Astroberry OS is to [download a binary system image](https://www.astroberry.io/download), flash a new microSD card and boot Raspberry Pi with it. Alternatively you can manually install debian packages from Astroberry OS APT repository. **Warning:** Run these commands only if you are installing on a 64-bit version of Raspberry Pi OS or Debian Trixie.

### Manual install

**One-command installation**

```
curl -fsSL https://astroberry.io/debian/install.sh | bash
```

**Three-command installation**

1. Add Astroberry OS certificate and repository:

```
# Add Astroberry OS certificate
curl -fsSL https://astroberry.io/debian/astroberry.asc \
    | sudo gpg --dearmor -o /etc/apt/keyrings/astroberry.gpg

# Add Astroberry OS repository
curl -fsSL https://astroberry.io/debian/astroberry.sources \
    | sudo tee /etc/apt/sources.list.d/astroberry.sources
```

2. Set higher priority to Astroberry OS APT repository:

Astroberry OS APT repository provides the latest versions of some packages, which older versions are also available in Debian and Raspberry OS repositories. To avoid packages installation issues you need to set higher priority to Astroberry OS APT repository. To set higher priority to the repository run the following command:

```
cat <<EOF > /etc/apt/preferences.d/astroberry-pin
Package: *
Pin: origin astroberry.io
Pin-Priority: 900
EOF
```

3. Install Astroberry OS:

```
sudo apt update && sudo apt install astroberry-os
```
Visit [astroberry.io](https://astroberry.io/install) for detailed installation instructions.

## Support Astroberry OS 🚀

If you find Astroberry OS useful and would like to support its development, you can do so in the following ways:

* [Buy us a coffee](https://www.buymeacoffee.com/astroberry)
* [Subscribe on Patreon](https://www.patreon.com/c/Astroberry)
* [Sponsor on GitHub](https://github.com/sponsors/astroberry-official)
* [Support on Astroberry.io](https://astroberry.io/support/)

## Community 🧑‍🤝‍🧑

Join our community on [Discord](https://discord.gg/Bzhm24VgQu) or check out our [website](https://astroberry.io) for more information and the latest news.
