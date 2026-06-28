#!/usr/bin/env bash
set -euxo pipefail

# Sync the base image to the current kernel/package set before installing the
# pre-built NVIDIA modules. The akmod packages are built against a specific
# kernel ABI and fail if the image still carries an older kernel stack.
dnf5 upgrade -y --refresh

# Install pre-built kmod and driver packages from akmods-nvidia-lts.
# ublue-os-nvidia-addons drops nvidia-container-toolkit.repo but it's not
# visible until the next dnf invocation, so the toolkit is installed separately.
dnf5 install -y \
    /tmp/akmods-rpms/ublue-os/ublue-os-nvidia*.rpm \
    /tmp/akmods-rpms/kmods/kmod-nvidia*.rpm \
    /tmp/akmods-rpms/nvidia/*.rpm \
    libva-nvidia-driver

dnf5 config-manager setopt nvidia-container-toolkit.enabled=1
dnf5 install -y nvidia-container-toolkit

dnf5 clean all

# Configure Docker to use the NVIDIA container runtime
mkdir -p /etc/docker
nvidia-ctk runtime configure --runtime=docker

# Configure POdman to use the NVIDIA container runtime
if command -v nvidia-ctk >/dev/null 2>&1; then
    mkdir -p /etc/containers/cdi.d /etc/cdi
    nvidia-ctk cdi generate --output=/etc/containers/cdi.d/nvidia.json || true
    nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml || true
fi
