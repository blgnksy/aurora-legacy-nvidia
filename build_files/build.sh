#!/usr/bin/env bash
set -euxo pipefail

dnf5 install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

dnf5 makecache

dnf5 install -y \
    akmod-nvidia-580xx \
    xorg-x11-drv-nvidia-580xx \
    xorg-x11-drv-nvidia-580xx-libs \
    xorg-x11-drv-nvidia-580xx-cuda \
    xorg-x11-drv-nvidia-580xx-cuda-libs \
    libva-nvidia-driver \
    nvidia-container-toolkit \
    nvidia-container-toolkit-base \
    libnvidia-container1 \
    libnvidia-container-tools

dnf5 clean all