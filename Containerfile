FROM ghcr.io/ublue-os/aurora-dx:stable

COPY build_files/ /tmp/build_files/

RUN chmod +x /tmp/build_files/build.sh && \
    /tmp/build_files/build.sh && \
    ostree container commit