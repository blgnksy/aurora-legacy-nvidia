#!/usr/bin/env bash
set -euxo pipefail

dnf5 install -y \
    /tmp/akmods-rpms/ublue-os/ublue-os-nvidia*.rpm \
    /tmp/akmods-rpms/kmods/kmod-nvidia*.rpm \
    /tmp/akmods-rpms/nvidia/*.rpm \
    libva-nvidia-driver

dnf5 clean all
