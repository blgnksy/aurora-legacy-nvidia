FROM ghcr.io/ublue-os/akmods-nvidia-lts:main-44 AS akmods-nvidia

FROM ghcr.io/ublue-os/aurora-dx:stable

COPY system_files/shared/ /
COPY build_files/ /tmp/build_files/

RUN --mount=type=bind,from=akmods-nvidia,src=/rpms,dst=/tmp/akmods-rpms \
    chmod +x /tmp/build_files/build.sh && \
    /tmp/build_files/build.sh && \
    ostree container commit

COPY build_files/custom.preinstall /etc/flatpak/preinstall.d/custom.preinstall
