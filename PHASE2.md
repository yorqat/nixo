# Phase 2: btrfs subvolumes + impermanence

Converts the root disk (`nvme0n1p6`, 840G) from a raw top-level mount into
`@` / `@nix` / `@persist` subvolumes, with impermanence bind-mounting stateful
paths from `/persist`. Done in place: every move is a same-filesystem rename,
nothing is deleted, and the old top-level stays as a bootable fallback until
you clean it manually.

> **Warning:** do **not** merge this branch into `main` before the migration
> succeeds. If the running system ever rebuilds with subvolume mounts pointing
> at subvolumes that don't exist yet, the next reboot fails. Merge only after
> the verification checklist below passes.

Target layout:

```
nvme0n1p6 (btrfs, uuid fdbc04d4...)
├── @         -> /          (blank at every boot)
├── @nix      -> /nix
├── @persist  -> /persist   (etc, var, home, root live here; impermanence
│                             bind-mounts them into place at boot)
└── top-level leftovers    (fallback; delete only after verification)

nvme0n1p5 -> /boot (unchanged)
sda1      -> /dat  (untouched, gains compress=zstd + noatime)
nvme0n1p7 -> blank 2G (unallocated for future use)
```

## 0. Pre-flight (on the running system)

```sh
git push origin main phase2          # both branches safe on the remote
nixos-rebuild switch --flake .#qat   # confirm phase-1 system is green
```

Optional belt-and-suspenders full snapshot (reflink copy, near-instant) — take
it before the USB session, while booted normally:

```sh
sudo mount -o subvolid=5 /dev/nvme0n1p6 /mnt
sudo btrfs subvolume snapshot /mnt /mnt/pre-phase2-snap
sudo umount /mnt
```

## 1. Live USB session

Boot a NixOS live ISO (same version or newer), then as root:

```sh
# mount the data disk to reach this repo
mkdir -p /dat && mount /dev/sda1 /dat
cd /dat/Documents/A-Work/1-Fling/nixo
git checkout phase2

# migrate (see script for safety assertions)
chmod +x migrate-subvols.sh && ./migrate-subvols.sh

# mount the new layout
mount -o subvol=@,compress=zstd,noatime /dev/nvme0n1p6 /mnt
mkdir -p /mnt/nix /mnt/persist /mnt/boot
mount -o subvol=@nix,compress=zstd,noatime /dev/nvme0n1p6 /mnt/nix
mount -o subvol=@persist,compress=zstd,noatime /dev/nvme0n1p6 /mnt/persist
mount /dev/nvme0n1p5 /mnt/boot

# install the phase2 config
nixos-install --flake .#qat --root /mnt
```

`nixos-install` needs network for substitutions. Your login password survives:
it lives in `@persist/etc/shadow`.

## 2. Reboot and verify

```sh
findmnt / /nix /persist        # subvol=@ / @nix / @persist
ls /persist/etc/ssh            # host keys present
ls -la ~/.ssh                  # sops-deployed keys (symlinks into /run/secrets)
swapon --show                  # zram
git -C ~/Documents/A-Work/1-Fling/nixo status
```

Then reboot **once more** and re-verify: that proves root is truly blank and
everything comes back from `/persist`.

## 3. Afterlife

```sh
git checkout main && git merge phase2 && git push   # only after verification
```

Reclaim the fallback space (only when confident — this removes the escape
hatch):

```sh
sudo mount -o subvolid=5 /dev/nvme0n1p6 /mnt
cd /mnt
rm -rf bin usr tmp run boot var.old etc.old 2>/dev/null   # leftovers, NOT @*
ls                                                        # should show only @, @nix, @persist, lost+found
cd / && umount /mnt
```

The freed 2G `nvme0n1p7` stays blank; repurpose later or fold into a bigger
repartition alongside `@persist` if it ever feels small.
