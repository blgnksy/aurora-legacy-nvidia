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

# tuxedo-drivers ships upstream as a DKMS package, but DKMS always builds
# against the build host's running kernel (uname -r), never the kernel-core
# that ships in this image — a Fedora tuxedo-drivers issue confirms its
# Makefile ignores the KERNELDIR dkms passes in. That's guaranteed to fail
# in CI, where the runner's own kernel is unrelated to Fedora's. Build the
# module ourselves against the exact target kernel instead: KDIR is a plain
# `:=` in the Makefile, so it's safely overridden from the make command line.
KERNEL_VERSION=$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)
dnf5 install -y kernel-devel-${KERNEL_VERSION} gcc gcc-c++ make bc elfutils-libelf-devel \
    git python3 systemd-devel nodejs24 nodejs24-npm

TUXEDO_DRIVERS_VERSION=4.22.3
TUXEDO_DRIVERS_BUILD_TAG="${TUXEDO_DRIVERS_VERSION}-blgnksy"
git clone --depth 1 --branch "v${TUXEDO_DRIVERS_VERSION}" \
    https://github.com/tuxedocomputers/tuxedo-drivers.git /tmp/tuxedo-drivers
# the Makefile's M=$(PWD) reads the inherited shell PWD, not the -C target,
# so cd into it directly rather than relying on make -C for that.
# `install`'s `cp -r usr /` expects usr/ at the repo root, but that mapping
# from files/usr is normally done by TUXEDO's own packaging tool (package.yml
# file_map), not plain make install — stage it into place ourselves first.
(cd /tmp/tuxedo-drivers && cp -r files/usr . && make KDIR="/usr/src/kernels/${KERNEL_VERSION}" install)
depmod "${KERNEL_VERSION}"
rm -rf /tmp/tuxedo-drivers
echo "${TUXEDO_DRIVERS_BUILD_TAG}" > /usr/lib/tuxedo-drivers-build-version

# tuxedo-control-center: dnf5's own RPM payload extractor fails unpacking
# TUXEDO's official ~450MB Electron-bundle RPM (confirmed with a manual
# `rpm2cpio | cpio` extraction of the very same payload succeeding cleanly —
# the bug is in dnf5, not the package). Build it from source instead, laid
# out to match electron-builder's own path convention so TUXEDO's own
# desktop/service/policy files can be reused unmodified.

# /root is a symlink to /var/roothome (ostree "stateless root" convention);
# that target doesn't exist yet during a container build, which silently
# breaks npm/git writing to $HOME.
mkdir -p /var/roothome
git config --global --add safe.directory '*'

TCC_VERSION=3.0.8
TCC_BUILD_TAG="${TCC_VERSION}-blgnksy"
git clone --depth 1 --branch "v${TCC_VERSION}" \
    https://github.com/tuxedocomputers/tuxedo-control-center.git /tmp/tcc
pushd /tmp/tcc
npm ci
# electron's own postinstall doesn't reliably fetch its binary under this
# project's npm install-script allowlisting; force it explicitly.
node node_modules/electron/install.js
npm run build-prod
cp -r node_modules/electron /tmp/tcc-electron-runtime
npm prune --omit=dev
popd

# /opt resolves to /var/opt, and /var is persistent state that ostree/bootc
# does NOT re-sync from the image on an upgrade of an already-existing
# deployment (only a fresh install would pick up new /var content) — so
# anything installed directly under /opt would silently vanish after
# `bootc upgrade` on a system that already has a prior deployment. Install
# the real payload under /usr instead (properly versioned/replaced every
# upgrade), and use a tmpfiles.d rule so /var/opt/tuxedo-control-center
# becomes a symlink to it on every boot — TCC's own compiled code and its
# systemd/desktop files hardcode /opt/tuxedo-control-center/... paths, so
# that symlink has to keep resolving rather than relocating those paths.
install -d /usr/lib/tuxedo-control-center/resources/dist
cp -r /tmp/tcc/dist/tuxedo-control-center /usr/lib/tuxedo-control-center/resources/dist/
cp -r /tmp/tcc/node_modules /usr/lib/tuxedo-control-center/resources/dist/tuxedo-control-center/node_modules
cp -r /tmp/tcc-electron-runtime /usr/lib/tuxedo-control-center/electron
chmod 4755 /usr/lib/tuxedo-control-center/electron/dist/chrome-sandbox

