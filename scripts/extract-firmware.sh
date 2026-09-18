#!/usr/bin/env bash
# Populates overlay/root/fumagician/ with the three files Samsung's own
# updater needs, pulled from YOUR OWN copy of Samsung Magician / the
# Samsung NVMe firmware update tool. These files are Samsung's property
# and are not distributed with this repo — see README.md.
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: extract-firmware.sh <path-to-fumagician-binary> <path-to-DSRD.enc> <path-to-FWREV.enc>

Locate these three files inside your own Samsung Magician / NVMe firmware
update tool installation:
  - fumagician      Samsung's firmware-flashing binary (ELF, Linux x86)
  - DSRD.enc        device/auth descriptor Samsung's tool expects alongside it
  - <FWREV>.enc      the encrypted firmware image itself, named after the
                     target firmware revision (e.g. 3B7QCXE7.enc)
EOF
    exit 1
}

[[ $# -eq 3 ]] || usage

fumagician_bin=$1
dsrd_enc=$2
fw_enc=$3
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
dest="${repo_root}/overlay/root/fumagician"

for f in "$fumagician_bin" "$dsrd_enc" "$fw_enc"; do
    test -s "$f" || { echo "Missing or empty: $f" >&2; exit 1; }
done

file "$fumagician_bin" | grep -qi 'ELF' || {
    echo "Warning: $fumagician_bin does not look like an ELF binary." >&2
}

mkdir -p "$dest"
install -m 700 "$fumagician_bin" "$dest/fumagician"
install -m 600 "$dsrd_enc" "$dest/DSRD.enc"
install -m 600 "$fw_enc" "$dest/$(basename "$fw_enc")"

echo "Installed into $dest:"
ls -la "$dest"
echo
echo "These files are gitignored — they will not be committed."
