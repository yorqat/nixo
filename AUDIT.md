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

Progress so far: §3.3–§3.6 (the wayland/session pass, 2026-09-30), §2.3/§2.3b,
§2.5–§2.7 and §3.10.
The wayland items were verified against a realised `system-path` (what actually
lands in `/run/current-system/sw`), not just eval — several of the claims in §3
only show up in the built profile or in nixpkgs' source, not in the config:
```sh
nix-store --realise "$(nix-store --query --graph "$DRV" | grep -o '[^ ]*-system-path' | head -1)"
```

Legend: `[ ]` open · `[~]` in progress · `[x]` done. Work top-down; §1 first.

**This file is the progress tracker — keep it true.** Every change to the tree
that touches a finding here must come with an AUDIT.md edit in the same commit:
flip the box, replace the claim with what was actually done, and correct the
finding if the fix contradicted it (several already were). "Done" means the
claim was re-verified against the new eval, not that a line was deleted. When
something breaks at runtime, add a new finding here before debugging it — the
box that lied is usually the cause.

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

- [x] **2.5 `flake.nix:52-55` — "dead `allowUnfree`".** — fixed by deleting the
  cause, not the flag (2026-09-30)

  The claim was half right for the wrong reason. That `pkgs` is a *separate*
  `import`ed nixpkgs used only for `devshell`, so it never set the system
  `allowUnfree` — that comes from `nixosSystem` via `sys/mods/core/nix.nix`. But
  it was not dead: `devshell/default.nix` pulled `pkgs.claude-code`, whose
  `meta.license.free` is `false`, and without `config.allowUnfree` the shell
  refused to even instantiate:

  ```
  error: Refusing to evaluate package 'claude-code-2.1.283' in
  .../pkgs/by-name/cl/claude-code/package.nix:94 because it has an unfree license ('unfree')
  ```

  (Reproduce with `nix build --impure --expr '… import f.inputs.nixpkgs { system = …; } in p.claude-code' --dry-run`.
  Worth knowing: it *evaluates* fine and only throws on instantiation —
  `check-meta.nix` asserts inside `drvPath`, so `nix eval p.claude-code.version`
  is not a test for this and will tell you it is fine.)

  So `claude-code` went first — it was the only unfree thing in the devshell
  (`opencode` is separate and MIT) and had no other reference in the tree — and
  `config.allowUnfree = true` went with it. `pkgs` is now a bare
  `import inputs.nixpkgs { inherit system; }`, which also retired the
  commented-out `legacyPackages` line above it.

  `nix develop -c …` instantiates the whole devshell closure, and the unfree
  check throws at instantiation, so that command succeeding *is* the proof the
  closure is now free — no need to audit licenses one by one. A comment on the
  `pkgs` binding records that a future unfree addition needs the flag back.

  The system-side `nixpkgs.config.allowUnfree` in `sys/mods/core/nix.nix` is
  unrelated and still required (nvidia, plasma-era leftovers, unfree fonts).

- [x] **2.6 `nix.nix` sets defaults to their default values.** — fixed
  (2026-09-30), with one correction

  `allowBroken = false` and `allowInsecure = false` were no-ops — both are the
  upstream default (`pkgs/top-level/config.nix:279`, and `allowInsecure` below
  it) — and are gone. `nixpkgs.config` is now just `allowUnfree = true`.

  **Correction: "`environment.defaultPackages = []` is already the default" is
  wrong.** The option default is `[ perl rsync strace ]`
  (`nixos/modules/config/system-path.nix:53-64`, wired at `:113`); the audit
  read back the *merged* value from this config, which of course is `[]`. So
  that line is load-bearing: it strips all three from `/run/current-system/sw`
  (confirmed — none of them is in the live `/run/current-system/sw/bin`, and
  `environment.systemPackages = corePackages ++ defaultPackages`,
  `system-path.nix:186`).

  Kept as-is with a comment recording that it is a deliberate strip, not a
  no-op. Restoring `[ perl rsync strace ]` is a behaviour change, not a cleanup
  — `strace` in particular is commonly wanted for debugging a config like this
  one, so it is a separate decision.

