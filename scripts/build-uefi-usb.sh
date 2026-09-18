#!/usr/bin/env bash
# Writes a prepared boot tree directly to a USB drive as a UEFI boot disk
# (GRUB + FAT32 ESP), instead of building an ISO.
#
# SAFETY: this repartitions and formats the target device. You MUST pass
# EXPECTED_USB_SERIAL matching `udevadm info --query=property --name=<device>
# | grep ID_SERIAL` for your own drive — the script refuses to run otherwise.
# This is not optional; it is what stops you from wiping the wrong disk.
set -euo pipefail

boot_tree=${1:?Usage: build-uefi-usb.sh <boot-tree-dir> <device> <EXPECTED_USB_SERIAL>}
device=${2:?Usage: build-uefi-usb.sh <boot-tree-dir> <device> <EXPECTED_USB_SERIAL>}
expected_serial=${3:?Usage: build-uefi-usb.sh <boot-tree-dir> <device> <EXPECTED_USB_SERIAL>}
partition="${device}1"
mount_dir=/mnt/magic-mountain-usb
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
apkovl="${repo_root}/build/$(cat "${repo_root}/overlay/etc/hostname").apkovl.tar.gz"

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
test -s "${boot_tree}/bzImage" && test -s "${boot_tree}/initrd" || {
    echo "Boot tree is missing bzImage/initrd." >&2
    exit 4
}
test -s "${apkovl}" || { echo "${apkovl} missing — run pack-overlay.sh first." >&2; exit 4; }

echo "Installing UEFI boot-media tools..."
pacman -Syu --needed --noconfirm grub dosfstools efibootmgr mtools

echo "Rebuilding ${device} as a UEFI boot disk..."
umount "${device}" "${partition}" 2>/dev/null || true
wipefs -a "${device}"
parted -s "${device}" mklabel gpt
parted -s "${device}" mkpart ESP fat32 1MiB 257MiB
parted -s "${device}" set 1 esp on
partprobe "${device}"
udevadm settle
mkfs.fat -F 32 -n MAGICMTN "${partition}"

mkdir -p "${mount_dir}"
mount "${partition}" "${mount_dir}"
cleanup() { sync; umount "${mount_dir}" 2>/dev/null || true; }
trap cleanup EXIT

mkdir -p "${mount_dir}/boot"
cp "${boot_tree}/bzImage" "${boot_tree}/initrd" "${apkovl}" "${mount_dir}/"

grub-install \
    --target=x86_64-efi \
    --efi-directory="${mount_dir}" \
    --boot-directory="${mount_dir}/boot" \
    --removable \
    --no-nvram \
    --recheck \
    "${device}"

cp "${boot_tree}/boot/grub/grub.cfg" "${mount_dir}/boot/grub/grub.cfg"
sync

echo "Verifying copied boot files against source..."
for f in bzImage initrd; do
    src=$(sha256sum "${boot_tree}/${f}" | cut -d' ' -f1)
    dst=$(sha256sum "${mount_dir}/${f}" | cut -d' ' -f1)
    [[ "${src}" == "${dst}" ]] || { echo "Checksum mismatch on ${f}." >&2; exit 5; }
done
test -s "${mount_dir}/EFI/BOOT/BOOTX64.EFI"
test -s "${mount_dir}/boot/grub/grub.cfg"

echo "UEFI boot USB ready on ${device}."
