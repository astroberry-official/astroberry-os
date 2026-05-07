#!/bin/bash
#
# astroberry-docker-run.sh
# Start astroberry builder docker image
#

ARCH=$(dpkg-architecture | grep DEB_HOST_ARCH= | cut -d= -f2 | xargs)

if [ "$ARCH" != "arm64" -a "$ARCH" != "amd64" ]; then
    echo "Unknown architecture"
    exit 1
fi

docker run --privileged --rm -it -v /dev:/dev -v .:/work  ghcr.io/astroberry-official/astroberry-os/debian-trixie-$ARCH
