#!/usr/bin/env bash
set -euxo pipefail

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

# Generate CDI spec for OCI runtimes (Podman). This allows Podman to pick up
# NVIDIA device and environment hooks via the CDI mechanism provided by
# nvidia-container-toolkit.
if command -v nvidia-ctk >/dev/null 2>&1; then
    mkdir -p /etc/containers/cdi.d
    nvidia-ctk cdi generate > /etc/containers/cdi.d/nvidia.json || true
fi