- [x] **2.7 `nix.settings` unions with module defaults instead of replacing.**
  — fixed (2026-09-30)

  Before / after, from the built `nix.conf`
  (`nix build '.#nixosConfigurations.qat.config.environment.etc."nix/nix.conf".source'`):

  ```
  - trusted-users       = root root yor
  + trusted-users       = root yor
  - substituters        = … https://hyprland.cachix.org …
  + substituters        = … (no hyprland)
  - trusted-public-keys = … niri.cachix.org-1:… … cache.nixos.org-1:… cache.nixos.org-1:… …
  + trusted-public-keys = … niri.cachix.org-1:… (one each)
  - experimental-features =            <- empty, from the option default
  - experimental-features = nix-command flakes
  + experimental-features = nix-command flakes
  ```

  - `trusted-users` now `lib.mkForce [ "root" setup.userName ]`. The default is
    `[ "root" ]` at normal priority (`nixos/modules/config/nix.nix:443`), so the
    old plain list unioned into `root root yor`. Kept `"root"` explicitly
    rather than relying on the default, since `mkForce` is exactly what drops
    the default.
  - Hand-written `niri.cachix.org` substituter + key deleted. niri-flake
    already injects both at normal priority (`niri-flake/flake.nix:480-481`),
    toggled by `niri-flake.cache.enable` (default `true`) — so this also makes
    the cache switchable, which the hand copy made impossible.
  - `hyprland.cachix.org` deleted from both lists. Verified it appears nowhere
    in the tree but these two lines and that no flake input pulls it.
  - `cache.nixos.org-1` deleted from `trusted-public-keys`: the module already
    sets it (`nixos/modules/config/nix.nix:442`). The `?priority=10`
    substituter stays — that is not a duplicate of the `mkAfter` bare
    `https://cache.nixos.org/` (`nix.nix:444`) and the priority is load-bearing.
  - `extraOptions` deleted entirely; `nix.settings.experimental-features` is
    the option now. The option default is `[ ]`
    (`nixos/modules/config/nix.nix:257`) and the `nixConf` formatter renders an
    empty list as a bare `experimental-features =`, which is the stray line —
    setting the option non-empty removes both lines and `extraOptions`.

  The generated file passes its own `checkPhase` (`nix config show` over
  `NIX_CONF_DIR`), so it is a valid `nix.conf`, not just a plausible one.

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
  niri-only box.**

  Fix is `services.xserver.enable = false` plus
  `services.displayManager.sddm.wayland.enable = true`. The X server goes and
  the greeter keeps working, because nixpkgs' sddm module has a first-class
  wayland mode: it sets `DisplayServer = "wayland"`, adds `qt6.qtwayland`, and
  runs a kiosk compositor (`weston --shell=kiosk` by default, `kwin` if
  selected) — `services/display-managers/sddm.nix:67,18,131-146`. Its only
  precondition assertion is `xcfg.enable || cfg.wayland.enable` (sddm.nix:350),
  so X11-off with sddm-wayland is a supported pairing, and the `[X11]` section
  sddm's X path needs is simply not emitted (`optionalAttrs xcfg.enable`).

  Not hypothetical on this machine: the generation logged into on 2026-09-30
  (20:10:52 and 21:54:48) ran `DisplayServer=wayland` with
  `weston-16.0.0 --shell=kiosk` and drew a working login screen on this GPU.

  Unverified: no boot of the rebuilt closure yet, and no closure check that
  `xorg-server`, `xterm`, `xrandr`, `xsetroot`, `xinput`, `xauth` and friends
  are gone from `/run/current-system/sw/bin`.

  **Correction: "programs.xwayland.enable alone suffices" was wrong** — the fix
  needs a greeter that can still draw. The answer is sddm's own wayland mode,
  not a different display manager: nixpkgs refuses to evaluate sddm unless
  `xserver.enable` or `sddm.wayland.enable` is set, and only emits the `[X11]`
  section sddm's X path needs under `optionalAttrs xcfg.enable`.

  #### Correction: the greetd + tuigreet detour (2026-09-30), closed out

  An earlier pass also replaced sddm with `services.greetd` + `tuigreet`,
  reasoning that any greeter which brings a DRM compositor up on proprietary
  nvidia at boot is a risk worth removing. Wrong trade: it built, but the only
  boot of that generation (2026-09-30 21:53) hung during early boot before
  `greetd.service` ever started, so no greeter was drawn and tuigreet has never
  been observed working on this machine. The reasoning is recoverable from
  `git stash list` (entry `greetd+tuigreet experiment`) if it is ever wanted
  again; do not retry it before sddm's wayland mode has booted and been
  confirmed.

  `services.xserver.xkb` dies with the module, so the layout moves to where it
  is actually read: `usrs/mods/niri` sets
  `input.keyboard.xkb = { layout = "us"; variant = ""; }` and the generated
  `config.kdl` carries it. niri never consulted `/etc/X11/xkb`, and xkbcommon is
  compiled with `-Dxkb-config-root=${xkeyboardconfig}/etc/X11/xkb`, so dropping
  the module cannot break keymap data. Nothing reads the system xkb layout
  afterwards: niri takes it from `config.kdl`.