cat > /usr/lib/tuxedo-control-center/tuxedo-control-center <<'WRAPPER'
#!/bin/bash
exec /usr/lib/tuxedo-control-center/electron/dist/electron /usr/lib/tuxedo-control-center/resources/dist/tuxedo-control-center "$@"
WRAPPER
chmod +x /usr/lib/tuxedo-control-center/tuxedo-control-center
ln -sf /usr/lib/tuxedo-control-center/tuxedo-control-center /usr/bin/tuxedo-control-center
echo "${TCC_BUILD_TAG}" > /usr/lib/tuxedo-control-center-build-version

DIST_DATA=/usr/lib/tuxedo-control-center/resources/dist/tuxedo-control-center/data/dist-data
install -Dm644 "${DIST_DATA}/tuxedo-control-center.desktop" /usr/share/applications/tuxedo-control-center.desktop
install -Dm644 "${DIST_DATA}/tuxedo-control-center-tray.desktop" /etc/skel/.config/autostart/tuxedo-control-center-tray.desktop
install -Dm644 "${DIST_DATA}/com.tuxedocomputers.tccd.policy" /usr/share/polkit-1/actions/com.tuxedocomputers.tccd.policy
install -Dm644 "${DIST_DATA}/com.tuxedocomputers.tomte.policy" /usr/share/polkit-1/actions/com.tuxedocomputers.tomte.policy
install -Dm644 "${DIST_DATA}/com.tuxedocomputers.tccd.conf" /usr/share/dbus-1/system.d/com.tuxedocomputers.tccd.conf
install -Dm644 "${DIST_DATA}/com.tuxedocomputers.tcc.metainfo.xml" /usr/share/metainfo/com.tuxedocomputers.tcc.metainfo.xml
install -Dm644 "${DIST_DATA}/tuxedo-control-center_256.svg" /usr/share/icons/hicolor/scalable/apps/tuxedo-control-center.svg
install -Dm644 "${DIST_DATA}/99-webcam.rules" /etc/udev/rules.d/99-webcam.rules
install -Dm644 "${DIST_DATA}/tccd.service" /etc/systemd/system/tccd.service
install -Dm644 "${DIST_DATA}/tccd-sleep.service" /etc/systemd/system/tccd-sleep.service

# tccd.service.d/10-restart.conf (system_files/nvidia-open) overrides
# ExecStart/ExecStop to run through stock node instead of pkg's bundled
# binary — pkg's patched Node bootstrap (embedded virtual filesystem
# unpacking) races under a plain systemd launch and reliably crashes with a
# V8 PageAllocator ENOMEM; confirmed it never happens run interactively, and
# disappears under strace (classic race signature: ptrace serializes/slows
# execution). It also adds Restart=, since the vendor unit has none.

# tccd's own %post can't reliably enable services during a container build
# (no running systemd).
systemctl enable --root=/ tccd.service tccd-sleep.service

rm -rf /tmp/tcc

# tuxedo-tomte weakly recommends tuxedo-control-center, which would drag the
# broken RPM back in via weak-dependency resolution — both it and
# tuxedo-drivers are already built from source above, so exclude them here.
dnf5 install -y --exclude=tuxedo-control-center --exclude=tuxedo-drivers \
    tuxedo-tomte \
    tuxedo-firmware-collection

dnf5 clean all

mkdir -p /etc/docker
nvidia-ctk runtime configure --runtime=docker

# ublue-os-nvidia-addons used to ship this disabled (needing a manual enable
# here, since RPM %post can't call systemctl during a container build) but
# now ships nvidia-cdi-refresh.service/.path instead, pre-enabled by the
# package itself — nothing left for us to do here.
