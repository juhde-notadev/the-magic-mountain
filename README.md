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

## What's NOT in this repo, and what this repo never does

`overlay/root/fumagician/{fumagician, DSRD.enc, <FWREV>.enc}` and
`overlay/etc/fumagician-target-model` are **not** included, and never
will be. `fumagician` is Samsung's proprietary binary, and the `.enc`
files are Samsung's signed/encrypted firmware payload — both come from
Samsung's own official firmware update ISO, and redistributing them
isn't this repo's call to make.

Nothing in this repo downloads anything from Samsung, or from Alpine,
on your behalf. You get both ISOs yourself, from their official
sources, and hand them to the scripts. That's deliberate — this repo
only ever touches files you already have on disk.

## Building and booting

1. Download your drive's firmware update ISO yourself, from Samsung's
   official support site for your exact model (e.g.
   `Samsung_SSD_960_EVO_3B7QCXE7.iso`). Nothing here fetches this for
   you.
2. Download the official Alpine "standard" or "extended" **x86_64** ISO
   yourself, from
   [alpinelinux.org/downloads](https://alpinelinux.org/downloads/)
   (pick another architecture if your hardware needs it). Don't unpack
   or modify it.
3. `git clone` this repo.
4. Put both ISOs wherever's convenient — inside the cloned repo is
   fine, they're gitignored either way.
5. `scripts/extract-firmware.sh <samsung-firmware.iso> "<model
   substring>"` — unpacks the Samsung ISO (it's just a kernel + initrd;
   no mounting, no Windows, no Magician needed) and stages
   `fumagician`/`DSRD.enc`/`<FWREV>.enc` into
   `overlay/root/fumagician/`, then writes `<model substring>` to
   `overlay/etc/fumagician-target-model`. Use something specific enough
   to only match your drive in `/sys/class/nvme/*/model`, e.g.
   `"960 EVO"`, `"970 EVO Plus"`, `"990 PRO"`.
6. `scripts/build-uefi-iso.sh <alpine-standard-*.iso>` — one command
   for "pack the overlay, add it to the ISO, done": it runs
   `pack-overlay.sh` (tars `overlay/` into
   `build/localhost.apkovl.tar.gz` — runnable on its own if you just
   want to inspect that file) and then uses
   `xorriso ... -boot_image any replay` to clone the stock Alpine ISO's
   existing BIOS+UEFI boot records unchanged while adding the apkovl at
   `/localhost.apkovl.tar.gz`. Produces `build/the-magic-mountain.iso`.
   No custom kernel/initrd/grub.cfg assembly — this is the actual
   technique that was verified to work, ~350MB image, no exotic
   tooling.
7. Plug in a USB stick you're willing to erase, then
   `sudo scripts/dd-usb.sh build/the-magic-mountain.iso /dev/sdX` —
   writes the hybrid ISO straight to it. No partitioning, no bootloader
   install step, no Ventoy; this is the method that was actually
   verified to work. It looks up `/dev/sdX`'s real serial via
   `udevadm`, shows it to you, and makes you type or paste it back to
   confirm before it touches anything — that's what stops you from
   wiping the wrong disk. It is not optional and there is no override
   flag.
8. Boot the media, unplug/unmount anything else touching the target NVMe
   drive, and run `fumagician` at the prompt. It will refuse to proceed
   if the wrong drive is detected or an NVMe filesystem is still
   mounted.

That's seven small, independently-inspectable steps rather than one
script that does everything — slower to type, but each stage is
something you can open and read before running, and a mistake at one
stage doesn't hide inside a bigger one.

### Alternative / untested method

`scripts/write-ventoy-usb.sh` writes the ISO from step 6 onto a Ventoy
stick instead of `dd`-ing it directly — useful if you want to keep other
ISOs on the same drive. It was never actually used for the working
result (`dd-usb.sh` was). Ventoy was originally tried to work around
Samsung's own official firmware ISO not booting on UEFI-only hardware —
turns out that ISO is BIOS-only (`isolinux`, no `/efi` El Torito record
at all), so on a machine without BIOS/CSM compatibility it simply won't
boot, full stop. (It's not actually broken or empty — it has a real
kernel, initrd, and bootloader, just no UEFI path. `extract-firmware.sh`
unpacks it directly rather than booting it, so this doesn't matter for
this repo either way.) Ventoy didn't fix that and was dropped in favor
of remastering a real UEFI-capable Alpine ISO instead. Treat
`write-ventoy-usb.sh` as a starting point, not a proven path.

## Other Samsung drives

Nothing about the boot environment, the overlay, or the build scripts is
specific to the 960 EVO — that's just the drive this was built for. To
target a different Samsung NVMe SSD (970 EVO Plus, 990 PRO, etc.):

1. Download *that* drive's official firmware update ISO from Samsung —
   don't mix files from a different drive's ISO, `fumagician` and the
   `.enc` payload are paired with each other.
2. Run `extract-firmware.sh` against that ISO with a model string that
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
