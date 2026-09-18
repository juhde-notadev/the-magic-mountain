# The Magic Mountain

A minimal Alpine Linux live environment that runs Samsung's own
`fumagician` firmware-flashing tool directly against an NVMe SSD — for
when Samsung Magician's installer/updater won't run, won't detect your
drive, or otherwise won't get out of its own way.

Built out of necessity after Samsung Magician (Windows and Linux) refused
to update the firmware on a Samsung SSD 960 EVO. `fumagician` is the real
tool Magician calls internally to do the flash; this repo boots straight
into it, off external media, with the drive unmounted, and nothing else
running. Nothing here is 960-EVO-specific — see "Other Samsung drives"
below.

## How it works

- A **completely unmodified, official Alpine ISO** (the "standard" or
  "extended" release already ships NVMe/USB/UEFI drivers and a root
  shell — that's all this needs) is remastered by adding exactly one
  file at its root: `localhost.apkovl.tar.gz`. Alpine's live-boot init
  always checks for that file and applies it automatically — no custom
  kernel, initrd, or bootloader config required.
- That file is `overlay/` packed up. Alpine's overlay mechanism
  (`lbu`/`apkovl`) applies it at boot. See `overlay/etc/hostname`,
  `overlay/root/.profile`, `overlay/usr/local/bin/fumagician`.
- Root auto-logs in on the physical console only (`overlay/bin/autologin`,
  wired up in `overlay/etc/inittab`); serial still requires a real login.
- `overlay/usr/local/bin/fumagician` is a safety wrapper: it refuses to
  run if any `/dev/nvme*` filesystem is mounted, and refuses to run
  unless a drive matching `overlay/etc/fumagician-target-model` is
  detected in `/sys/class/nvme/*/model`. Only then does it hand off to
  Samsung's real `fumagician` binary in `root/fumagician/` — which asks
  for a `y`/`n` confirmation of its own before it touches anything.
  Afterward the wrapper doesn't just exit silently: it reads
  `/sys/class/nvme/*/firmware_rev`, compares it against the target
  revision pulled from the `<FWREV>.enc` filename, and prints either
  `FLASH VERIFIED` or a clear `FLASH STATUS UNCONFIRMED` / `FLASH
  FAILED` — it never leaves you guessing whether it worked. Samsung's
  dual firmware-slot design runs a key check on the uploaded image and
  swaps the active slot in hardware within milliseconds — no controller
  reset involved — so the wrapper only retries for a few seconds (to
  give the host driver a moment to notice and refresh its cached
  Identify Controller data), not to wait out a reboot.

## What's NOT in this repo

`overlay/root/fumagician/{fumagician, DSRD.enc, <FWREV>.enc}` and
`overlay/etc/fumagician-target-model` are **not** included.
`fumagician` is Samsung's proprietary binary, and the `.enc` files are
Samsung's signed/encrypted firmware payload — both come from Samsung's
own Magician / NVMe Firmware Update Tool download, and redistributing
them isn't this repo's call to make.

You need to locate those three files yourself inside your own Magician
install (or Samsung's standalone Linux NVMe firmware update tool), for
the exact drive and firmware revision you're targeting, then run:

```sh
scripts/extract-firmware.sh /path/to/fumagician /path/to/DSRD.enc /path/to/<FWREV>.enc "<model substring>"
```

`<model substring>` is whatever uniquely identifies your drive in
`/sys/class/nvme/*/model` — e.g. `"960 EVO"`, `"970 EVO Plus"`, `"990
PRO"`. This drops the three Samsung files into `overlay/root/fumagician/`
and writes the model string to `overlay/etc/fumagician-target-model`.
All four are gitignored — they will never end up in a commit.

## Building and booting

This is the exact workflow that was verified end to end, ~350MB image,
no exotic tooling:

1. Download the official Alpine "standard" or "extended" **x86_64** ISO
   from [alpinelinux.org/downloads](https://alpinelinux.org/downloads/)
   (pick another architecture if your hardware needs it — the technique
   is the same). Don't unpack or modify it.
2. `scripts/extract-firmware.sh ...` — populate the overlay with your own
   Samsung files and target model (see above).
3. `scripts/pack-overlay.sh` — tars `overlay/` into
   `build/localhost.apkovl.tar.gz`.
4. `scripts/build-uefi-iso.sh /path/to/alpine-standard-*.iso` — uses
   `xorriso ... -boot_image any replay` to clone the stock ISO's existing
   BIOS+UEFI boot records unchanged while adding the packed apkovl at
   `/localhost.apkovl.tar.gz`. Produces `build/the-magic-mountain.iso`.
5. `sudo scripts/dd-usb.sh build/the-magic-mountain.iso /dev/sdX` —
   writes the hybrid ISO straight to the USB stick. No partitioning, no
   bootloader install step, no Ventoy. This is the method that was
   actually verified to work. It looks up `/dev/sdX`'s real serial via
   `udevadm`, shows it to you, and makes you type or paste it back to
   confirm before it touches anything — that's what stops you from
   wiping the wrong disk. It is not optional and there is no override
   flag.
6. Boot the media, unplug/unmount anything else touching the target NVMe
   drive, and run `fumagician` at the prompt. It will refuse to proceed
   if the wrong drive is detected or an NVMe filesystem is still
   mounted.

### Alternative / untested method

`scripts/write-ventoy-usb.sh` writes the ISO from step 4 onto a Ventoy
stick instead of `dd`-ing it directly — useful if you want to keep other
ISOs on the same drive. It was never actually used for the working
result (`dd-usb.sh` was); Ventoy was originally tried to work around
Samsung's own official ISO being unbootable garbage (no bootloader, no
initramfs, nothing), before switching to remastering a real Alpine ISO
instead. Treat it as a starting point, not a proven path.

## Other Samsung drives

Nothing about the boot environment, the overlay, or the build scripts is
specific to the 960 EVO — that's just the drive this was built for. To
target a different Samsung NVMe SSD (970 EVO Plus, 990 PRO, etc.):

1. Get `fumagician`, `DSRD.enc`, and the firmware `.enc` file for *that*
   drive from *its* matching Samsung Magician / firmware updater release
   — don't mix files from different drive generations, they're paired
   with each other.
2. Run `extract-firmware.sh` with those files and a model string that
   matches that drive's `/sys/class/nvme/*/model` output.
3. Everything else in "Building and booting" is unchanged.

This hasn't been verified on anything but the 960 EVO, since that's the
only drive it's been run against — if you try it on something else,
opening an issue with what did or didn't work would help others.

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
