## Session notes (yor / qat)

NixOS flake config for host `qat`, user `yor`. Format with alejandra before
committing. The user runs rebuilds themselves (`sudo nixos-rebuild switch
--flake .#qat`); verify changes with evals instead:
`nix eval .#nixosConfigurations.qat.config.system.build.toplevel.drvPath`.

## Conventions

- `setup/default.nix` is THE user config and is passed everywhere via
  specialArgs from `sys/default.nix` (system modules get `setup` as a module
  arg; HM modules via `home-manager.extraSpecialArgs`). Never `import
  .../setup` inside a module.
- `setup.lite = true` is the fresh-install-safe profile: gates the nvidia and
  ollama modules (both conditionally imported in sys/default.nix) and plasma6.
  Machine-specific stuff must stay behind it or another `includes` flag.

## Layout

- Everything lives on `main`. Phase 1 (sops-nix secrets, devshell `secrets`
  util, zram, ssh hardening, autologin removed) and phase 2 (btrfs
  subvolumes `@`/`@nix`/`@persist` + impermanence) are merged; the live-USB
  disk migration succeeded and `PHASE2.md` / `migrate-subvols.sh` are deleted.

## Gotchas learned the hard way

- `sudo nixos-rebuild` re-roots `flake.lock`. If evals then fail with
  "Permission denied" on flake.lock: `sudo chown yor:users flake.lock`.
- Flakes ignore untracked files: `git add` anything new (including `secrets/`
  payloads) before rebuilding, or sops silently deploys nothing.
- sops payloads in `secrets/` are whole-file binary format (extensionless);
  `defaultSopsFormat = "binary"` in sys/mods/core/secrets.nix is load-bearing.
- Adding a secret: `secrets add <name> <file>` in the devshell — every git-tracked
  payload in `secrets/` deploys automatically to `~/.config/secrets/<name>` (no
  allowlist; the flake enumerates the dir). Edit with `secrets edit <name>`.
- Personal secret config lives in `setup.secrets` (setup/default.nix): `deployPaths`
  (payload -> home-relative path, e.g. ssh keys), `envNames` (payload -> env var,
  rendered into `~/.config/secrets/env` which `.bashrc` sources), `root`
  (root-owned neededForUsers payloads like the password hash).
- Per-app home persistence lives in `setup.persist` (setup/default.nix):
  `homeDirs`/`homeFiles`, home-relative. System-level paths stay in
  sys/mods/core/persistence.nix; modules self-register by appending to
  `environment.persistence."/persist"`.
- `known_hosts` is deliberately NOT in sops: it is state, not a secret, and
  ssh must be able to append new host keys across reboots.
- The age key exists twice and must stay identical: `~/.config/sops/age/keys.txt`
  (editing) and `/var/lib/sops-nix/key.txt` (boot decryption). An offline
  backup of it is still outstanding — every secret in the repo is unrecoverable
  without it.
- Disks: `/` on nvme0n1p6 (840G btrfs; subvols `@` -> `/`, `@nix` -> `/nix`,
  `@persist` -> `/persist`, impermanence persists /var + /home + /etc/machine-id
  + sops key), `/dat` on sda1 (1.8T btrfs, documents/media/code; home dirs
  symlink into it via `setup.symLinks` tmpfiles rules), `/boot` on nvme0n1p5,
  nvme0n1p7 is blank 2G.

## Roadmap

- Phase 3 (config only, no downtime): enumerate `/persist` per app instead of
  whole `/home`; snapper on `@persist`; dedupe plasma6+niri (pick one stack);
  make ollama on-demand. (Done: per-app persistence, on-demand ollama module
  with boot-free daemon + idle-stop timer, setup refactor. Remaining: snapper,
  plasma6+niri dedupe.)
- Phase 4 (reinstall-scale): LUKS full-disk encryption + lanzaboote secure
  boot + TPM unlock. sops/subvolumes/impermanence carry over unchanged; this
  is the one step that cannot be retrofitted in place.