- [x] **3.4 `sys/mods/wayland:13,20-23` — compositor env for a different
  compositor.** — fixed (2026-09-30)

  All of `WLR_BACKEND`, `WLR_NO_HARDWARE_CURSORS`, `WLR_DRM_NO_ATOMIC`,
  `NIXOS_OZONE_WL`, `CLUTTER_BACKEND` are gone, plus the two leftovers the
  finding only mentioned in passing: `ANKI_WAYLAND` (no anki anywhere) and
  `DIRENV_LOG_FORMAT = ""`. `environment.variables` is now two entries.

  Three more went with them, all verified redundant rather than assumed:

  - `XDG_SESSION_TYPE = "wayland"` — set by niri itself (`src/main.rs:96`) *and*
    by sddm for every session it used to start (`Display.cpp:440`,
    `session.xdgSessionType()` from the session dir). System-wide it was a lie in
    the other direction too: `environment.variables` lands in
    `/etc/set-environment`, which systemd-logind imports for **tty and SSH
    logins too**, and logind derives a session's `Type` from exactly that
    variable. (Verified: the var is in `/etc/set-environment` and the running
    graphical session reports `Type=wayland`.)
  - `DISABLE_QT5_COMPAT = "0"` — a no-op by construction; Qt only reads it to
    *disable* the wayland platform, and "0" is the default.
  - (`pkgs` is now an unused module arg in that file, like it already was.)

  Kept: `MOZ_ENABLE_WAYLAND` (firefox would otherwise run under Xwayland) and
  `QT_WAYLAND_DISABLE_WINDOWDECORATION` (matches `prefer-no-csd` in the niri
  config).

- [x] **3.5 `sys/mods/wayland:15` — `QT_QPA_PLATFORM = "wayland"`
  system-wide.** — fixed (2026-09-30)

  Deleted outright, not moved to the session: Qt 6 picks the wayland platform
  from `WAYLAND_DISPLAY` on its own, and the way to override a single app is its
  own wrapper, not a global. Nothing in the tree is a Qt app that needs forcing
  (kitty, swaybg, swaylock, mako, fuzzel, eww, nautilus, pavucontrol, brave and
  signal are all native-Wayland or GTK; `libreoffice-fresh` is opt-in and off).
  The xcb-only-tool breakage the finding warned about is gone with it.

  Consequence to know: a Qt**5** app (or one still asking for xcb) now runs under
  Xwayland rather than failing. Xwayland is still enabled, so that is a
  regression in rendering path, not in function. The greeter is not affected:
  `sddm-greeter-qt6` already runs inside weston under `sddm.wayland.enable`, so
  Qt6 picks its wayland platform plugin without the env var.

