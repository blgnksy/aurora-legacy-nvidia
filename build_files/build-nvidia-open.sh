#!/usr/bin/env bash
set -euxo pipefail

# ublue-os-nvidia-addons ships nvidia-container-toolkit.repo but disabled by default
dnf5 config-manager setopt nvidia-container-toolkit.enabled=1
dnf5 install -y nvidia-container-toolkit

# Debugging tools
dnf5 install -y \
    gdb \
    gdb-gdbserver \
    strace \
    ltrace \
    perf \
    valgrind \
    binutils \
    elfutils \
    bpftrace \
    lsof \
    sysstat \
    tcpdump

# TUXEDO repo — fan control, performance profiles, hardware drivers
FEDORA_VER=$(rpm -E '%fedora')
rpm --import "https://rpm.tuxedocomputers.com/fedora/${FEDORA_VER}/0x54840598.pub.asc"
dnf5 config-manager addrepo --from-repofile="https://rpm.tuxedocomputers.com/fedora/tuxedo.repo"

# kernel-devel must be present before tuxedo-drivers installs so its DKMS
# build has headers to build the module against.
KERNEL_VERSION=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)
dnf5 install -y kernel-devel-${KERNEL_VERSION}

dnf5 install -y \
    tuxedo-control-center \
    tuxedo-drivers \
    tuxedo-tomte \
    tuxedo-firmware-collection \
    nspr \
    nss

# tccd's own %post can't reliably enable services during a container build
# (no running systemd), same issue worked around below for ublue-nvctk-cdi.
systemctl enable --root=/ tccd.service tccd-sleep.service

dnf5 clean all

mkdir -p /etc/docker
nvidia-ctk runtime configure --runtime=docker

systemctl enable --root=/ ublue-nvctk-cdi.service
