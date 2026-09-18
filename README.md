# The Magic Mountain

A minimal Alpine Linux UEFI live environment that runs Samsung's own
`fumagician` firmware-flashing tool directly against an NVMe drive —
for when Samsung Magician's installer/updater won't run, won't detect
your drive, or otherwise won't get out of its own way.

Built out of necessity after Samsung Magician (Windows and Linux) refused
to update the firmware on a Samsung SSD 960 EVO. `fumagician` is the real
tool Magician calls internally to do the flash; this repo boots straight
into it, off external media, with the drive unmounted, and nothing else
running.

## How it works

- A stock Alpine kernel/initrd (already ships NVMe/USB/UEFI drivers on the
  "standard"/"extended" releases) boots off a USB stick or ISO.
- Alpine's overlay mechanism (`lbu`/`apkovl`) applies `overlay/` at boot —
  no initrd rebuild needed. See `overlay/etc/hostname`,
  `overlay/root/.profile`, `overlay/usr/local/bin/fumagician`.
- Root auto-logs in on the physical console only (`overlay/bin/autologin`,
  wired up in `overlay/etc/inittab`); serial still requires a real login.
- `overlay/usr/local/bin/fumagician` is a safety wrapper: it refuses to run
  if any `/dev/nvme*` filesystem is mounted, and refuses to run unless a
  Samsung SSD 960 EVO is detected in `/sys/class/nvme/*/model`. Only then
  does it hand off to Samsung's real `fumagician` binary in
  `root/fumagician/`.

## What's NOT in this repo

`overlay/root/fumagician/{fumagician, DSRD.enc, <FWREV>.enc}` are **not**
included. `fumagician` is Samsung's proprietary binary, and the `.enc`
files are Samsung's signed/encrypted firmware payload — both come from
Samsung's own Magician / NVMe Firmware Update Tool download, and
redistributing them isn't this repo's call to make.

You need to locate those three files yourself inside your own Magician
install (or Samsung's standalone Linux NVMe firmware update tool), for
the firmware revision you're targeting, then run:

```sh
scripts/extract-firmware.sh /path/to/fumagician /path/to/DSRD.enc /path/to/<FWREV>.enc
```

This drops them into `overlay/root/fumagician/` with the right
permissions. They're gitignored — they will never end up in a commit.

## Building and booting

This is the workflow that was actually used, end to end, and it's smaller
and simpler than it might look — the whole image is around 300MB:

1. Prepare a boot tree: get a stock Alpine `bzImage` + `initrd` (the
   "standard" or "extended" ISO/netboot release already has NVMe/USB/UEFI
   drivers baked in — that's really all you need, plus a root shell), and
   a `grub.cfg` that chainloads them. Lay these out as
   `boot-tree/{bzImage,initrd,boot/grub/grub.cfg}`.
2. `scripts/extract-firmware.sh ...` — populate the overlay with your own
   Samsung files (see above).
3. `scripts/pack-overlay.sh` — tars `overlay/` into
   `build/fumagician.apkovl.tar.gz`.
4. `scripts/build-uefi-iso.sh boot-tree/ build/the-magic-mountain.iso` —
   `grub-mkrescue` produces a BIOS+UEFI hybrid ISO.
5. `scripts/dd-usb.sh build/the-magic-mountain.iso /dev/sdX <your-drive's-udevadm-ID_SERIAL>` —
   writes the hybrid ISO straight to the USB stick. No partitioning, no
   bootloader install step, no Ventoy. This is the only USB-writing method
   that was actually verified to work.

   All the USB-writing scripts require `EXPECTED_USB_SERIAL` to match your
   actual drive (`udevadm info --query=property --name=/dev/sdX | grep
   ID_SERIAL`) before they'll touch it — that's what stops you from wiping
   the wrong disk. It is not optional and there is no override flag.
6. Boot the media, unplug/unmount anything else touching the target NVMe
   drive, and run `fumagician` at the prompt. It will refuse to proceed if
   the wrong drive is detected or an NVMe filesystem is still mounted.

### Alternative / untested USB-writing methods

`scripts/build-uefi-usb.sh` (partitions the stick and `grub-install`s onto
it instead of `dd`) and `scripts/write-ventoy-usb.sh` (Ventoy) are also in
`scripts/`, generalized from earlier attempts, but neither was actually
used for the working result — `dd-usb.sh` was. Ventoy specifically was a
dead end here: it was tried to work around Samsung's own official ISO
being unbootable garbage (no bootloader, no initramfs, nothing), before
switching to building a real bootable environment from Alpine instead. If
you use either of these two, treat them as starting points, not proven
paths.

## Why "The Magic Mountain"

Alpine Linux *is* the mountain; `fumagician` — literally "smoke magician"
— *is* the trick. Also a nod to Thomas Mann's novel, which is set in an
Alpine sanatorium. Read into that what you will.

## Disclaimer

This flashes firmware on an NVMe drive. That's inherently riskier than
almost anything else you can do to a machine — a failed/interrupted flash
can brick the drive. Use at your own risk, back up first, and don't run
it on a drive that's currently mounted or in use. Not affiliated with or
endorsed by Samsung.

## License

MIT — see `LICENSE`. (Applies to this repo's own scripts/overlay content
only; it has no bearing on Samsung's proprietary files, which aren't
included here.)
