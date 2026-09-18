#!/usr/bin/env bash
# Packs overlay/ into an Alpine "lbu" overlay archive (*.apkovl.tar.gz).
# Alpine's live-boot init applies this automatically at boot if it's placed
# next to the kernel/initrd on the boot media, named after the hostname set
# in overlay/etc/hostname. No initrd rebuild required.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
overlay="${repo_root}/overlay"
hostname=$(cat "${overlay}/etc/hostname")
output="${1:-${repo_root}/build/${hostname}.apkovl.tar.gz}"

test -s "${overlay}/root/fumagician/fumagician" || {
    echo "overlay/root/fumagician/fumagician is missing." >&2
    echo "Run scripts/extract-firmware.sh first." >&2
    exit 1
}

mkdir -p "$(dirname "${output}")"
tar -C "${overlay}" -czf "${output}" .
sha256sum "${output}"
echo "Overlay packed to ${output}."
