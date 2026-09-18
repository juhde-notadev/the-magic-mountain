#!/usr/bin/env bash
# The actually-used method: grub-mkrescue output is a BIOS+UEFI hybrid ISO,
# so it can be written straight to a USB stick with dd — no partitioning,
# no bootloader install, no Ventoy needed.
#
# SAFETY: this overwrites the entire target device. It looks up the
# device's real serial via udevadm, shows it to you, and makes you
# type/paste it back before doing anything — that's what stops you from
# wiping the wrong disk. It is not optional and there is no override flag.
set -euo pipefail

iso=${1:?Usage: dd-usb.sh <iso> <device>}
device=${2:?Usage: dd-usb.sh <iso> <device>}

if [[ ${EUID} -ne 0 ]]; then
    echo "Run this script with sudo." >&2
    exit 1
fi

dev_basename=$(basename "${device}")
if [[ ! -b ${device} ]] || [[ $(< "/sys/class/block/${dev_basename}/removable") != 1 ]]; then
    echo "Safety check failed: ${device} is not a removable disk." >&2
    exit 2
fi
test -s "${iso}" || { echo "${iso} missing." >&2; exit 3; }

actual_serial=$(udevadm info --query=property --name="${device}" | sed -n 's/^ID_SERIAL=//p')
if [[ -z ${actual_serial} ]]; then
    echo "Could not read ID_SERIAL for ${device} via udevadm — refusing to continue." >&2
    exit 4
fi

echo "About to overwrite this device:"
udevadm info --query=property --name="${device}" | grep -E '^ID_(VENDOR|MODEL|SERIAL)=' || true
echo
read -r -p "Type or paste the ID_SERIAL above to confirm ERASING ${device}: " typed_serial
if [[ "${typed_serial}" != "${actual_serial}" ]]; then
    echo "Serial did not match — refusing to continue." >&2
    exit 5
fi

umount "${device}" 2>/dev/null || true
for p in "${device}"?*; do umount "$p" 2>/dev/null || true; done

echo "Writing (oflag=direct so progress reflects the actual device, not the page cache)..."
dd if="${iso}" of="${device}" bs=4M status=progress oflag=direct conv=fsync
sync

echo "Verifying write..."
iso_size=$(stat -c%s "${iso}")
src_hash=$(sha256sum "${iso}" | cut -d' ' -f1)
dst_hash=$(head -c "${iso_size}" "${device}" | sha256sum | cut -d' ' -f1)
[[ "${src_hash}" == "${dst_hash}" ]] || { echo "Checksum mismatch after dd." >&2; exit 6; }

echo "${device} now boots ${iso}."
