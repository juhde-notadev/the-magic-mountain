#!/usr/bin/env bash
# Copies the staged Samsung files (from extract-firmware.sh, in
# samsungiso/staging/) into overlay/, then packs overlay/ into an
# Alpine "lbu" overlay archive. Named localhost.apkovl.tar.gz on
# purpose: Alpine's live-boot init checks for "<hostname>.apkovl.tar.gz"
# first, then always falls back to "localhost.apkovl.tar.gz" regardless
# of what hostname actually gets set — using that name works no matter
# what, and it's what actually got used in the verified build.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
overlay="${repo_root}/overlay"
staging="${repo_root}/samsungiso/staging"
output="${1:-${repo_root}/repackiso/localhost.apkovl.tar.gz}"

test -x "${staging}/fumagician" || {
    echo "${staging}/fumagician is missing." >&2
    echo "Run scripts/extract-firmware.sh first." >&2
    exit 1
}
test -s "${staging}/target-model" || {
    echo "${staging}/target-model is missing or empty." >&2
    echo "Run scripts/extract-firmware.sh first." >&2
    exit 1
}

fw_enc=$(find "${staging}" -maxdepth 1 -name '*.enc' ! -name 'DSRD.enc' | head -n1)
[[ -n "${fw_enc}" ]] || { echo "No firmware .enc payload in ${staging}." >&2; exit 1; }

mkdir -p "${overlay}/root/fumagician"
install -m 700 "${staging}/fumagician" "${overlay}/root/fumagician/fumagician"
install -m 600 "${staging}/DSRD.enc" "${overlay}/root/fumagician/DSRD.enc"
install -m 600 "${fw_enc}" "${overlay}/root/fumagician/$(basename "${fw_enc}")"
cp "${staging}/target-model" "${overlay}/etc/fumagician-target-model"

mkdir -p "$(dirname "${output}")"
tar -C "${overlay}" -czf "${output}" .
sha256sum "${output}"
echo "Overlay packed to ${output}."
