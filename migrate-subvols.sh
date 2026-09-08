#!/usr/bin/env bash
# One-time in-place migration: raw btrfs top-level -> @/@nix/@persist subvolumes.
# Run as root from a NixOS live USB. Nothing is deleted: same-filesystem moves are
# renames, and old data stays on the top-level as a fallback (see PHASE2.md).
set -euo pipefail

ROOT_UUID="fdbc04d4-599a-470c-b9dd-7e14493abb3a"
DISK="${DISK:-/dev/nvme0n1p6}"
TOP="/mnt/btrfs-top"

log() { printf '%s\n' "==> $*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

if [ "$(id -u)" -ne 0 ]; then
  die "run as root from a live USB"
fi

actual="$(readlink -f "/dev/disk/by-uuid/$ROOT_UUID")"
if [ "$actual" != "$(readlink -f "$DISK")" ]; then
  die "$DISK is not the root disk (uuid resolves to $actual); refusing"
fi

mkdir -p "$TOP"
if ! mountpoint -q "$TOP"; then
  mount -o subvolid=5 "$DISK" "$TOP"
fi
cd "$TOP"

for sub in @ @nix @persist; do
  if [ -e "$sub" ]; then
    die "$TOP/$sub already exists; refusing to continue"
  fi
done

for d in etc var home root nix; do
  if [ ! -d "$d" ]; then
    die "expected $TOP/$d on the top-level; layout differs from expectation, stop and inspect"
  fi
done

btrfs subvolume create @
btrfs subvolume create @nix
btrfs subvolume create @persist

log "moving state into subvolumes (renames, no data copied)"
mv nix/store @nix/store
mv etc @persist/etc
mv var @persist/var
mv home @persist/home
mv root @persist/root

log "done"
printf '%s\n' \
  "top-level leftovers (bin, usr, tmp, ...) are kept as fallback." \
  "next: mount the new layout and nixos-install --flake .#qat (PHASE2.md)"
