#!/usr/bin/env bash
# Builds a UEFI-bootable ISO from a prepared Alpine boot tree plus this
# repo's packed overlay.
#
# boot_tree must already contain a stock Alpine kernel/initrd and a
# grub.cfg that chainloads them (see README.md "Building the boot tree").
# Alpine's "standard"/"extended" releases already include NVMe/USB/UEFI
# drivers, so no initrd rebuild should be necessary.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
boot_tree=${1:?Usage: build-uefi-iso.sh <boot-tree-dir> [output.iso]}
output=${2:-${repo_root}/build/the-magic-mountain.iso}
apkovl="${repo_root}/build/$(cat "${repo_root}/overlay/etc/hostname").apkovl.tar.gz"

test -s "${boot_tree}/bzImage" || { echo "${boot_tree}/bzImage missing." >&2; exit 1; }
test -s "${boot_tree}/initrd" || { echo "${boot_tree}/initrd missing." >&2; exit 1; }
test -s "${boot_tree}/boot/grub/grub.cfg" || { echo "${boot_tree}/boot/grub/grub.cfg missing." >&2; exit 1; }
test -s "${apkovl}" || { echo "${apkovl} missing — run pack-overlay.sh first." >&2; exit 1; }

if ! command -v grub-mkrescue >/dev/null 2>&1 || ! command -v xorriso >/dev/null 2>&1; then
    echo "grub-mkrescue and xorriso are required (Arch: pacman -S grub xorriso)." >&2
    exit 1
fi

cp "${apkovl}" "${boot_tree}/"

mkdir -p "$(dirname "${output}")"
grub-mkrescue -o "${output}" "${boot_tree}"

printf '\n--- EFI boot records ---\n'
xorriso -indev "${output}" -report_el_torito plain 2>/dev/null
printf '\n--- output ---\n'
file "${output}"
sha256sum "${output}"
echo "UEFI ISO built at ${output}."
