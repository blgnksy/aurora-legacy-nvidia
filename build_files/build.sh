#!/usr/bin/env bash
set -euxo pipefail

dnf5 install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

dnf5 makecache

# akmod-nvidia-580xx is a hard dep of xorg-x11-drv-nvidia-580xx and its %post
# scriptlet tries to build the kernel module as root, failing in a container.
# All 64 packages install successfully — only the scriptlet exit code poisons
# the transaction. Disable errexit around this call and verify explicitly after.
set +e
dnf5 install -y \
    xorg-x11-drv-nvidia-580xx \
    xorg-x11-drv-nvidia-580xx-libs \
    xorg-x11-drv-nvidia-580xx-cuda \
    xorg-x11-drv-nvidia-580xx-cuda-libs \
    libva-nvidia-driver
set -e
rpm -q akmod-nvidia-580xx xorg-x11-drv-nvidia-580xx xorg-x11-drv-nvidia-580xx-libs

dnf5 clean all

# Blacklist nouveau and nova_core (Rust NVIDIA driver in Fedora 44 kernel) at both layers:
# runtime (modprobe) and initramfs (dracut), equivalent of the kargs approach
cat > /usr/lib/modprobe.d/nvidia-blacklist.conf << 'EOF'
blacklist nouveau
blacklist nova_core
options nvidia-drm modeset=1 fbdev=1
EOF

mkdir -p /usr/lib/dracut/dracut.conf.d
cat > /usr/lib/dracut/dracut.conf.d/nvidia-blacklist.conf << 'EOF'
omit_drivers+=" nouveau nova_core "
EOF