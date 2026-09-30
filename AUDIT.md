# Config audit — 2026-09-30

Audit of the whole tree at `4d08de3` + uncommitted working-tree changes
(`flake.nix`, `sys/host/default.nix`). Every claim below was checked against a
live `nix eval` of `.#nixosConfigurations.qat` and, for §1, against the running
system. Nothing here is load-bearing-broken: the config evaluates clean and
`alejandra --check` passes. The only genuine bug classes are **§1** and **§6.2**.

Checked with:
```sh
nix eval .#nixosConfigurations.qat.config.system.build.toplevel.drvPath
nix develop -c alejandra --check .
```

Legend: `[ ]` open · `[~]` in progress · `[x]` done. Work top-down; §1 first.

---

## 1. The architecture's central invariant is false

- [ ] **`/` is not ephemeral. Nothing wipes it.**

  There is no `tmpfs.root`, no `boot.initrd.postResumeCommands` subvol rotation,
  and no tmpfiles clean rule anywhere in the tree. The pinned impermanence
  (`7b1d382`, bind-mount based) never wipes root by design — its own README tells
  you to add the btrfs `@` rotation yourself.

  Proof from this machine: rebooted today (`system boot 2026-09-30 20:10`), and
  `/etc/ssh/ssh_host_ed25519_key` is dated **2026-09-13**. `/etc` is not a
  separate mount, so it inherits btrfs `[@]` and survives.

  Contradicted by `sys/mods/core/persistence.nix:2`, `AGENTS.md`,
  `README.md:11` and `README.md:47`.

  So `environment.persistence."/persist"` currently buys nothing — the allowlist
  is decorative and `@` grows monotonically forever.

  **Decide:** implement the wipe (rotation in `postResumeCommands`, per
  impermanence's README) *or* stop claiming it. Note it becomes a real bug the
  moment you fix it — see the NetworkManager note in §6.4.

---

## 2. Contradictions inside the config

- [ ] **2.1 The uncommitted working-tree change is self-defeating.**

  ```diff
  -      inputs.nixpkgs.follows = "nixpkgs";
  +      # inputs.nixpkgs.follows = "nixpkgs";
  +    package = pkgs.niri;      # sys/host/default.nix:48
  ```

  `package = pkgs.niri` already pins the binary. Commenting out `follows` does
  nothing for that and only *adds* a second nixpkgs to the lock. Result: root is
  `7a0f122f`, but `niri` resolves its nixpkgs to a stale `b4fd65b1`.

  **Fix:** keep `follows`, drop the comment.

- [ ] **2.2 `niri-flake` earns almost nothing and costs a lot.**

  You now take `pkgs.niri` (26.04) and `xwayland-satellite` from pkgs, so the
  flake's `niri-stable`/`niri-unstable`/`xwayland-satellite-*` packages and its
  binary cache are unused. What it *does* still do:

  - forces `xdg-desktop-portal-gnome`
  - runs a **KDE polkit agent** (`niri-flake-polkit` →
    `polkit-kde-authentication-agent-1`)
  - disables nixpkgs' own niri module via `disabledModules`
  - inflates `home-manager.sharedModules` to **30 entries for 3 distinct files**
    (stylix's HM integration imported ~28×, because stylix is injected both
    directly and via niri-flake)

  nixpkgs ships both a NixOS and an HM niri module that cover this without the
  KDE baggage. See also the follow-up in §5.

- [x] **2.3 Plasma6 is gone but its fingerprints remain.** — fixed

  Commit `4d08de3` purged plasma6, yet:

  - ~~`usrs/default.nix:59-62` still justifies
    `stylix.targets.qt.platform = lib.mkForce "qtct"` by a plasma6 argument~~
    → removed. Verified a **no-op**: stylix computes `qtct` anyway when no
    `gnome`/`plasma6`/`lxqt` desktopManager is enabled (`modules/qt/nixos.nix:39`
    — all three confirmed `false`), and `"qtct"` is already the option default.
  - ~~`setup/default.nix:8-11` still says `lite` gates "nvidia gpu, plasma6"~~
    → comment now reads "nvidia gpu" only.
  - `README.md:12,169` and the `AGENTS.md` roadmap still list plasma6 — **not
    done**, docs only.
  - ~~the stylix **kde target is still on**~~ → `stylix.targets.kde.enable` and
    `stylix.targets.gnome.enable` are now `false` in `usrs/default.nix`. Both
    default to `true` upstream; dropping them removed `stylix-kde-theme` from
    `home.packages`, both `stylix-activate-*` autostart entries and every
    `xdg.systemDirs.config` entry. `qt`/`gtk` theming is untouched
    (`qt.style.name = "kvantum"`, `qt.platformTheme.name = "qtct"`).

  **Correction to the original finding:** the claim that `kvantum` is not in the
  profile was wrong. It checked only `environment.systemPackages` (the *system*
  profile); the plugin ships via *home-manager* — `qtstyleplugin-kvantum5` and
  `qtstyleplugin-kvantum` are both in `home.packages`, pulled in by stylix's qt
  target setting `qt.kvantum.enable = true`. `QT_STYLE_OVERRIDE=kvantum` is
  therefore valid, and no Qt app is falling back.

- [x] **2.3b Orphan GNOME settings in `sys/host/default.nix`.** — fixed

  All three lines were dead weight, proven by closure diff:

  - `services.gnome.gnome-keyring.enable` — **redundant**: niri-flake sets it
    unconditionally (`flake.nix:509`). Removing it changes nothing; gnome-keyring
    stays reachable via `system-path`/`pam.d`/`dbus-1`.
  - `services.gnome.glib-networking.enable` — **redundant**: `nautilus` and
    `geoclue` pull glib-networking in regardless.
  - `services.udev.packages = [ gnome-settings-daemon ]` — the brightness-OSD
    hack. Dead: `usrs/mods/niri/default.nix:113-114` drives brightness with
    `brightnessctl` and draws the OSD with `eww open osc-brightness`. Nothing
    calls `org.gnome.SettingsDaemon`. This one was real, and removing it also
    took `libgweather`, `gweather-locations`, `geocode-glib`, `libgphoto2`,
    `sane`/`net-snmp`, `colord`, `argyllcms` and `gnome-session-ctl` with it.

  Not orphans, deliberately left alone: niri-flake forces
  `xdg-desktop-portal-gnome` and `ente-auth` needs gnome-keyring. Both are
  §2.2 fallout, fixed by dropping niri-flake, not by editing this file.

- [ ] **2.4 `lite` doesn't gate the machine-specific stuff it claims to.**

  `usrs/mods/apps/opencode/default.nix:13-18` hardcodes
  `__NV_PRIME_RENDER_OFFLOAD`, `NVIDIA-G0` and `__VK_LAYER_NV_optimus` into
  ollama's environment with no `setup.lite` / `setup.includes.nvidia` guard.
  Flip `lite = true` and ollama starts with NVIDIA offload env against no
  driver.

- [ ] **2.5 `flake.nix:52-55` — dead `allowUnfree`.**

  `config.allowUnfree = true` on a locally `import`ed nixpkgs is dead: that
  `pkgs` is only used for `devshell`. The system pkgs come from `nixosSystem`,
  where `sys/mods/core/nix.nix:9` already sets it.

- [ ] **2.6 `nix.nix` sets three defaults to their default values.**

  `environment.defaultPackages = []` (verified `[]` is already the default),
  `allowBroken = false`, `allowInsecure = false`.

- [ ] **2.7 `nix.settings` unions with module defaults instead of replacing.**

  Generated `/etc/nix/nix.conf` actually contains:

  ```
  trusted-users = root root yor
  substituters = https://niri.cachix.org https://cache.nixos.org?priority=10 ... https://hyprland.cachix.org ... https://cache.nixos.org/
  trusted-public-keys = ... niri.cachix.org-1:... niri.cachix.org-1:...
  experimental-features =          <- empty, from the store default
  experimental-features = nix-command flakes
  ```

  - `trusted-users = ["root" setup.userName]` unions with the default
    `["root"]` → `root root yor`. Use `lib.mkForce` or just `[ setup.userName ]`.
  - `niri.cachix.org` is already injected by the niri-flake module
    (`niri-flake.cache.enable` defaults to `true`) — your hand-written copy is a
    duplicate.
  - `hyprland.cachix.org` is trusted with a key for a flake you don't have.
  - `experimental-features` via `extraOptions` emits a duplicate empty line
    first. Use `nix.settings.experimental-features = [ "nix-command" "flakes" ]`.

- [ ] **2.8 `usrs/default.nix:57 programs.home-manager.enable = true` is a no-op.**

  HM's own module gates its body on `!config.submoduleSupport.enable`, which is
  true here — and it would only install a stray `home-manager` binary if that
  ever flipped. Footgun, not a feature.

- [ ] **2.9 `setup/default.nix:20` points at `migrate-cred.sh`,** which no
  longer exists.

---

## 3. Anti-patterns

Security / correctness first.

- [ ] **3.1 `network.nix:3` + `sys/host:144-151` — sshd on all interfaces with
  no firewall.** `firewall.enable = false` and no `AllowUsers`/`ListenAddress`.
  `services.openssh.openFirewall = true` is the default but does nothing here.
  Re-enable the firewall (or at minimum scope sshd) and consider `AllowUsers`,
  `MaxAuthTries`, `X11Forwarding no`.

- [ ] **3.2 `sys/host:33` — privilege groups for nothing.** `docker`, `kvm` and
  `libvirtd` are added while `virtualisation.libvirtd.enable = false` and no
  docker/qemu is installed. `docker` is root-equivalent.

- [ ] **3.3 `sys/host:121-128` — `services.xserver.enable = true` on a
  niri-only box.** Verified bloat in the profile: `xorg-server xterm xrandr
  xrdb setxkbmap iceauth xlsclients xset xsetroot xinput xprop xauth`.
  `programs.xwayland.enable` alone suffices.

- [ ] **3.4 `sys/mods/wayland:13,20-23` — compositor env for a different
  compositor.** `WLR_BACKEND`, `WLR_NO_HARDWARE_CURSORS`,
  `WLR_DRM_NO_ATOMIC`, `NIXOS_OZONE_WL` and `CLUTTER_BACKEND` are
  wlroots/Hyprland/mutter only — no-ops under niri. `ANKI_WAYLAND` and
  `DIRENV_LOG_FORMAT` are unrelated leftovers.

- [ ] **3.5 `sys/mods/wayland:15` — `QT_QPA_PLATFORM = "wayland"`
  system-wide** forces every Qt app onto Wayland, breaking xcb-only tools.
  Belongs in the session, not `environment.variables`.

- [ ] **3.6 `sys/mods/nvidia:16-21` — the textbook NVIDIA env anti-pattern.**
  `GBM_BACKEND = "nvidia-drm"` and `__GLX_VENDOR_LIBRARY_NAME = "nvidia"`
  globally: niri picks its own backend, and the global
  `__GLX_VENDOR_LIBRARY_NAME` hijacks every GL app on the system.
  `__GL_GSYNC_ALLOWED` / `__GL_VRR_ALLOWED` are AMD-only. `nvidia-x11` is in the
  profile for no reason.

- [ ] **3.7 `nix.nix:18` — `auto-optimise-store = true`** on btrfs
  `compress=zstd`. Silent hardlink cloning, near-useless on btrfs and a known
  source of weirdness. Drop it.

- [ ] **3.8 `nix.nix:38-42` — GC window is ~4 days.** `gc.dates = "weekly"`
  with `options = "--delete-older-than 4d"` means a weekly GC that discards
  anything older than 4 days, so your rollback window is 4 days. Widen it or
  drop the manual `options`.

- [ ] **3.9 `sys/host:154-159` — wrong explanation.** The comment says the
  `/etc` symlink keeps the HM generation alive. It doesn't: the **system
  closure** roots it. The mechanism works; the comment is wrong.

- [ ] **3.10 `sys/host:13-25` — two locale intents fighting.**
  `defaultLocale = "en_PH.UTF-8"` (US conventions, Tagalog language) *and* every
  `LC_*` = `fil_PH`, including `LC_MONETARY` / `LC_TIME` / `LC_NUMERIC`. Shell
  dates and numbers come out in Filipino formats. Pick one.

- [ ] **3.11 `network.nix:18` — dead nameservers.** `["1.1.1.1" "1.0.0.1"]` is
  overridden by `services.resolved.enable = true`, which puts the stub resolver
  at `127.0.0.53` in `/etc/resolv.conf`.

- [ ] **3.12 `boot:25-28` + `sys/host:165` — dead NFS support.**
  `initrd.kernelModules = ["nfs"]`, `supportedFilesystems = ["nfs"]` and
  `nfs-utils`, with no NFS mounts anywhere.

- [ ] **3.13 `usrs/mods/eww/default.nix:46` — `~/.config/eww` is a read-only
  store symlink.** `theme` / `theme_mode` read wallpapers *through* it. Works,
  but zero user extensibility is possible and the bar config can never be
  touched outside Nix. Acceptable if deliberate; document it.

- [ ] **3.14 eww yuck scripts depend on the interactive session PATH.** Bare
  `wpctl`, `brightnessctl`, `mpc`, `ffmpeg`, `jq`, `niri`, `systemctl`, inherited
  from `niri.service` → `eww.service`. Works today, breaks the day that chain
  changes. Store paths via `lib.getExe` would be deterministic.

- [ ] **3.15 `usrs/mods/eww/config/scripts/music_info:5` — fixed
  `/tmp/eww_mp_thumbnail.png`** in a world-writable dir, plus an `ffmpeg`
  invocation per track change.

- [ ] **3.16 `sound.nix` — defaults set to defaults.**
  `services.pulseaudio.enable = false` and `security.rtkit.enable = true` are
  both no-ops given pipewire. `alsa.support32Bit = true` only matters for
  32-bit Steam titles.

- [ ] **3.17 `boot/default.nix` + `hardware-configuration.nix` — hand-edited
  generated file.** `hardware-configuration.nix` still carries its "Do not
  modify" header but has been edited. `swapDevices = []` coexists with
  `zramSwap.enable` and will be re-added by `nixos-generate-config`.
  `usbhid` / `sd_mod` / `usb_storage` in `availableKernelModules` are
  built-in no-ops. Move the durable bits into a `sys` module.

- [ ] **3.18 `sys/host:115,116,143` — commented-out dead code:**
  `# dbus.enable = true`, `# enable powerprofilesctl`, `# flatpak.enable = true`.

- [ ] **3.19 `sys/host:10,13-25` — needless string interpolation.**
  `"${setup.timeZone}"` etc. in 12 places; `setup` values are already strings.

---

## 4. Duplication & dead weight

- [ ] **4.1 Satoshi is defined twice.**
  - `sys/mods/core/fonts.nix:2-27` — `pname = "satoshi"`, version `2.000`, has
    `meta.license = licenses.unfree`
  - `sys/mods/core/stylix.nix:8-21` — `pname = "satoshi-font"`, version `1.0`,
    **no `meta`**, no `runHook`, different install path

  Both hashes are valid (verified) only because `stripRoot` differs, so
  `fetchzip`'s *output* hash differs. Two store paths, two downloads, and the
  stylix copy has no license metadata on an unfree font. `sentient`
  (`stylix.nix:23-36`) is also license-less. Extract one shared derivation.

- [ ] **4.2 ~7 MB of dead binaries in git.** `stitch_wall_dark.png` at the repo
  root is **md5-identical** to
  `usrs/mods/eww/config/images/wallpapers/stitch_wall_dark.png`;
  `stitch_wall.png` likewise. `stitch_wall_hd.png` (2.6 MB) and all three
  `.webp` files are referenced by nothing. Only `wall.png` is live (README).

- [ ] **4.3 `sys/host` re-states what niri-flake already sets with `mkDefault`:**
  `hardware.graphics.enable`, `programs.dconf.enable`,
  `services.gnome.gnome-keyring.enable`, and the `xdg.*` set.

- [ ] **4.4 `niri` is in `environment.systemPackages` twice** (from
  `programs.niri.package` and `hardware.graphics.enable`).

- [ ] **4.5 Personal data outside `setup/`** — the whole premise of the layout.
  Git name/emails, the `qarkdev+*` addresses and the
  `~/Documents/A-Work/1-Fling/gitlab/**` include all live in
  `usrs/mods/git/default.nix`. Move them to `setup`.

- [ ] **4.6 `yor-password-hash` is named twice** — `setup.secrets.root` and
  hardcoded at `sys/host:35`. Rename it and the host module breaks with an
  unhelpful error. Drive it from `setup.secrets.root`.

- [ ] **4.7 Dead signing config.** `usrs/mods/git`: `signing.format = null`,
  `gpg.format = "ssh"`, with `commit.gpgsign` and `user.signingkey` both
  commented out. Signs nothing.

- [ ] **4.8 `opencode` the binary is declared in `apps/neovim`'s
  `extraPackages`,** while its config is in `apps/opencode`. Comment out neovim
  and the binary vanishes.

- [ ] **4.9 Stylix targets programs that aren't installed.** System-level:
  `fish`, `lightdm`, `grub`, `plymouth`, `regreet`, `spicetify`. HM-level:
  `vscode` (its module is commented out), plus `hyprland`, `sway`, `river`,
  `wayfire`, `bspwm`, `i3`, … And `nixvim` is targeted by **both** the system
  and HM stylix instances.

- [ ] **4.10 `flake.nix:49` — misleading alias.**
  `outputs = {self, ...} @ inputs` binds `inputs` to the whole attrset, not
  `self.inputs` (which is what `sys/default.nix:6` actually uses). It's unused
  and reads exactly backwards.

- [ ] **4.11 No `formatter` output,** despite `AGENTS.md` mandating alejandra.
  The tree is currently alejandra-clean (verified), so
  `formatter = pkgs.alejandra` is free and makes `nix fmt` work.

- [ ] **4.12 `devshell` carries tools with no users:** `fnlfmt` (no fennel in
  the tree) and `yaml-language-server` (no yaml).

- [ ] **4.13 Hardcoded `trusted-public-keys` / `substituters` will rot.** The
  niri key in particular tracks a flake you may drop (§5).

---

## 5. Follow-up worth considering

- [ ] **Delete the `niri` input** and use nixpkgs' NixOS + HM niri modules.

  You'd lose the KDE polkit agent, the forced GNOME portal, the duplicate
  nixpkgs, the duplicate stylix injection, and the unused binary cache — and get
  back a clean `nix.conf`. This is the single biggest simplification available,
  and it is what makes §2.2, §4.3 and half of §2.3 go away at once. Do it
  *after* §2.1, not before.

---

## 6. Fresh-install gaps

- [ ] **6.1 Secrets have no bootstrap path, and `lite` doesn't cover it.**
  `sops.age.keyFile` points into `/persist`, and `sys/host:35` dereferences
  `config.sops.secrets."yor-password-hash"` unconditionally — so a fresh install
  that followed the README's own age-key swap can't evaluate or activate without
  the payload present. The README documents the manual procedure, which is the
  right call, but nothing enforces or checks it.

- [ ] **6.2 `secrets.nix:79-88` — the `authorized_keys` template is
  unconditional.** It sits in the `//` arm, so it's defined whenever
  `payloads != {}` regardless of whether `id_ed25519.pub` exists. Rename or
  remove that one payload and you get an opaque eval failure. Every other secret
  is properly gated by `envAvailable`; this one isn't.

- [ ] **6.3 Inconsistent tmpfiles force semantics.** `usrs/default.nix:9-11`
  uses `L` for `setup.symLinks` (correctly refuses to clobber a real dir, but
  silently no-ops with a journal warning) while `usrs/mods/niri:191` uses `L+`
  for the wallpaper. Add a comment in `setup.symLinks` saying the `L` is
  deliberate.

- [ ] **6.4 `/etc/NetworkManager/system-connections` is not in the persistence
  allowlist.** Harmless today *only* because of §1. The moment the root wipe
  lands, every saved WiFi password is lost on reboot. Add it in the same commit
  as §1.

- [ ] **6.5 `fastfetch/default.nix:11,16`.** `nix-light.png` is installed and
  never referenced; the logo `source` is a hardcoded `$HOME` string instead of
  the store path, so the config isn't reproducible.

---

## Appendix: things checked that are fine

Recorded so they don't get re-audited:

- `usrs/mods/eww/config/scripts/*` are `100755` in git and executable in the
  store — `deflisten` works.
- The `theme` script's `$GEN/activate` / `specialisation/light/activate` dance
  works, and `home.programs.niri.package` is correctly `mkForce`d to
  `pkgs.niri` (26.04) by the niri-flake module, so `config.kdl` is validated
  against the binary that actually runs.
- `services.fstrim.enable` is `true` (NixOS default) — TRIM does run.
- `programs.ente-auth` is a real nixpkgs module, not a typo.
- The niri wayland session does reach SDDM, via
  `services.displayManager.sessionPackages` (not `/etc/wayland-sessions`).
- `programs.chromium.enable` genuinely does emit
  `/etc/{chromium,brave,opt/chrome}/policies/managed/*` — the comment in
  `sys/host:51-53` is accurate, and Brave does pick the policies up.
- `impermanence`'s `hideMounts` is still a live option at this pin. (Its
  `method` sibling now throws, but only if you read it — the config's string
  form never does.)
- `nixvim`'s `defaultEditor` and the shell module's `EDITOR = "nvim"` don't
  collide (nixvim uses `mkDefault`).
- Repo is `alejandra`-clean.
