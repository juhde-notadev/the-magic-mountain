#!/usr/bin/env bash
# Extracts fumagician/DSRD.enc/<FWREV>.enc from Samsung's own official
# firmware update ISO and stages them in overlay/root/fumagician/.
#
# This script never touches Samsung's servers. You download the ISO
# yourself, from Samsung's official support site, for your exact drive
# and firmware revision — this only unpacks what you already have.
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: extract-firmware.sh <samsung-firmware-update.iso> <target-model-string>

<samsung-firmware-update.iso> is the ISO you download yourself from
Samsung's official support site, for your exact drive and firmware
revision (e.g. Samsung_SSD_960_EVO_3B7QCXE7.iso). Nothing here fetches
it for you.

<target-model-string> is matched (as a substring) against
/sys/class/nvme/*/model at boot — the wrapper refuses to run fumagician
unless it's present. Use something specific enough to only match your
drive, e.g. "970 EVO Plus" or "990 PRO".
EOF
    exit 1
}

[[ $# -eq 2 ]] || usage

samsung_iso=$1
target_model=$2
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
dest="${repo_root}/overlay/root/fumagician"

test -s "$samsung_iso" || { echo "Missing or empty: $samsung_iso" >&2; exit 1; }
[[ -n "$target_model" ]] || { echo "target-model-string must not be empty." >&2; exit 1; }

for cmd in xorriso cpio; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd is required." >&2; exit 1; }
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "Extracting bzImage/initrd from $samsung_iso..."
xorriso -osirrox on -indev "$samsung_iso" \
    -extract /bzImage "$work/bzImage" \
    -extract /initrd "$work/initrd" >/dev/null 2>&1

test -s "$work/initrd" || {
    echo "Could not extract /initrd from $samsung_iso — is this really" >&2
    echo "Samsung's official firmware update ISO?" >&2
    exit 1
}

echo "Unpacking initrd..."
mkdir -p "$work/initrd-root"
# cpio exits nonzero here because it can't mknod dev/console without root —
# harmless, we only need the regular files below; verified by the test -x
# check right after instead of trusting cpio's exit status.
( cd "$work/initrd-root" && zcat "$work/initrd" | cpio -idm 2>/dev/null ) || true

src="$work/initrd-root/root/fumagician"
test -x "$src/fumagician" || { echo "fumagician binary not found inside $samsung_iso." >&2; exit 1; }
test -s "$src/DSRD.enc" || { echo "DSRD.enc not found inside $samsung_iso." >&2; exit 1; }

fw_enc=$(find "$src" -maxdepth 1 -name '*.enc' ! -name 'DSRD.enc' | head -n1)
[[ -n "$fw_enc" ]] || { echo "No firmware .enc payload found inside $samsung_iso." >&2; exit 1; }

mkdir -p "$dest"
install -m 700 "$src/fumagician" "$dest/fumagician"
install -m 600 "$src/DSRD.enc" "$dest/DSRD.enc"
install -m 600 "$fw_enc" "$dest/$(basename "$fw_enc")"
printf '%s' "$target_model" > "${repo_root}/overlay/etc/fumagician-target-model"

echo
echo "Installed into $dest:"
ls -la "$dest"
echo
echo "Target firmware : $(basename "$fw_enc" .enc)"
echo "Target model    : $target_model"
echo "These files are gitignored — they will not be committed."
