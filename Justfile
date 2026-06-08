image_name := "aurora-dx-legacy-nvidia"

# Build the image locally
build:
    docker build -t {{image_name}}:local .

# Open a shell in the locally built image
shell:
    docker run --rm -it {{image_name}}:local bash

# Check what base digest is recorded in our published image
check-base:
    skopeo inspect docker://ghcr.io/$(git remote get-url origin | sed 's|.*github.com/||;s|/.*||')/{{image_name}}:latest \
      | jq '.Labels["org.opencontainers.image.base.digest"]'

# Check the current upstream aurora-dx:stable digest
check-upstream:
    skopeo inspect docker://ghcr.io/ublue-os/aurora-dx:stable | jq '.Digest'
