# Session notes (yor / qat)

NixOS flake config for host `qat`, user `yor`. Format with alejandra before
committing. The user runs rebuilds themselves (`sudo nixos-rebuild switch
--flake .#qat`); verify changes with evals instead:
`nix eval .#nixosConfigurations.qat.config.system.build.toplevel.drvPath`.

## Layout / branch state

- `main` = phase 1: sops-nix secrets, devshell `secrets` util, zram, ssh
  hardening, autologin removed. The old `/cred` partition is retired and wiped.
- `phase2` = btrfs subvolumes (`@`, `@nix`, `@persist`) + impermanence
  scaffolding. **Do not merge into `main` before the live-USB disk migration
  in PHASE2.md succeeds.** It gets installed from the USB (`nixos-install`),
  never rebuilt against on the running system — subvolume mounts pointing at
  subvolumes that don't exist yet make the next boot fail.

## Gotchas learned the hard way

- `sudo nixos-rebuild` re-roots `flake.lock`. If evals then fail with
  "Permission denied" on flake.lock: `sudo chown yor:users flake.lock`.
- Flakes ignore untracked files: `git add` anything new (including `secrets/`
  payloads) before rebuilding, or sops silently deploys nothing.
- sops payloads in `secrets/` are whole-file binary format (extensionless);
  `defaultSopsFormat = "binary"` in sys/mods/core/secrets.nix is load-bearing.
- Adding a secret: `secrets add <name> <file>` in the devshell, then register
  the name in `userSecrets` (sys/mods/core/secrets.nix) and extend `deployPath`
  if it should not land in `~/.ssh/<name>`. Edit with `secrets edit <name>`.
- `known_hosts` is deliberately NOT in sops: it is state, not a secret, and
  ssh must be able to append new host keys across reboots.
- The age key exists twice and must stay identical: `~/.config/sops/age/keys.txt`
  (editing) and `/var/lib/sops-nix/key.txt` (boot decryption). An offline
  backup of it is still outstanding — every secret in the repo is unrecoverable
  without it.
- Disks: `/` on nvme0n1p6 (840G btrfs, raw top-level until the phase 2
  migration), `/dat` on sda1 (1.8T btrfs, documents/media/code; home dirs
  symlink into it via `setup.symLinks` tmpfiles rules), `/boot` on nvme0n1p5,
  nvme0n1p7 is blank 2G.
- The stylix "qt platform kde unsupported" eval warning is cosmetic.

## Roadmap

- Phase 3 (config only, no downtime): enumerate `/persist` per app instead of
  whole `/home`; snapper on `@persist`; dedupe plasma6+niri (pick one stack);
  make ollama on-demand; refactor setup/default.nix to a single specialArgs
  pass (kills the fragile per-module relative imports); delete dead setup
  fields (`extraPackages`, `userWebsite`, `secureBoot.bootspec`).
- Phase 4 (reinstall-scale): LUKS full-disk encryption + lanzaboote secure
  boot + TPM unlock. sops/subvolumes/impermanence carry over unchanged; this
  is the one step that cannot be retrofitted in place.
