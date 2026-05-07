# Astroberry OS
Astroberry OS is an operating system for Raspberry Pi for controlling astronomy equipment.

[![Astroberry OS Sneak Preview](http://img.youtube.com/vi/S5cMd0XJ1Hk/maxresdefault.jpg)](http://www.youtube.com/watch?v=S5cMd0XJ1Hk "Astroberry OS Sneak Preview")

This library provides comprehensive set of tools for automated building of Astroberry OS.
Is uses self-hosted actions runner to execute GitHub workflows to:
- build dockerized system builder
- build debian packages provided by Astroberry OS
- maintain online Astroberry OS software repository
- build system image file

## Install build environment
Astroberry OS and software packages are built using preconfigured build environment. Run `scripts/raspberrypi-setup.sh` 
on your Raspberry Pi to prepare it for installation of GitHub self-hosted actions runner.

Add and configure a self-hosted actions runner in [Project Settings](https://github.com/astroberry-official/astroberry-os/settings/actions/runners).
While configuring a new actions runner, you will be given a set of commands to run on your Raspberry Pi.
Run these commands on your Raspberry Pi to install actions runner. When finished, run actions runner with `actions-runner/run.sh`

## Build Astroberry OS
Debian packages are compiled and built using [GitHub Actions](https://github.com/astroberry-official/astroberry-os/actions)
The following workflows are used to compile and build debian packages of software provided by Astroberry OS APT repository.
Make sure that your self-hosted actions runner is started before running any workflow.

- **Astroberry OS builder** - builds a docker image with preconfigured building environment.
  It runs automaticaly whenever you compile and build a debian package. If you need to start it manually, run `scripts/astroberry-docker-run.sh`.
  Docker image is exported to [https://ghcr.io/astroberry-official/astroberry-os/debian-trixie](https://ghcr.io/astroberry-official/astroberry-os/debian-trixie).


- **Astroberry OS image** - build Astroberry OS system image file.


- **Astroberry OS meta-package** - build astroberry-os-[lite|desktop|full] meta-packages that install required packages.


- **Astroberry OS repository** - add packages and update Astroberry OS APT repository.


- **Software packages:**

  - **Build Astroberry Manager** - compile Astroberry Wanager - web frontend for Astroberry OS.

  - **Build GSC** - compile and package Guide Star Catalog (GSC) of stars.

  - **Build INDI Core** - compile and package core INDI packages. Virtually all other packages depend on it.

  - **Build INDI 3rd Party Libraries** - compile and package INDI 3rd party libraries.

  - **Build INDI 3rd Party Drivers** - compile and package INDI 3rd party drivers.

  - **Build StellarSolver** - compile and package StellarSolver. Required by KStars.

  - **Build KStars** - compile and package KStars.

  - **Build PHD2** - compile and package PHD2.

  - **Build PHD2 Log Viewer** - compile and package PHD2 Log Viewer.


## Install Astroberry OS

### Quick install
The easiest way to install Astroberry OS is to [download a binary system image](https://www.astroberry.io/download), flash a new microSD card and boot Raspberry Pi with it.
Alternatively you can manually install debian packages from Astroberry OS APT repository. Execute the folowing commands on your Raspberry Pi, running official Raspberry Pi OS.

```
# Add Astroberry OS certificate
curl -fsSL https://astroberry.io/debian/astroberry.asc \
    | sudo gpg --dearmor -o /etc/apt/keyrings/astroberry.gpg

# Add Astroberry OS repository
curl -fsSL https://astroberry.io/debian/astroberry.sources \
    | sudo tee /etc/apt/sources.list.d/astroberry.sources
```

**Important note**
Astroberry OS APT repository provides the latest versions of some packages, which older versions are also available in Debian and Raspberry OS repositories.
You need to set higher priority to Astroberry OS APT repository to avoid packages installation issues. To set higher priority to the repository run the following command:

```
cat <<EOF > /etc/apt/preferences.d/astroberry-pin
Package: *
Pin: origin astroberry.io
Pin-Priority: 900
EOF
```

Finally you can install Astroberry OS.

```
# Install Astroberry OS
sudo apt update && sudo apt install astroberry-os-lite
```
Visit [www.astroberry.io](https://www.astroberry.io/install) for detailed installation instructions.

### Astroberry OS flavours and ingredients
Two flavors of Astroberry OS are available for installation: **astroberry-os-lite** and **astroberry-os-desktop**

Astroberry OS **Lite** provides:
- Built on top of official Raspberry Pi OS
- Support for 64bit Raspberry Pi 5
- Wireless Hotspot for accessing the system in the field
- New generation Astroberry OS web manager
- INDI framework with official device drivers
- Guide Star Catalog (GSC) for simulating star fields
- Astrometry for field solving

Astroberry OS **Desktop** provides everything from lite flavour PLUS:
- XFCE Desktop Environment
- Remote desktop accessible with a web browser
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
