#!/usr/bin/env bash
set -euxo pipefail

# ublue-os-nvidia-addons ships nvidia-container-toolkit.repo but disabled by default
dnf5 config-manager setopt nvidia-container-toolkit.enabled=1
dnf5 install -y nvidia-container-toolkit

dnf5 clean all

mkdir -p /etc/docker
nvidia-ctk runtime configure --runtime=docker

systemctl enable --root=/ ublue-nvctk-cdi.service
