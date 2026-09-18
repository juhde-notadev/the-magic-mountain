#!/usr/bin/env bash
# Populates overlay/root/fumagician/ with the three files Samsung's own
# updater needs, pulled from YOUR OWN copy of Samsung Magician / the
# Samsung NVMe firmware update tool, and configures which drive model the
# safety wrapper is allowed to run against. These files are Samsung's
# property and are not distributed with this repo — see README.md.
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: extract-firmware.sh <path-to-fumagician-binary> <path-to-DSRD.enc> <path-to-FWREV.enc> <target-model-string>

Locate these three files inside your own Samsung Magician / NVMe firmware
update tool installation, matching the drive and firmware revision you
are targeting:
  - fumagician      Samsung's firmware-flashing binary (ELF, Linux x86)
  - DSRD.enc        device/auth descriptor Samsung's tool expects alongside it
  - <FWREV>.enc      the encrypted firmware image itself, named after the
                     target firmware revision (e.g. 3B7QCXE7.enc)

<target-model-string> is matched (as a substring) against
/sys/class/nvme/*/model at boot — the wrapper refuses to run fumagician
unless it's present. Use something specific enough to only match your
drive, e.g. "970 EVO Plus" or "990 PRO". This isn't 960-EVO-specific:
any Samsung NVMe drive works as long as fumagician/DSRD.enc/<FWREV>.enc
come from the matching official Samsung updater for that model.
EOF
    exit 1
}

[[ $# -eq 4 ]] || usage

fumagician_bin=$1
dsrd_enc=$2
fw_enc=$3
target_model=$4
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
dest="${repo_root}/overlay/root/fumagician"

for f in "$fumagician_bin" "$dsrd_enc" "$fw_enc"; do
    test -s "$f" || { echo "Missing or empty: $f" >&2; exit 1; }
done
[[ -n "$target_model" ]] || { echo "target-model-string must not be empty." >&2; exit 1; }

file "$fumagician_bin" | grep -qi 'ELF' || {
    echo "Warning: $fumagician_bin does not look like an ELF binary." >&2
}

mkdir -p "$dest"
install -m 700 "$fumagician_bin" "$dest/fumagician"
install -m 600 "$dsrd_enc" "$dest/DSRD.enc"
install -m 600 "$fw_enc" "$dest/$(basename "$fw_enc")"
printf '%s' "$target_model" > "${repo_root}/overlay/etc/fumagician-target-model"

echo "Installed into $dest:"
ls -la "$dest"
echo
echo "Target model set to: $target_model"
echo "These files are gitignored — they will not be committed."