- [x] **3.6 `sys/mods/nvidia:16-21` — the textbook NVIDIA env anti-pattern.**
  — fixed (2026-09-30)

  `environment.variables` is gone from the module; the per-process
  `nvidia-offload` wrapper (which still sets `__GLX_VENDOR_LIBRARY_NAME` etc. for
  the one process that wants them) is the only place those names appear now.

  - `GBM_BACKEND = "nvidia-drm"` — a **Mesa** knob (which backend Mesa's GBM
    should load). niri goes through libgbm + EGL directly and never reads it, and
    apps that want NVIDIA go through the wrapper. Removed. Same for weston: it
    also talks to EGL/GLVND directly, so the `GBM_BACKEND=nvidia-drm` advice you
    find in sddm bug reports (sddm#1819) is not what made those greeters work.
  - `__GLX_VENDOR_LIBRARY_NAME = "nvidia"` — GLX-only, so under Wayland it never
    touched the EGL clients every app here actually uses; it only forced X11/GLX
    clients onto NVIDIA. Removed per §3.5's reasoning. **Effect:** an X11 GL app
    now gets Mesa instead of the dGPU unless offloaded (`nvidia-offload`).
    Nothing in the tree is one; revisit if Steam games come back on.
  - `__GL_GSYNC_ALLOWED` / `__GL_VRR_ALLOWED` — amdgpu knobs, inert on a
    glvnd/NVIDIA GLX path. Removed.

  **Correction: "`nvidia-x11` is in the profile for no reason" is wrong.** It
  arrives through `hardware.graphics.extraPackages` when `hardware.nvidia.open =
  true` (`hardware/video/nvidia.nix:503`) and is what installs the GLVND/EGL
  vendor files niri's clients need. Verified still in the new closure
  (`nvidia-x11-595.104.02`), independent of §3.3.

  **And `services.xserver.videoDrivers = ["nvidia"]` must stay.** It looks dead
  now that the X server is gone, but `hardware.nvidia.enabled` is `readOnly` and
  defaults to `"nvidia" ∈ services.xserver.videoDrivers`
  (`hardware/video/nvidia.nix:8`) — that list *is* the switch. Commented it out
  and the whole driver module silently evaluates off
  (`hardware.nvidia.enabled` → `false`: no modesetting, no ld paths, no ICDs),
  with no assertion and no warning. It is now commented in the module.

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

- [x] **3.10 `sys/host:13-25` — two locale intents fighting.** — fixed
  (2026-09-30), settled on `en_PH.UTF-8`

  The `i18n.extraLocaleSettings` block and `setup.extraLocale` are gone; one
  locale now. `setup.defaultLocale` stays `en_PH.UTF-8` and the generated
  `/etc/locale.conf` is one line:

  ```
  LANG=en_PH.UTF-8
  ```

  All nine `LC_*` were the same string, so they only ever restated `LANG` for
  those categories while overriding it for the language.

  **Correction: the finding's gloss on both locales was wrong, and backwards.**
  Measured on this machine:

  |                        | `en_PH.UTF-8`                    | `fil_PH.UTF-8`              |
  | ---------------------- | ------------------------------- | --------------------------- |
  | `date +%c`             | `Wednesday, 30 September, 2026 10:55:00 PM` | `Miy 30 Set 2026 10:55:00 N.H.` |
  | `date +%x`             | `Wednesday, 30 September, 2026` | `09/30/26` (**US order**)    |
  | AM/PM                  | `PM`                            | `N.H.`                      |
  | `currency_symbol`      | `₱`                             | `₱`                         |
  | `printf "%'d" 1234567` | `1,234,567`                     | `1,234,567`                 |

  So `en_PH` is *not* "US conventions" — it is day-first with long month names
  and PHP, i.e. the PH convention you actually want. And `fil_PH` is the one
  with US-order numeric dates. They disagree on date order, which is why this
  was worth fixing rather than shrugging at: the old config gave you
  `en_PH`'s language with `fil_PH`'s date formats.

  The pre-fix state was the worst of both, confirmed from the live system
  (`localectl status`): `LANG=en_PH.UTF-8` with all nine `LC_*=fil_PH`, and
  since `LC_TIME`/`LC_NUMERIC` win over `LANG`, `date +%c` printed
  `Miy 30 Set 2026 10:55:00 N.H.`.

  **Not a pure no-op — two things change on rebuild.** `i18n.supportedLocales`
  is derived from `defaultLocale` + `extraLocaleSettings`
  (`nixos/modules/config/i18n.nix:20-30`), so `fil_PH/*` leaves it and
  `glibcLocales` rebuilds: `["C.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" "en_PH.UTF-8/UTF-8"]`,
  archive contains `en_PH.utf8` + `en_US.utf8` and no `fil_PH` (verified with
  `strings` on the new `locale-archive`). And the formats change as tabled
  above. Nothing else in the tree references `fil_PH`.

  Verified the surviving locale against the new archive directly — note the
  mechanism is `systemd.globalEnvironment.LOCALE_ARCHIVE`
  (`i18n.nix:212`), not `LOCPATH`; setting `LOCPATH` makes glibc fall back to
  `C` and silently looks like the locale is broken:

  ```sh
  LOCALE_ARCHIVE="$(nix eval --raw .#nixosConfigurations.qat.config.i18n.glibcLocales \
    --apply 'p: p + "/lib/locale/locale-archive"')"
  LOC_ALL=en_PH.UTF-8 date +"%c | %x | %r"
  # Wednesday, 30 September, 2026 11:02:12 PM | Wednesday, 30 September, 2026 | 11:02:12 PM PST
  LOC_ALL=en_PH.UTF-8 locale -k LC_MONETARY | grep currency_symbol   # ₱
  ```

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

- [ ] **4.13 Hardcoded `trusted-public-keys` / `substituters` will rot.**
  `nixpkgs-wayland.cachix.org` and `nix-community.cachix.org` are pinned here
  for flake inputs that may not survive §5. (The niri key and
  `hyprland.cachix.org` used to be in this list too; §2.7 dropped the first as
  a duplicate of what niri-flake injects, and the second as a flake that is not
  in the tree.)

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
- The niri wayland session reaches the display manager via the generated
  `niri.desktop` (`Exec=niri-session`) in
  `${services.displayManager.sessionData.desktops}/share/wayland-sessions`, which
  is where sddm's `Wayland.SessionDir` points (`sddm.nix:92`) and keeps pointing
  under `sddm.wayland.enable`. The session itself is unchanged by §3.3.
- `programs.chromium.enable` genuinely does emit
  `/etc/{chromium,brave,opt/chrome}/policies/managed/*` — the comment in
  `sys/host:51-53` is accurate, and Brave does pick the policies up.
- `impermanence`'s `hideMounts` is still a live option at this pin. (Its
  `method` sibling now throws, but only if you read it — the config's string
  form never does.)
- `nixvim`'s `defaultEditor` and the shell module's `EDITOR = "nvim"` don't
  collide (nixvim uses `mkDefault`).
- Repo is `alejandra`-clean.
