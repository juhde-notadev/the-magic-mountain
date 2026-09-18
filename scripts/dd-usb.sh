#!/usr/bin/env bash
# The actually-used method: grub-mkrescue output is a BIOS+UEFI hybrid ISO,
# so it can be written straight to a USB stick with dd — no partitioning,
# no bootloader install, no Ventoy needed.
#
# SAFETY: this overwrites the entire target device. You MUST pass
# EXPECTED_USB_SERIAL matching `udevadm info --query=property --name=<device>
# | grep ID_SERIAL` for your own drive — the script refuses to run otherwise.
set -euo pipefail

iso=${1:?Usage: dd-usb.sh <iso> <device> <EXPECTED_USB_SERIAL>}
device=${2:?Usage: dd-usb.sh <iso> <device> <EXPECTED_USB_SERIAL>}
expected_serial=${3:?Usage: dd-usb.sh <iso> <device> <EXPECTED_USB_SERIAL>}

if [[ ${EUID} -ne 0 ]]; then
    echo "Run this script with sudo." >&2
    exit 1
fi

dev_basename=$(basename "${device}")
if [[ ! -b ${device} ]] || [[ $(< "/sys/class/block/${dev_basename}/removable") != 1 ]]; then
    echo "Safety check failed: ${device} is not a removable disk." >&2
    exit 2
fi
if ! udevadm info --query=property --name="${device}" | grep -Fxq "ID_SERIAL=${expected_serial}"; then
    echo "Safety check failed: ${device} does not match EXPECTED_USB_SERIAL." >&2
    exit 3
fi
test -s "${iso}" || { echo "${iso} missing." >&2; exit 4; }

umount "${device}" 2>/dev/null || true
for p in "${device}"?*; do umount "$p" 2>/dev/null || true; done

dd if="${iso}" of="${device}" bs=4M status=progress conv=fsync
sync

echo "Verifying write..."
iso_size=$(stat -c%s "${iso}")
src_hash=$(sha256sum "${iso}" | cut -d' ' -f1)
dst_hash=$(head -c "${iso_size}" "${device}" | sha256sum | cut -d' ' -f1)
[[ "${src_hash}" == "${dst_hash}" ]] || { echo "Checksum mismatch after dd." >&2; exit 5; }

echo "${device} now boots ${iso}."
