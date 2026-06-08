#!/usr/bin/env bash
set -euxo pipefail

# aurora-dx ships RPM Fusion repo files but disables them — enable nonfree for akmod-nvidia-580xx
sed -i 's/enabled=0/enabled=1/' /etc/yum.repos.d/rpmfusion-nonfree*.repo

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