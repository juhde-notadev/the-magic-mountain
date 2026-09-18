#!/usr/bin/env bash
# One command for the "unpack, add the wrapper, repack" stage: packs
# overlay/ (via pack-overlay.sh — run it standalone if you just want to
# inspect the apkovl) then remasters the stock Alpine ISO by adding it
# at the root, replaying the source ISO's existing BIOS+UEFI boot
# records unchanged. No custom kernel, initrd, or grub.cfg assembly
# required; Alpine's own boot chain is used completely untouched.
#
# Get the stock ISO from https://alpinelinux.org/downloads/ — pick the
# "standard" or "extended" x86_64 release (aarch64 etc. also work if your
# hardware needs it). It already ships NVMe/USB/UEFI drivers. Drop it in
# alpineiso/ (a plain directory in this repo, nothing auto-detects it —
# pass the path explicitly below).
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
stock_iso=${1:?Usage: build-uefi-iso.sh <stock-alpine-iso> [output.iso]}
output=${2:-${repo_root}/repackiso/the-magic-mountain.iso}
apkovl="${repo_root}/repackiso/localhost.apkovl.tar.gz"

test -s "${stock_iso}" || { echo "${stock_iso} missing." >&2; exit 1; }
command -v xorriso >/dev/null 2>&1 || {
    echo "xorriso is required (Arch/BlackArch: pacman -S libisoburn)." >&2
    exit 1
}

"${repo_root}/scripts/pack-overlay.sh"

mkdir -p "$(dirname "${output}")"
rm -f "${output}"

xorriso -indev "${stock_iso}" \
    -outdev "${output}" \
    -boot_image any replay \
    -map "${apkovl}" /localhost.apkovl.tar.gz \
    -commit

printf '\n--- El Torito boot records (should show both BIOS and UEFI) ---\n'
xorriso -indev "${output}" -report_el_torito plain 2>/dev/null
printf '\n--- output ---\n'
file "${output}"
sha256sum "${output}"
echo "Remastered ISO built at ${output}."
