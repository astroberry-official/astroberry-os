# Astroberry OS
Astroberry OS is an operating system for Raspberry Pi for controlling astronomy equipment.

[![astroberry-os](https://github.com/astroberry-official/astroberry-os/actions/workflows/astroberry-os-release.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/astroberry-os-release.yml)
[![astroberry-manager](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-astroberry-manager.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-astroberry-manager.yml)
[![indi-core](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-indi-core.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-indi-core.yml)
[![indi-3rdparty-libs](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-indi-3rdparty-libs.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-indi-3rdparty-libs.yml)
[![indi-3rdparty-drivers](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-indi-3rdparty-drivers.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-indi-3rdparty-drivers.yml)
[![stellarsolver](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-stellarsolver.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-stellarsolver.yml)
[![kstars](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-kstars.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-kstars.yml)
[![phd2](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-phd2.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-phd2.yml)
[![phdlogview](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-phdlogview.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-phdlogview.yml)
[![gsc](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-gsc.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-gsc.yml)
[![python3-indi-client](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-indi-client.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-indi-client.yml)
[![python3-indiweb](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-indiweb.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-indiweb.yml)
[![python3-gpsdclient](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-gpsdclient.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-gpsdclient.yml)
[![python3-yr-weather](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-yr-weather.yml/badge.svg)](https://github.com/astroberry-official/astroberry-os/actions/workflows/build-python3-yr-weather.yml)


[![Astroberry OS](.github/video-thumbnail.jpg)](http://www.youtube.com/watch?v=S5cMd0XJ1Hk "Astroberry OS")

This library provides comprehensive set of tools for automated building of Astroberry OS.
Is uses self-hosted actions runner to execute GitHub workflows to:
- build dockerized system builder
- build debian packages provided by Astroberry OS
- build system image file

See [ARCHITECTURE](docs/ARCHITECTURE.md) for details.

## Astroberry OS flavours and ingredients
Two flavors of Astroberry OS are available for installation: **astroberry-os-lite** and **astroberry-os-desktop**

Astroberry OS **Lite**
- Built on top of official Raspberry Pi OS
- Support for 64bit Raspberry Pi 4 & 5
- Wireless Hotspot for accessing the system in the field
- INDI framework with official device drivers
- Guide Star Catalog (GSC) for simulating star fields
- Astrometry for field solving
- New generation web-based Astroberry Manager

Astroberry OS **Desktop**
- All features from astroberry-os-lite
- XFCE Desktop Environment accessible with a web browser
- KStars planetarium software
- PHD2 for autoguiding
- PHD Log Viewer for inspecting guiding performance
- StellarSolver for field solving
- ASTAP for field solving
- Gnome Predict for satellite tracking
- FireCapture for planetary imaging
- SER Player for viewing captured planetary video
- AstroDMX capture software
- CCDciel capture software
- Siril for DSO image processing

## Install Astroberry OS 🏃

### Quick install
The easiest way to install Astroberry OS is to [download a binary system image](https://www.astroberry.io/download), flash a new microSD card and boot Raspberry Pi with it.

Alternatively you can manually install debian packages from Astroberry OS APT repository. Run these commands only if you are running Raspberry Pi OS (64-bit) or Debian Trixie (64-bit).

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
Visit [www.astroberry.io](https://www.astroberry.io/install) for detailed installation instructions.
