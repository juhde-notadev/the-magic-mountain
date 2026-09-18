#!/usr/bin/env bash
# Packs overlay/ into an Alpine "lbu" overlay archive. Named localhost.apkovl.tar.gz
# on purpose: Alpine's live-boot init checks for "<hostname>.apkovl.tar.gz" first,
# then always falls back to "localhost.apkovl.tar.gz" regardless of what hostname
# actually gets set — using that name works no matter what, and it's what actually
# got used in the verified build.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
overlay="${repo_root}/overlay"
output="${1:-${repo_root}/build/localhost.apkovl.tar.gz}"

test -s "${overlay}/root/fumagician/fumagician" || {
    echo "overlay/root/fumagician/fumagician is missing." >&2
    echo "Run scripts/extract-firmware.sh first." >&2
    exit 1
}
test -s "${overlay}/etc/fumagician-target-model" || {
    echo "overlay/etc/fumagician-target-model is missing or empty." >&2
    echo "Run scripts/extract-firmware.sh with your drive's model string first." >&2
    exit 1
}

mkdir -p "$(dirname "${output}")"
tar -C "${overlay}" -czf "${output}" .
sha256sum "${output}"
echo "Overlay packed to ${output}."
