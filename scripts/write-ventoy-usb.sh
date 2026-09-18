#!/usr/bin/env bash
# Alternative to build-uefi-usb.sh: installs Ventoy on a USB drive and
# copies a pre-built ISO (from build-uefi-iso.sh) onto it. Useful if you
# want to keep other ISOs on the same drive.
#
# SAFETY: same as build-uefi-usb.sh — EXPECTED_USB_SERIAL must match your
# own drive, or the script refuses to run.
set -euo pipefail

ventoy_dir=${1:?Usage: write-ventoy-usb.sh <ventoy-dir> <iso> <device> <EXPECTED_USB_SERIAL>}
iso=${2:?Usage: write-ventoy-usb.sh <ventoy-dir> <iso> <device> <EXPECTED_USB_SERIAL>}
device=${3:?Usage: write-ventoy-usb.sh <ventoy-dir> <iso> <device> <EXPECTED_USB_SERIAL>}
expected_serial=${4:?Usage: write-ventoy-usb.sh <ventoy-dir> <iso> <device> <EXPECTED_USB_SERIAL>}
partition="${device}1"
mount_dir=/mnt/magic-mountain-ventoy

if [[ ${EUID} -ne 0 ]]; then
    echo "Run this script with sudo." >&2
    exit 1
fi

dev_basename=$(basename "${device}")
if [[ ! -b ${device} ]] || [[ $(< "/sys/class/block/${dev_basename}/removable") != 1 ]]; then
    echo "Safety check failed: ${device} is not removable." >&2
    exit 2
fi
if ! udevadm info --query=property --name="${device}" | grep -Fxq "ID_SERIAL=${expected_serial}"; then
    echo "Safety check failed: ${device} does not match EXPECTED_USB_SERIAL." >&2
    exit 3
fi
test -x "${ventoy_dir}/Ventoy2Disk.sh" || { echo "Ventoy2Disk.sh not found in ${ventoy_dir}." >&2; exit 4; }
test -s "${iso}" || { echo "${iso} missing." >&2; exit 4; }

umount "${device}" "${partition}" 2>/dev/null || true
# -I forces reinstall so rerunning replaces an existing Ventoy disk; -g selects GPT for UEFI.
"${ventoy_dir}/Ventoy2Disk.sh" -I -g "${device}"
partprobe "${device}"
udevadm settle
mkdir -p "${mount_dir}"
mount "${partition}" "${mount_dir}"
cp "${iso}" "${mount_dir}/"
sync

echo "Verifying copy..."
src=$(sha256sum "${iso}" | cut -d' ' -f1)
dst=$(sha256sum "${mount_dir}/$(basename "${iso}")" | cut -d' ' -f1)
umount "${mount_dir}"
[[ "${src}" == "${dst}" ]] || { echo "Checksum mismatch after copy." >&2; exit 5; }

echo "Ventoy USB ready on ${device} with $(basename "${iso}")."
