# Astroberry OS Project Architecture

## Building Process

- Astroberry OS delivers ready-to-use images of an operating system for Raspberry Pi and other devices.
- System image is based on **Raspberry Pi OS image** that is based on **Debian** operating system.
- Build process is hosted on GitHub and is using **GitHub Actions**.
- Self-hosted runners for GitHub Actions are used.
- All building workflows run inside **Docker Builder** containers using custom builder images.
- Custom astroberry-os software is preinstalled and configured on top of the base image.
- Base image is downloaded from Raspberry Pi OS or bootstrapped directly from Debian.
- Custom astroberry-os software is compiled and packaged from sources, except external binary packages (see note below).
- Custom astroberry-os software is installed from online **debian repository of debian packages**, which we maintain and host on a server separate to this GitHub repository.
- External binary packages are also available from our online repository (marked as restricted) or can be downloaded from their original authors.
- Updates to astroberry-os packages are pushed to our online repository and users can update their systems using the standard package manager (**apt**).
- System images are built after major changes to the system or underyling build process. They contain the latest stable versions of all packages as of build time and are available for manual download from project website.

### Docker Builder

All building workflows run inside **Docker Builder** container using custom builder images defined in `docker/Dockerfile.debian-trixie`.

The Docker containers are run on self-hosted GitHub Actions runner. See [GitHub Actions documentation](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners) for more details.

Add an actions runner in [Project Settings](https://github.com/astroberry-official/astroberry-os/settings/actions/runners). Follow instructions and run actions runner with `actions-runner/run.sh`.

### Debian Packages

Custom astroberry-os software is compiled from sources and packaged as debian packages. 

External binary packages (e.g. FireCapture, AstroDMx) are provided from their original authors in compiled form and are available as binary packages in our online repository (marked as restricted) or are downloaded directly from their original authors.

When new versions of debian packages are ready, they are uploaded to **online debian repository** and can be installed using the standard package manager (**apt**).

#### Building and Packaging

The building and packaging process uses worflows defined in `.github/workflows/` directory. These workflows are triggered manually and run inside **Docker Builder** container for the debian distribution we are targeting. At present this is debian-trixie.

The following workflows are used to compile and build debian packages of software provided by Astroberry OS APT repository.
Make sure that your self-hosted actions runner is started before running any workflow.

- **Astroberry OS [ arm64 | amd64 ]** - build Astroberry OS system image. Starting from v3.2 amd64 architecture is supported.

- **Astroberry OS meta-package** - build astroberry-os meta-package that installs required packages.

- **Astroberry OS sysmod** - build astroberry-os-sysmod that provides custom mods to the original Raspberry Pi OS.


- **Software packages** (recommended order of running)

  ✔️ **Build gsc** - compile and package guide star catalog (GSC) of stars.

  ✔️ **Build indi-core** - compile and package indi core packages.

  ✔️ **Build indi-3rdparty-libs** - compile and package indi 3rd party libraries.

  ✔️ **Build indi-3rdparty-drivers** - compile and package indi 3rd party drivers.

  ✔️ **Build stellarsolver** - compile and package stellarsolver.

  ✔️ **Build kstars** - compile and package kstars.

  ✔️ **Build phd2** - compile and package phd2.

  ✔️ **Build phdlogview** - compile and package PHD2 Log Viewer.

  ✔️ **Build python3-gpsdclient** - compile and package python module gpsdclient required by astroberry-manager.

  ✔️ **Build python3-indi-client** - compile and package python module pyindi required by astroberry-manager.

  ✔️ **Build python3-indiweb** - compile and package python module indiweb required by astroberry-manager.

  ✔️ **Build python3-yr-weather** - compile and package python module yr-weather required by astroberry-manager.

  ✔️ **Build astroberry-manager** - compile and package astroberry manager - web frontend for astroberry os.

  ✔️ **Build astroberry-os-sysmod** - compile and package astroberry os system modifications.

  ✔️ **Build astroberry-os** - compile and package astroberry os meta-package that installs astroberry-os.

  ✔️ **Build astroberry-release** - create system image with latest stable versions of all packages as of build time.


#### Online Repository

The repository provides 3 distributions:
- **trixie** (stable): stable version of packages promoted from testing distribution after successful tests
- **trixie-testing** (unstable): testing version of packages, contains new version of debian packages, that will be included in the next stable release
- **trixie-staging** (staging): staging version of packages, contains newly built debian packages, not tested yet

Workflow for promotion of packages: 
1. When new versions of debian packages are built, they are uploaded to the trixie-staging distribution. 
2. Once the packages are tested and deemed stable, they are promoted to the trixie-testing distribution. 
3. Finally, after extensive testing, the packages are promoted to the trixie distribution.

trixie (stable) and trixie-testing (unstable) distributions are signed with a valid gpg key.
trixie-staging (staging) distribution is not signed and is only for testing purposes, not intended for production use. Users may experience unexpected issues when using packages from this distribution. Users are advised to use stable repositories only.

We use **reprepro** to manage our online repository. We do not provide automated procedure for updating the repository, it is done manually.

The online repository is available at [https://astroberry.io/debian](https://astroberry.io/debian).

Basic configuration of the repository consists of three files:

**conf/distributions**

```
Origin: astroberry.io
Label: astroberry.io
Codename: trixie
Suite: stable
Components: main restricted
Architectures: arm64 amd64
Description: Astroberry OS APT repository
SignWith: B9EA22DE1118CEE6F40494357E8C9FBE975B014A
Contents: .gz
Pull: development
Log: trixie.log

Origin: astroberry.io
Label: astroberry.io
Codename: trixie-testing
Suite: unstable
Components: main restricted
Architectures: arm64 amd64
Description: Astroberry OS APT repository
SignWith: B9EA22DE1118CEE6F40494357E8C9FBE975B014A
Contents: .gz
Pull: staging
Log: trixie-testing.log

Origin: astroberry.io
Label: astroberry.io
Codename: trixie-staging
Suite: staging
Components: main restricted
Architectures: arm64 amd64
Description: Astroberry OS APT repository
Contents: .gz
Log: trixie-staging.log
```

**conf/options**

```
verbose
ask-passphrase
```

**conf/pulls**

```
Name: development
From: trixie-testing

Name: staging
From: trixie-staging
```

### System Image

System image is built using a workflow triggered manually. Workflow is defined in the `.github/workflows/astroberry-os-release.yml` file, which invokes build script `scripts/astroberry-image-build.sh`.

The build workflow produces two artifacts for each architecture and type (standard/lite):
- `astroberryos_[VERSION]_[DISTRIBUTION]-[ARCH].[img.xz|iso]` - system image
- `astroberryos_[VERSION]_[DISTRIBUTION]-[ARCH].[img.xz|iso].sha256sum` - sha256sum of the system image

eg. for arm64 architecture and debian-trixie distribution, the output images are:
- `astroberryos_3.2_debian-trixie-arm64.img.xz`
- `astroberryos_3.2_debian-trixie-arm64.img.xz.sha256sum`

The system images are published to the project website [download section](https://astroberry.io/download/).