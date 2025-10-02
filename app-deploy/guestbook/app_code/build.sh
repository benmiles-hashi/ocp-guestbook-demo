#!/usr/bin/env bash
set -euo pipefail

# 1. Build arch-specific images
podman build --platform linux/amd64 -t quay.io/bkmiles/vault-guestbook-app:amd64 .
podman build --platform linux/arm64 -t quay.io/bkmiles/vault-guestbook-app:arm64 .

# 2. Push each arch image up to Quay
podman push quay.io/bkmiles/vault-guestbook-app:amd64
podman push quay.io/bkmiles/vault-guestbook-app:arm64

# 3. Remove any stale local manifest to avoid Podman collisions
podman rmi -f localhost/vault-guestbook-manifest:latest || true

# 4. Create a local manifest list under a throwaway name
podman manifest create localhost/vault-guestbook-manifest:latest

# 5. Add the remote per-arch images into the manifest
podman manifest add localhost/vault-guestbook-manifest:latest docker://quay.io/bkmiles/vault-guestbook-app:amd64
podman manifest add localhost/vault-guestbook-manifest:latest docker://quay.io/bkmiles/vault-guestbook-app:arm64

# 6. Push the manifest list to Quay as the official `latest` tag
podman manifest push --all localhost/vault-guestbook-manifest:latest docker://quay.io/bkmiles/vault-guestbook-app:latest

# 7. Verify
skopeo inspect docker://quay.io/bkmiles/vault-guestbook-app:latest | jq '.manifests[].platform'
