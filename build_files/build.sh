#!/usr/bin/env bash
set -euxo pipefail

dnf5 install -y \
    /tmp/akmods-rpms/ublue-os/ublue-os-nvidia*.rpm \
    /tmp/akmods-rpms/kmods/kmod-nvidia*.rpm \
    /tmp/akmods-rpms/nvidia/*.rpm \
    libva-nvidia-driver \
    nvidia-container-toolkit

dnf5 clean all

# Configure Docker to use the NVIDIA container runtime
mkdir -p /etc/docker
nvidia-ctk runtime configure --runtime=docker
