#!/usr/bin/env bash
set -euxo pipefail

# ublue-os-nvidia-addons ships nvidia-container-toolkit.repo but disabled by default
dnf5 config-manager setopt nvidia-container-toolkit.enabled=1
dnf5 install -y nvidia-container-toolkit

# TUXEDO repo — fan control, performance profiles, hardware drivers
FEDORA_VER=$(rpm -E '%fedora')
rpm --import "https://rpm.tuxedocomputers.com/fedora/${FEDORA_VER}/0x54840598.pub.asc"
dnf5 config-manager addrepo --from-repofile="https://rpm.tuxedocomputers.com/fedora/tuxedo.repo"
dnf5 install -y \
    tuxedo-control-center \
    tuxedo-fix-nvidia-preserve-vram-suspend \
    tuxedo-tomte \
    tuxedo-firmware-collection

dnf5 clean all

mkdir -p /etc/docker
nvidia-ctk runtime configure --runtime=docker

systemctl enable --root=/ ublue-nvctk-cdi.service
