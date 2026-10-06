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
§2.5–§2.7 and §3.10, then §2.1 + §2.2 + §5 (the `niri-flake` removal,
2026-10-01), then §3.3 (X server off / sddm wayland, 2026-10-01).
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

  **Re-verified 2026-10-06: still open, and the contradiction is now sharper.**
  A grep for `wipe|rotate|set-default|subvolume create|tmpfs\.` across every
  `.nix`/`.sh` in the tree hits only comments and one `neededForBoot` — there is
  still no `tmpfs.root`, no `postResumeCommands`, no clean rule. The only
  tmpfiles rules are secret-dir creation (`secrets.nix:34-37`), the wallpaper
  symlink (`niri/default.nix:271`) and `setup.symLinks` (`usrs/default.nix:38`);
  none wipes.

  Fresh live proof, since the item was filed: `/proc/self/mounts` shows
  `/dev/nvme0n1p6 / btrfs … subvol=/@` mounted **rw**, and
  `/etc/ssh/ssh_host_ed25519_key` is dated **2026-09-13** while `uptime -s` says
  **2026-10-06 09:21** — the key outlived a reboot. The `@persist` bind mounts
  are all live (`/home`, `/var/log`, `/etc/machine-id`,
  `/var/lib/sops-nix/key.txt` each `subvol=/@persist`), but with root
  non-ephemeral those writes land on `[@]` anyway, so the allowlist at
  `persistence.nix:5-24` buys nothing today. It is not dead code, though — it
  pre-stages phase 3/4.

  The documentation conflict has also moved: `sys/mods/core/persistence.nix:2`
  now flatly says "root is blank at boot", `README.md` at `:11` and `:53`, and
  `AGENTS.md:50` all repeat it. Three of those are wrong today, and §6.4's
  NetworkManager consequence is no longer hypothetical under that wording.

---

## 2. Contradictions inside the config

- [x] **2.1 The uncommitted working-tree change is self-defeating.** — fixed
  (2026-10-01), but by deleting the thing rather than restoring `follows`

  ```diff
  -      inputs.nixpkgs.follows = "nixpkgs";
  +      # inputs.nixpkgs.follows = "nixpkgs";
  +    package = pkgs.niri;      # sys/host/default.nix:48
  ```

  The diagnosis was right (`package = pkgs.niri` already pinned the binary, and
  commenting out `follows` only added a second nixpkgs to the lock), but the
  prescribed fix — keep `follows` — was about to become moot. The `niri` input
  is now **gone entirely**, so there is no `follows` to keep: the diff above no
  longer exists in any form.

  The stale nixpkgs is gone from the lock as a side effect. `b4fd65b1` (the
  niri-flake-flavoured nixpkgs) appears **nowhere** in `flake.lock`, and the lock
  went from 4 nixpkgs nodes to 3. The nodes were renumbered by the regeneration
  (`nixpkgs_2` → `nixpkgs`), but no root nixpkgs rev moved: root is still
  `7a0f122f`, and so is the second node.

  See §2.2 for what replaced the flake and §5 for the follow-up this retired.

- [x] **2.2 `niri-flake` earns almost nothing and costs a lot.** — fixed
  (2026-10-01), by deleting the input

  Every bullet in the original finding held up. Each was re-checked against the
  build *after* removal, not against the new config's source:

  - **KDE polkit agent: gone.** Closure diff against `/run/current-system`
    removed `polkit-kde-agent-1-6.7.5`, `polkit-qt-1`, `kwidgetsaddons`,
    `kcoreaddons`, `kcrash`, `kdbusaddons`, `karchive`, `kconfig`,
    `kcolorscheme`, `kirigami`, `kiconthemes`, `ki18n`, `knotifications`,
    `qqc2-desktop-style`, `sonnet`, plus `qt5compat`, `qtshadertools`,
    `aspell` and `hunspell` — the agent was dragging a Qt5 stack in behind it.
    Replaced with `polkit-gnome-0.105`, one package.
  - **Forces `xdg-desktop-portal-gnome`: still true, just from someone else.**
    niri-flake did this; nixpkgs' module does too, and *recommends* it
    (`nixpkgs/nixos/modules/programs/wayland/niri.nix:77-79`, citing niri's own
    wiki) — so it stays in `xdg.portal.extraPortals` and this is not a saving.
    **Correction to the finding:** it framed the forced portal as something the
    removal would win back. It doesn't; the GNOME portal is upstream's intended
    niri setup. What the removal *did* add is `xdg-desktop-portal-gtk-1.15.3`:
    `wayland-session.nix:23` appends it when `enableGtkPortal` is on (default
    `true`), and `niri.nix:83-86` imports `wayland-session.nix` passing only
    `enableWlrPortal = false; enableXWayland = false`. That is net **+1** package,
    and it backs a config file that is byte-identical to the one niri-flake
    installed via `configPackages = [ cfg.package ]`
    (`niri-flake/flake.nix:563`): both say
    `default=gnome;gtk`, `Access=gtk`, `Notification=gtk`, `Secret=gnome-keyring`.
    Nixpkgs writes it to `/etc/xdg/xdg-desktop-portal/niri-portals.conf`
    instead of taking it from niri's `share/`, so behaviour is unchanged and the
    `gtk` side now actually has a package behind it.
  - **Disables nixpkgs' niri module: no longer true, and that's the point.**
    `niri-flake/flake.nix:462` had `disabledModules = [
    "programs/wayland/niri.nix" ]`. With the flake gone the module is active,
    which is visible in the build: `/etc/systemd/user/niri.service.d/overrides.conf`
    (`X-RestartIfChanged=false`, `enableDefaultPath=false`) and
    `/etc/xdg/xdg-desktop-portal/niri-portals.conf` now exist, and neither did
    before. Both are `mkDefault`-level upstream, so the config did not need
    changing — but this is the concrete proof the module is now doing the work.
  - **`home-manager.sharedModules` 30 → 27**, i.e. the ~28 duplicate stylix
    injections are gone, leaving one per distinct HM file.
  - **The binary cache is gone and so is the hand-copied key.** The built
    `/etc/nix/nix.conf` no longer lists `niri.cachix.org` in either
    `substituters` or `trusted-public-keys`.

  What was *not* free, and had to be done by hand:

  - **stylix has no niri target** (`stylix-module = call ./stylix.nix` in
    niri-flake, `flake.nix:44`, `533`). The cursor, focus-ring and border
    colours are now written out explicitly in `usrs/mods/niri/default.nix`
    against `config.stylix`/`config.lib.stylix`. The generated `config.kdl` was
    diffed against the old one line by line and against niri 26.04's own
    `resources/default-config.kdl` to confirm nothing silently reverted to a
    default the flake had been setting.
  - **HM's KDL renderer is stricter than KDL.** Three configs evaluated fine but
    produced a file `niri` rejected, all now fixed and covered by
    `checkConfig`: `binds."Mod+Q".close-window = {}` emits the bare
    `Mod+Q close-window` (KDL v2 forbids an identifier as an argument — niri
    wanted `Mod+Q { close-window }`), `on = true` emits `on true`, and
    `quit."skip-confirmation" = true` emits a nested `quit { … }` node. `on` has
    to be an empty attrset and the skip-confirmation flag needs `_props`.
  - **`xwayland-satellite` came back out of `home.packages`.** The HM module
    adds it itself (`xwaylandSatellitePackage` default) — verified in the built
    `home-path`: `xwayland-satellite` is on `PATH` without the explicit entry.
  - **Two `polkit.service`-ish units would have collided.** nixpkgs'
    `wayland-session.nix:11` sets `security.polkit.enable = true`, so the
    polkit *system* unit is still there — only the *agent* was niri-flake's.
    `niri-flake-polkit.service` is gone; `polkit-gnome-authentication-agent.service`
    is a **user** unit, installed into
    `~/.config/systemd/user/` and symlinked into
    `graphical-session.target.wants/`, so it cannot shadow it.
  - **One new unit appeared that nothing predicted:**
    `xdg-autostart-if-no-desktop-manager.target`, from
    `wayland-session.nix:27-29` (`runXdgAutostartIfNone = mkDefault true`,
    described in `services/x11/desktop-managers/none.nix:17-26` as what
    window-manager-only sessions need). Benign here — niri's own unit already
    carries `Wants=xdg-desktop-autostart.target` and `Before=
    xdg-desktop-autostart.target`, so autostart ran before too — but it is a
    behaviour delta the §5 prediction did not mention, recorded so nobody
    re-discovers it in a future diff.

  The full system builds. `nix build
  .#nixosConfigurations.qat.config.system.build.toplevel` → 40 derivations,
  2 fetches (218 KiB), and `home.programs.niri.package` is still `pkgs.niri`
  (26.04) so `config.kdl` is validated by `checkConfig` against the binary that
  actually runs. Both `sys` and HM sides resolve to the same
  `/nix/store/14fnag7q2i1q18nqi56ggqgbd1cl0c3g-niri-26.04`.

  **Behaviour change, deliberate:** the `input.keyboard.xkb` block is gone from
  the generated config (verified absent), so niri now takes its keymap from
  systemd-localed instead (`us`, `pc104`, `terminate:ctrl_alt_bksp` — the values
  in `00-keyboard.conf`) rather than from `config.kdl`. Worth one manual login
  check.

  **Corrected 2026-10-06, see §4.14.** Two claims in the note as first written
  were wrong. niri does not "read the locale" — it reads localed's `X11Layout`
  over D-Bus, and the locale is not an input to keymap selection at all. And the
  block was not "the flake writing out niri's own defaults": §3.3 had put a real
  layout statement there, `input.keyboard.xkb = { layout = "us"; variant = ""; }`
  (`AUDIT.md` at `6cbbf8f^:312`). Removing it is what left the keymap undeclared
  in the tree, which §4.14's fix puts back.

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

  Not orphans, deliberately left alone: the GNOME portal and `ente-auth`'s
  gnome-keyring. The original note said both were "§2.2 fallout, fixed by
  dropping niri-flake" — that was half right and has been corrected after the
  drop (§2.2). niri-flake did not set either of these; nixpkgs' own niri module
  does, at `mkDefault`:
  - `xdg.portal.extraPortals = [ xdg-desktop-portal-gnome ]` —
    `nixpkgs/nixos/modules/programs/wayland/niri.nix:77-79`
  - `gnome.gnome-keyring.enable = mkDefault true` — `niri.nix:46`, "recommended
    by upstream", and genuinely load-bearing here because `Secret` is routed to
    gnome-keyring in the portal config the same module writes

  So the lines stay gone from `sys/host` (redundant), but the dependencies they
  were keeping alive are now kept alive by the module instead. Verified live:
  `services.gnome.gnome-keyring.enable = true` and `xdg.portal.extraPortals = [
  gnome-keyring xdg-desktop-portal-gnome xdg-desktop-portal-gtk ]`.

- [ ] **2.4 `lite` doesn't gate the machine-specific stuff it claims to.** —
  re-verified 2026-10-06, still open; the NVIDIA env block drifted from
  `:13-18` to `:14-19`.

  `usrs/mods/apps/opencode/default.nix:14-17` still hardcodes
  `__NV_PRIME_RENDER_OFFLOAD`, `__NV_PRIME_RENDER_OFFLOAD_PROVIDER="NVIDIA-G0"`,
  `__GLX_VENDOR_LIBRARY_NAME="nvidia"`, `__VK_LAYER_NV_optimus="NVIDIA_only"`,
  plus `LD_LIBRARY_PATH = "/run/opengl-driver/…"` at `:19`, with no guard. Worse
  than the finding said: the module's args are `{pkgs, ...}` (`:1`), so `setup`
  is not even in scope, and it is imported unconditionally
  (`usrs/default.nix:27`) — a guard would have to be added, not just moved.

  Every premise still holds: `lite = false` (`setup/default.nix:11`),
  `includes.nvidia = !lite` (`:72`), and the real gate is the conditional
  import `++ lib.optional setup.includes.nvidia ./mods/nvidia`
  (`sys/default.nix:70`). So `lite = true` really does start ollama with NVIDIA
  offload env and no driver.

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
    **Updated by §2.2 (2026-10-01):** the flake is gone, so the injected key
    went with it and there is nothing left to be switchable. The
    `niri.cachix.org` entry is absent from both lists in the built `nix.conf`,
    and the comment in `sys/mods/core/nix.nix` that credited niri-flake for it
    has been replaced with a note saying there is nothing to pin.
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

- [x] **2.8 `usrs/default.nix:57 programs.home-manager.enable = true` is a no-op.** — fixed (2026-10-01)

  HM's own module gates its body on `!config.submoduleSupport.enable` (HM
  `modules/programs/home-manager.nix:41`). When running HM as a NixOS submodule,
  NixOS sets `submoduleSupport.enable = true` and `externalPackageInstall =
  useUserPackages` (HM `nixos/common.nix:50-53`); that makes the guard false, so
  the option never installs the `home-manager` package. Verified empirically: in
  this config `submoduleSupport.enable` is true, and `home.packages` contains
  no `home-manager` binary even while `programs.home-manager.enable = true` was
  present.

  The line was not just a no-op but actively misleading: it reads as if it
  bootstraps HM, when in reality HM is wired up via `home-manager.users."${setup.userName}"`
  in `sys/default.nix:47-60`. Removed it and added an explicit comment there
  explaining why. No behaviour change (the toplevel derivation hash remained
  identical).

- [ ] **2.9 `setup/default.nix:35` points at `migrate-cred.sh`,** which no
  longer exists. — re-verified 2026-10-06; the line number drifted (original
  cited `:20`), and that comment is the only mention outside this audit.

  The lone hit: `setup/default.nix:35` `# secrets are managed by sops-nix, not
  symlinks (see migrate-cred.sh)`. No `migrate-cred*` anywhere in the repo; git
  history shows `4d08de3` purged legacy scripts, but that reference survived.
  Harmless, but it is still wrong.

---

## 3. Anti-patterns

Security / correctness first.

- [x] **3.1 `network.nix:5-31` + `sys/host/default.nix:135-142` — sshd on all
  interfaces with no firewall.** — fixed (2026-10-01, verified live 11:25)

  (Line refs point at the fix as it now stands: `firewall.enable = false` used
  to be `network.nix:3`, and the sshd block is
  `services.openssh.settings` at `sys/host/default.nix:135-142`.)

  `firewall.enable` is now `true`, plus `nftables.enable = true` — without that
  second line nixpkgs keeps using the legacy iptables backend
  (`firewall.nix:89-95`: the `default` for `security.backend` is `nftables`
  only `if config.networking.nftables.enable`, else `iptables`), and the
  `inet`-family ruleset never gets built.

  Verified two ways — first the generated rules, then the **live** ones via
  `sudo nft list ruleset`. The input chain, verbatim from the running system:

  ```
  type filter hook input priority filter; policy drop;
  tcp dport 22 accept
  udp dport 5353 accept
  iifname "eno1" tcp dport { 4173-4180, 5173-5180, 6600 } accept
  meta l4proto . th dport @temp-ports accept
  ip6 daddr fe80::/64 udp dport 546 accept comment "DHCPv6 client"
  ```

  Alongside those: `iifname { "lo" } accept`, a conntrack
  `established/related` fast path, ping/ICMPv6 accepts, and DHCPv4. There is
  also a separate `rpfilter` chain (prerouting, mangle priority) that
  `nftables` always emits.

  **Where the ruleset actually lives.** `networking.nftables.rulesetFile` is
  `null` here, so there is **no `/etc/nftables.rules`**. The ruleset is a store
  script that `nftables.service` pipes to `nft -f`, referenced from its
  `ExecStart=` — read the unit's `ExecStart` path and `cat` it. (Getting this
  wrong is what made an already-live firewall look absent for several rebuild
  cycles; see 3.11's note below about trusting the artifact over a guess.)

  **`AllowUsers` and `MaxAuthTries` were considered and deliberately not added.**
  sshd is already key-only — the explicit settings are only
  `PasswordAuthentication false`, `KbdInteractiveAuthentication false`,
  `PermitRootLogin "no"` (`sys/host/default.nix:138-140`), and
  `X11Forwarding false` comes from the nixpkgs default rather than this config
  (all four confirmed by evaluating `services.openssh.settings`). The one path
  in is the sops-deployed `authorized_keys`
  (`SHA256:sUpHbK/mpkTsEn6Th7ExrU2GCLCp9ggBhwjxjdDLTUY`), confirmed working.
  `AllowUsers yor` would also be a mild footgun, since a future service account
  would need adding to the list.

  **Ports, and why each is open.** Enumerated from `ss -tulpn` before writing
  the rule:

  - `22` global — ssh, the only remotely used service.
  - `5353/udp` global — mDNS. `services.avahi.nssmdns4`/`nssmdns6`
    (`sys/host/default.nix:132-140`) buy `.local` resolution. The IP is
    DHCP-assigned and can move. Note it was **only half working** before
    3.11's fix — see the correction below.
  - `6600` (mpd) and `4173-4180` / `5173-5180` (vite/svelte dev + preview)
    scoped to `eno1` only. Vite dev servers have a history of
    arbitrary-file-read CVEs, so `iifname` keeps them off wifi/USB-tether even
    while open. nft collapses all three into one rule.

  These are static: they are open whenever the system is up, not when a dev
  server happens to bind. NixOS has no "open this port when a process listens"
  hook; the alternatives are `nix run nixos-firewall` or a manual `nft add
  rule` wrapper, neither of which is worth it for a LAN-scoped dev port.

  **`5355` (avahi's LLMNR) is now closed**, which is a free win: it was
  listening on tcp+udp on `0.0.0.0` and is legacy name resolution nothing on
  the LAN uses. Only `openFirewall`'s 5353 was ever contributed, so the
  default-drop simply excludes it.

  Loopback-only listeners (ollama 11434, opencode 4096, systemd-resolved 53)
  are unaffected either way; mpd was the one that genuinely needed an explicit
  rule to become reachable from a phone.

  **Correction to an earlier version of this entry: `ssh qat.local` did not
  work.** It was claimed here as the payoff for keeping 5353 open, and that was
  not true. The cause was `nssmdns6 = true` without `nssmdns4`: nixpkgs derives
  the nss database name from those two booleans (`avahi-daemon.nix:334-339`),
  so IPv6-only yields `mdns6_minimal`, which answers AAAA only. `ssh` resolves
  `AF_UNSPEC` and tries A first, gets NOTFOUND, and the `[NOTFOUND=return]`
  guard terminates the chain *before* `resolve` — so the stub never gets asked:

  ```
  hosts:  mymachines mdns6_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns
  ```

  `getent hosts qat.local` worked, which is what made it look fine; `ssh` and
  `ping` both failed with `Name or service not known`. Fixed in 3.11 by also
  setting `nssmdns4 = true`, which yields `mdns_minimal` (handles A and AAAA).
  Verified in the built `nsswitch.conf`. Worth remembering that a resolvable
  name in one tool and not another is an nss-ordering symptom, not flakiness.

  **Residual risk, unrelated to the firewall:** remote access depends on
  `/run/secrets/rendered/authorized_keys`, i.e. on age decryption succeeding at
  boot. If it fails, `authorized_keys` dangles, pubkey auth dies, and there is
  no password fallback. Worth a second key as a backstop.

- [ ] **3.2 privilege groups for nothing.** — re-verified 2026-10-06: **two of
  the three are now defensible, one is not.** Ref corrected (`sys/host:21`).

  `sys/host/default.nix:21` still grants `"kvm" "libvirtd" "docker"`, but the
  reasoning behind two of them has since been supplied:

  - `libvirtd` — `virtualisation.libvirtd.enable` is no longer hardcoded `false`;
    it is now `setup.includes.virt-manager` (`sys/host/default.nix:96-98`) and
    `pkgs.virt-manager` rides the same flag (`:8`, `:193`). Still `false` today
    (`setup/default.nix:76`), so the group is granted ahead of a flag that
    exists — defensible as a pair, wrong as an unconditional grant.
  - `kvm` — `boot.kernelModules = ["kvm-amd"]` (`hardware-configuration.nix:17`)
    and the module is loaded live (`/proc/modules`). Caveat: `/dev/kvm` does not
    exist on this machine, so nothing can actually use the group yet.
  - `docker` — **still dead.** No `docker` or `podman` package anywhere in the
    tree, and the group is root-equivalent. This is the one to drop.

- [x] **3.3 `sys/host:113-120` — `services.xserver.enable = true` on a
  niri-only box.** — fixed (2026-10-01)

  ```nix
  xserver.enable = false;
  displayManager = { sddm.enable = true; sddm.wayland.enable = true; };
  ```

  **The greeter half of this was decided and validated months before the
  finding was written, then lost.** Boot `-5` (2026-09-30 21:54:43) journal has
  `sddm-helper-start-wayland` starting `weston 16.0.0 --shell=kiosk` on the
  `drm-backend` with `gl-renderer`, and a successful login at 21:54:48 — so sddm
  wayland mode was not a proposal, it was observed working on this GPU.

  It then went missing without anyone noticing, and the cause is worth
  recording because it is the same failure mode as the `flake.lock` gotcha in
  `AGENTS.md`: **the change was never committed.**
  `git log -S "wayland.enable" --all -- sys/host/default.nix` returns only
  `24f053b initial`, and that match is `programs.xwayland.enable`, a different
  option. `0193a0b` (23:03, two hours after that boot) did cut 12 lines from
  `sys/host`, but they were `i18n.extraLocaleSettings`, not the sddm line —
  so nothing deleted it either. It lived only in the working tree across the
  greetd revert and was cleaned away. The working tree was clean by the next
  session, so there was no diff to notice.

  **These two lines are one atomic change, not two options.** `sddm.nix:349-352`
  asserts `xcfg.enable || cfg.wayland.enable` with the message "SDDM requires
  either services.xserver.enable or services.displayManager.sddm.wayland.enable
  to be true", so dropping the X server without the wayland greeter does not
  evaluate. There are only two valid end states — X11 + sddm-x11, or X-off +
  sddm-wayland — and the second was already the intent.

  Verified against a full build of the new generation
  (`/nix/store/khkmzhzxxa18axkkykbaask2hp3ay7bv-…`):

  - All seven binaries this finding listed are **gone** from
    `/run/current-system/sw/bin`: `Xorg`, `Xephyr`, `xterm`, `xrandr`,
    `xsetroot`, `xinput`, `xauth`. This closes the "unverified" sub-item the
    original finding left open — and it is the only reason to do the change.
  - Built `/etc/sddm.conf.d/00-nixos.conf` now carries `DisplayServer=wayland`
    and the entire `[X11]` section is gone (`ServerPath`, `XauthPath`,
    `XephyrPath`, `SessionCommand` all absent — `sddm.nix` gates them on
    `optionalAttrs xcfg.enable`). `[Wayland] CompositorCommand` is
    **byte-identical** to the string that worked in boot `-5`, same weston and
    same `weston.ini` store paths.
  - `niri.desktop` is unchanged: the `desktops` derivation is still
    `972s3nx1yf9vnx7c048z7xic4pv03jif`, the same store path as before, and
    `SessionDir` still points into it.
  - `programs.xwayland.enable = true` is unaffected (`xwayland.nix:44-49` only
    adds `cfg.package`; there is no coupling to `services.xserver`), and
    `xwayland-satellite` is still in the closure. **X apps still work** — this
    removes the X *server*, not Xwayland.
  - `services.xserver.videoDrivers = [ "nvidia" ]`
    (`sys/mods/nvidia/default.nix:33`) still evaluates and is now **inert**:
    nothing reads it without an X server. NVIDIA's Wayland support comes from
    the kernel module and `hardware.nvidia`, not from this option. Left in
    place; see §4.15.
  - The HM side is untouched: the generated `config.kdl` still carries
    `Qogir-Light` at size 24 and the `base0D`/`base03` border plus the
    `base0D`-family focus-ring gradients, so stylix theming did not regress.
  - `services.xserver.xkb` still evaluates with the module disabled and still
    writes nothing **into `environment.etc`** — unchanged. It keeps feeding
    `00-keyboard.conf` either way, so the keymap never depended on the gate;
    see §4.14.

  **Cost, for the record:** weston's dependency tree is not small. Closure went
  2119 → 2105 paths (**-14 net**), but that is ~26 X11 paths out and ~20 in,
  including `freerdp`, `neatvnc`, `sdl3`, `ffmpeg` and `lua` (weston's RDP/VNC
  clients and DRM-backend video decoders). The win is dropping the X server, not
  the path count.

  **Correction to the finding's framing:** it presented the wayland greeter as an
  open prerequisite — "the fix needs a greeter that can still draw". That
  prerequisite was already satisfied and demonstrated. What was actually
  outstanding was re-applying an edit that had been lost, which is why this read
  as untouched work rather than a forgotten decision.

  **Correction: "programs.xwayland.enable alone suffices" was wrong** — see the
  assertion above; it is not sufficient and does not evaluate.

  #### Correction: the greetd + tuigreet detour (2026-09-30), closed out

  An earlier pass also replaced sddm with `services.greetd` + `tuigreet`,
  reasoning that any greeter which brings a DRM compositor up on proprietary
  nvidia at boot is a risk worth removing. Wrong trade: boot `-6`
  (2026-09-30 21:53:37) lasted **6 seconds** and hung during early boot before
  `greetd.service` ever started, so no greeter was drawn and tuigreet has never
  been observed working on this machine. Boot `-5`, 90 seconds later, was sddm
  in wayland mode working — which is the better answer and is now what the tree
  says.

  **The stash holding the greetd experiment was dropped on 2026-10-01**, so any
  pointer to `git stash list` for it is dead. The commit is still reachable in
  the reflog for a while as `112a750` (touched `sys/host`, `sys/mods/nvidia`,
  `sys/mods/wayland`, `usrs/mods/niri`; +67/−29), but treat it as gone. The
  question it raised is now answered: sddm's wayland mode does bring up a DRM
  compositor on proprietary nvidia here, so there was no need to replace sddm.

  #### Correction: the xkb reasoning here was invalidated by §2.2 (2026-10-01)

  This finding used to end by claiming `services.xserver.xkb` "dies with the
  module", so the layout had to move into `usrs/mods/niri`. Half of that was
  never true. `services.xserver.xkb` does **not** die with the module, and in
  this config it writes nothing **into `environment.etc`**, module or not:

  - `/etc/X11/xkb` is emitted only under `optionalAttrs cfg.exportConfiguration`
    (`nixos/modules/services/x11/xserver.nix:896-900`), and
    `services.xserver.exportConfiguration` defaults to **`false`**
    (`xserver.nix:383-385`) and is never set here. Verified: the built `etc`
    derivation has `X11/xorg.conf.d/` but no `X11/xkb`, and there is no
    `/etc/X11/xkb` on the running system.
  - ~~So the layout niri actually used was the one niri-flake wrote into
    `config.kdl`, and `services.xserver.xkb` was dead weight.~~
    **Corrected 2026-10-06, §4.14: not dead weight.** It feeds `weston.ini`
    (the greeter) and `00-keyboard.conf` (niri, via systemd-localed).
  - ~~§2.2 then removed that `config.kdl` block too (it was niri's own default,
    not configuration). niri now resolves its layout from the locale chain —
    `/etc/locale.conf` (`LANG=en_PH.UTF-8`) → `systemd-localed` → `us`.~~
    **Corrected 2026-10-06, §4.14: the block was a real layout statement, and
    the chain has no `LANG` in it.** The route is `00-keyboard.conf` →
    `systemd-localed` → D-Bus; the locale is not consulted. Verified live at the
    time and still: `niri msg -j keyboard-layouts` →
    `{"names":["English (US)"],"current_idx":0}`.

  The X11 argument still holds and is worth keeping in the fix: niri never
  consulted `/etc/X11/xkb`, and xkbcommon is compiled with
  `-Dxkb-config-root=${xkeyboardconfig}/etc/X11/xkb`, so dropping the module
  cannot break keymap data.

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

- [x] **3.7 `nix.nix:18` — `auto-optimise-store = true`** on btrfs
  `compress=zstd`. Silent hardlink cloning, near-useless on btrfs and a known
  source of weirdness. Dropped — was already fixed in the tree before this
  review (the item was just never closed out).

  `sys/mods/core/nix.nix:25` carries the replacement comment
  (`auto-optimise-store disabled on btrfs (see AUDIT.md 3.7)`) and the option
  is gone from `nix.settings`.

  **One thing not to misread as a regression:** `/etc/nix/nix.conf:5` still
  reads `auto-optimise-store = false`. That is not the old setting coming back —
  it is the option's own default being written out, because
  `nix.settings.auto-optimise-store` defaults to `false`
  (`nixos/modules/config/nix.nix`). The fix is the *absence* of `true` from
  this config, not the absence of the line. Confirmed at runtime too:
  `nix config show | grep auto-optimise` → `auto-optimise-store = false`.

- [x] **3.8 `nix.nix:38-42` — GC window is ~4 days.** `gc.dates = "weekly"`
  with `options = "--delete-older-than 4d"` meant a weekly GC discarding
  anything older than 4 days, so the rollback window was 4 days. Already
  widened before this review; item never closed out.

  `sys/mods/core/nix.nix:48-53` now has `dates = "weekly"` with
  `options = "--delete-older-than 30d"`. Verified live end-to-end, because
  `gc.options` never appears in `nix.conf` — it is an `ExecStart` argument:
  `nix-gc.service` runs `nix-gc-start`, which contains
  `--delete-older-than 30d`, and `nix-gc.timer` is `OnCalendar=weekly` with
  `Persistent=true` (so a missed GC while powered off still runs). One GC per
  week, discarding anything older than 30 days.

- [x] **3.9 `sys/host:154-159` — wrong explanation.** The comment claimed the
  `/etc` symlink keeps the HM generation alive. It doesn't: the **system
  closure** roots it. The mechanism worked; only the comment was wrong.
  Corrected before this review; item never closed out.

  `sys/host/default.nix:179-185` now says "the system closure roots it;
  `/etc` symlink is just the stable path". Live, as described:

  ```
  /etc/current-home-generation -> /etc/static/current-home-generation
  nix-store -q --deriver /etc/current-home-generation
    -> /nix/store/q8i8rssr0igvvl1f7w9inffjw8nykqlg-home-manager-generation.drv
  ```

  The target resolves through the `etc` derivation, so the generation is in the
  system closure and cannot be collected — the symlink only gives it a fixed
  name. A third root also shows up after a rebuild, created by home-manager
  itself: `/nix/var/nix/gcroots/auto/fjb8z1zy… ->
  /home/yor/.local/state/home-manager/gcroots/current-home`. Harmless overlap;
  worth knowing there are two independent reasons it survives collection, so a
  future reader does not go looking for a third.

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

- [x] **3.11 `sys/mods/core/network.nix:47,56` — "dead nameservers".** — finding
  was WRONG; fixed anyway (2026-10-01)

  **The original claim was false.** It said `["1.1.1.1" "1.0.0.1"]` is
  "overridden by `services.resolved.enable = true`". It is not. The chain is
  real and the option works as intended:

  ```
  networking.nameservers                                    ← the config line
    → services.resolved.settings.Resolve.DNS                ← resolved.nix:95-102,
                                                               default = config.networking.nameservers
      → /etc/systemd/resolved.conf   [Resolve]  DNS=1.1.1.1 1.0.0.1
  ```

  `/etc/resolv.conf` containing `nameserver 127.0.0.53` is the **stub** resolver
  and is the intended design, not an override: everything local talks to the
  stub, the stub forwards to your upstreams. `resolvectl` on the running system
  showed `Global / Current DNS Server: 1.1.1.1`, i.e. it was live all along.

  **The real defect was one level down, and it did matter.** `nameservers` only
  sets the *global* scope, while the router hands out `192.168.254.254` over
  DHCP, which NetworkManager puts on the link and resolved treats as
  link-scoped DNS for `eno1`:

  ```
  Link 2 (eno1)
    DNS Servers: 192.168.254.254 1.0.0.1
  ```

  With both scopes present and equal priority, resolved may answer from the
  router's resolver — so the SEA-blocking risk the setting was added to avoid
  was only partly closed.

  **Fix:** `services.resolved.settings.Resolve.DNSPriority = -50`
  (`sys/mods/core/network.nix:56`), which makes the global Cloudflare pair win
  while *keeping* the router as a fallback — so if Cloudflare is unreachable you
  degrade to ISP DNS rather than losing DNS entirely. Chosen over
  NetworkManager's `ipv4.ignore-auto-dns`, which would have removed the
  fallback entirely. Verified in the built `resolved.conf`:

  ```
  [Resolve]
  DNS=1.1.1.1 1.0.0.1
  DNSPriority=-50
  ```

  Note `DNSPriority` belongs to `services.resolved`, **not**
  `networking.resolved` — `services.resolved.settings.Resolve` is a freeform
  submodule, and there is no `networking.resolved.dnsPriority` option.

  Untouched: mDNS (`services.resolved.domains` is empty, so `~.` is not routed
  through the stub and avahi keeps handling `.local`), and LLMNR.

  **This also turned up a second, unrelated bug, fixed in the same commit.**
  `services.avahi.nssmdns6 = true` without `nssmdns4` meant `ssh qat.local` did
  not resolve at all — see 3.1's correction note for the nss-ordering detail.
  The `nameservers` line was fine; the `.local` half of the story was not.

  **Methodology note from 3.1, learned the hard way.** Do not conclude that a
  rebuild "didn't pick up the config" from an artifact being absent at a
  guessed path, and do not compare an activated store path against
  `git archive`-extracted copies to date it — those evaluate as *path* flakes
  and hash differently from the git flake you actually build, so a mismatch
  proves nothing. Read what the build genuinely emits (`nftables.service`'s
  `ExecStart`, the module's `content`), and remember that a `--flake` rebuild of
  unchanged inputs legitimately reports the *same* store path. The corollary
  applies to *findings* too: 3.11 asserted a config line was inert on the basis
  of a plausible-sounding mechanism that was never checked against
  `services.resolved`'s actual defaults.

- [ ] **3.12 dead NFS support.** — re-verified 2026-10-06, all three references
  survive unchanged and there is still no NFS mount. Ref corrected: the initrd
  lines are in `sys/mods/core/boot/default.nix:26-27`, not `boot:25-28`.

  ```
  sys/mods/core/boot/default.nix:26   boot.initrd.supportedFilesystems = [ "nfs" ]
  sys/mods/core/boot/default.nix:27   boot.initrd.kernelModules = [ "nfs" ]
  sys/host/default.nix:191            nfs-utils in environment.systemPackages
  ```

  A case-insensitive grep for `nfs` across every `.nix` in the tree returns
  exactly those three plus this item — so nothing reads them.

- [ ] **3.13 `usrs/mods/eww/default.nix:46` — `~/.config/eww` is a read-only
  store symlink.** `theme` / `theme_mode` read wallpapers *through* it. Works,
  but zero user extensibility is possible and the bar config can never be
  touched outside Nix. Acceptable if deliberate; document it.

- [x] **3.14 eww yuck scripts depend on the interactive session PATH.** Bare
  `wpctl`, `brightnessctl`, `mpc`, `ffmpeg`, `jq`, `niri`, `systemctl`, inherited
  from `niri.service` → `eww.service`. Works today, breaks the day that chain
  changes. Store paths via `lib.getExe` would be deterministic. — partially
  addressed 2026-10-06: scripts now resolve key binaries via
  `command -v` (fallback) and the eww service's `ExecStartPost` sets a PATH;
  still not fully pinned to store paths for all invocations. Consider
  substituting absolute store paths at build time in `ewwConfig` instead of
  runtime discovery.

  **Why it's better:** `command -v` looks in `PATH` at runtime but defers to what
  the environment actually provides (user profile + system), so the scripts no
  longer hardcode bare tool names that only work if PATH happens to contain
  them. The `ExecStartPost` also explicitly prefixes `/run/current-system/sw/bin`
  into PATH, making the IPC check more robust. It's a defensive improvement
  (self-contained, resilient to environment changes) while stopping short of the
  fully deterministic build-time substitution.

- [ ] **3.15 `usrs/mods/eww/config/scripts/music_info:6` — fixed**
  `/tmp/eww_mp_thumbnail.png` in a world-writable dir, plus an `ffmpeg`
  invocation per track change. — re-verified 2026-10-06, both still true; the
  ref had drifted from `:5` to `:6`.

  `COVER="/tmp/eww_mp_thumbnail.png"` is still at `music_info:6`, still fed by
  `ffmpeg -i … -c copy "$COVER" -y` (`:23`), still invoked from `get_cover`
  (`:19-28`) via `emit_meta` (`:34`) — which only fires when the track's file
  changes (`listen_meta`, `:63-65`), so it really is one `ffmpeg` per track
  change and not per poll. Live proof it is still writing:
  `/tmp/eww_mp_thumbnail.png` exists, mode `-rw-r--r-- yor users`, written today,
  world-readable inside a world-writable directory.

- [ ] **3.16 `sound.nix` — defaults set to defaults.**
  `services.pulseaudio.enable = false` and `security.rtkit.enable = true` are
  both no-ops given pipewire. `alsa.support32Bit = true` only matters for
  32-bit Steam titles.

- [ ] **3.17 `boot/default.nix` + `hardware-configuration.nix` — hand-edited
  generated file.** `hardware-configuration.nix` still carries its "Do not
  modify" header but has been edited. `swapDevices = []` coexists with
  `zramSwap.enable` and will be re-added by `nixos-generate-config`.
  `usbhid` / `sd_mod` / `usb_storage` in `availableKernelModules` are
  built-in no-ops. Move the durable bits into a `sys` module. — re-verified
  2026-10-06, all still true, plus one new wrinkle.

  - The header is untouched (`hardware-configuration.nix:1-3`) and git records
    three manual rewrites: `57e4154` added the `/nix` + `/persist` subvols,
    `6078d42` dropped the `/cred` mount, `a253520` restored the curated
    `compress=zstd`/`noatime`/`kvm-amd` layout after a regeneration lost it.
    `README.md:138-141` documents the hand-maintenance — that is documentation,
    not a fix.
  - `swapDevices = []` (`hardware-configuration.nix:51`) still sits beside
    `zramSwap.enable = true` (`sys/host/default.nix:15`).
  - `availableKernelModules` (`hardware-configuration.nix:15`) still lists the
    three. The "built-in no-op" sub-claim could **not** be re-verified on this
    host: there is no `/lib/modules` tree for `6.18.54`, so it cannot be checked
    from here.
  - **New:** the `/boot` mount options are now in *two* places —
    `lib.mkForce ["fmask=0077" "dmask=0077"]` in
    `sys/mods/core/boot/default.nix:35` (added for §3.20) and the stale
    `["fmask=0022" "dmask=0022"]` still at `hardware-configuration.nix:42`. So
    the one durable bit that *was* moved into `sys` now exists in both files,
    and only the `mkForce` is load-bearing. Worth fixing the stale original to
    `0077` so the two agree and neither reads as a trap.

- [ ] **3.18 `sys/host:107,108,168` — commented-out dead code:**
  `# dbus.enable = true`, `# enable powerprofilesctl`, `# flatpak.enable = true`.
  — re-verified 2026-10-06, still all three. The refs above are corrected; the
  finding originally said `115,116,143`. Worth noting the middle one now sits
  directly above the live setting it once preceded:
  `sys/host/default.nix:108` is `# enable powerprofilesctl` and `:109` is
  `power-profiles-daemon.enable = true;`, so it reads as a note rather than a
  toggle — delete it and keep the other two until someone wants them.

- [ ] **3.19 needless string interpolation around `setup`.** `"${setup.…}"` —
  `setup` values are already strings. — re-verified 2026-10-06, still open but
  **the finding overstated it twice**: it is 10 occurrences on 10 lines across 3
  files, not 12, and 5 of the 10 cannot be removed.

  ```
  sys/host/default.nix:10,13,18,20,185    sys/default.nix:19,65
  sys/mods/core/secrets.nix:25,73,83
  ```

  The 5 that **must** keep interpolation are attribute names —
  `users."${setup.userName}"` (`sys/host/default.nix:18,185`,
  `sys/default.nix:65`) and `"${setup.hostName}" = …` (`sys/default.nix:19`) —
  plus one genuine concatenation, `description = "${setup.userName} (very cool
  person)"` (`sys/host/default.nix:20`).

  So the real cleanup is 5 lines: `sys/host/default.nix:10` (`time.timeZone`),
  `:13` (`i18n.defaultLocale`), and `secrets.nix:25,73,83` (all three just
  prefix a path with `"${setup.homeDir}/"`, which `setup.homeDir + "/"` states
  as directly). Low value; do it or don't, but do not read the item as "12
  redundant interpolations".

- [x] **3.20 `/boot` is world-readable, so the boot loader's entropy seed is.**
  — found 2026-10-01, blocks phase 4. **Fixed before this review; the checkbox
  was simply never closed.** Re-verified 2026-10-06, all three legs:
  `sys/mods/core/boot/default.nix:35` carries the `mkForce` (ref drifted from
  the `:42` quoted below); `findmnt -no OPTIONS /boot` shows
  `fmask=0077,dmask=0077` with `/boot` at mode `700`; and `journalctl -b 0 |
  grep bootctl` is down to the single good line
  (`Random seed file /boot/loader/random-seed successfully refreshed`), both
  world-accessible warnings gone. `stat /boot/loader/random-seed` as `yor`
  returns permission denied, which is the fix being live. Note for anyone
  touching this later: `hardware-configuration.nix:42` still carries
  `fmask=0022 dmask=0022`, so the `mkForce` is the only thing holding it — see
  §3.17.

  ```
  Oct 01 07:16:27 qat bootctl[977]:  Mount point '/boot' which backs the random
        seed file is world accessible, which is a security hole!
  Oct 01 07:16:27 qat bootctl[977]: Random seed file '/boot/loader/random-seed'
        is world accessible, which is a security hole!
  ```

  Pre-existing, not from §3.3 — it is in boots `-6`, `-5` and `-1` too — but it
  matters more now that LUKS is on the roadmap, so it is recorded before phase 4
  rather than during it.

  **What the file is.** `systemd-boot-random-seed.service` runs
  `bootctl --graceful random-seed` with `SYSTEMD_ESP_PATH=/boot` before
  `sysinit.target` (nixpkgs wires the path in
  `nixos/modules/system/boot/loader/efi.nix:19-20`; the unit is systemd's, and
  `systemd.nix:109-112` pulls it in). Per
  `systemd-boot-random-seed.service(8)`: systemd-boot reads the seed from the ESP,
  hashes it with a 'system token' held in an EFI variable, and passes the result
  to the kernel as **initial entropy pool seed** — that is the whole point, an
  entropy pool that is already full before any disk is readable. `bootctl(1)`
  refreshes the on-disk seed every boot so consecutive boots differ; the token is
  generated once and stored in NVRAM, which is what stops a cloned disk image
  from producing the same seed series across machines.

  So a readable seed means an attacker knows the kernel's early RNG state.

  **Why it is 0755.** Not a stray `chmod` — `/boot` is **vfat**, where POSIX
  modes are synthesised from mount options and `chmod` does not stick:

  ```
  $ findmnt -no SOURCE,FSTYPE,OPTIONS /boot
  /dev/nvme0n1p5 vfat rw,relatime,fmask=0022,dmask=0022,…,errors=remount-ro
  $ stat -c '%a' /boot/loader/random-seed
  755
  ```

  `0777 & ~0022 = 0755` for the file, `0777 & ~0022 = 0755` for the directory.
  The mask is the default the installer wrote into `hardware-configuration.nix`:

  ```nix
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/A7A2-930C";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];   # hardware-configuration.nix:41-42
  };
  ```

  and it reaches the mount unit by the ordinary route —
  `boot.mount` is `SourcePath=/etc/fstab`, and line 10 of the generated fstab is
  exactly that entry. `sys/mods/core/boot/default.nix:16` only sets
  `efiSysMountPoint = "/boot"`.

  **Fix applied.** `sys/mods/core/boot/default.nix:42`:

  ```nix
  fileSystems."/boot".options = lib.mkForce ["fmask=0077" "dmask=0077"];
  ```

  `0077` is what Debian/Ubuntu use for `/boot/efi`. Safe here: nothing in the
  chain reads the ESP as non-root — `bootctl`, `systemd-bless-boot` and
  `kernel-install` all run as root, and the systemd-boot/lanzaboote EFI binaries
  read it in firmware context where POSIX modes do not apply at all. The only
  casualty is a non-root user running `cat /boot/loader/loader.conf` by hand.

  **Why `mkForce` in `sys`, not an edit to `hardware-configuration.nix`.** §3.17
  already flags that file as hand-edited despite its "Do not modify" header, and
  the mask is a durable bit: `nixos-generate-config` would write `0022` straight
  back over a local edit on the next re-generation. `mkForce` overrides the
  generated `fileSystems` entry whichever file it lands in, and survives it.

  Verified: `fileSystems."/boot"` evaluates to
  `{device = "/dev/disk/by-uuid/A7A2-930C"; fsType = "vfat"; options = ["fmask=0077" "dmask=0077"];}`
  and the toplevel builds.

  **Confirmed on disk after rebuild + reboot.** `/boot` is mounted
  `fmask=0077,dmask=0077` and is `drwx------`; `stat /boot/loader/random-seed`
  as the `yor` user now returns `Permission denied`, which is the fix being
  live rather than the warning being intermittent. `bootctl` dropped from three
  lines to one, and the one that remains is the good one:

  ```
  - boot -1: bootctl[977]:  Mount point '/boot' … is world accessible …
  - boot -1: bootctl[977]: Random seed file '/boot/loader/random-seed' … world accessible …
  - boot -1: bootctl[977]: Random seed file /boot/loader/random-seed successfully refreshed (32 bytes).
  + boot  0: bootctl[972]: Random seed file /boot/loader/random-seed successfully refreshed (32 bytes).
  ```

  **Severity, honestly:** low today. Only `root` can read it —
  `trusted-users = root yor`, `users.mutableUsers = false`, and the only other
  accounts are `sddm` and `nixbld*` — and `yor` reading their own seed is not a
  threat. It becomes a real one if an unprivileged service is ever compromised,
  and it is worth closing before LUKS lands because a predictable early entropy
  pool is a modest aid to offline key search, and because the disk image is the
  thing that gets cloned and shared.

---

## 4. Duplication & dead weight

- [x] **4.1 Satoshi is defined twice.** — fixed (2026-10-01)
  - `sys/mods/core/fonts.nix:2-27` — `pname = "satoshi"`, version `2.000`, has
    `meta.license = licenses.unfree`
  - `sys/mods/core/stylix.nix:8-21` — `pname = "satoshi-font"`, version `1.0`,
    **no `meta`**, no `runHook`, different install path

  Both hashes were valid (verified) only because `stripRoot` differed, so
  `fetchzip`'s *output* hash differed. Two store paths, two downloads, and the
  stylix copy had no license metadata on an unfree font. `sentient`
  (`stylix.nix:23-36`) was also license-less.

  Extracted both into `sys/mods/core/fonts-share.nix` (a plain derivation file,
  not a module — imported by both consumers as `import ./fonts-share.nix
  {inherit pkgs;}`; there are no custom options anywhere else in this config, so
  a NixOS option was not worth the machinery). The `fonts.nix` version survived
  as the single definition: it is the one with the honest version (`2.000`, not
  the invented `1.0`), `runHook preInstall/postInstall`, and full `meta`. One
  store path now serves both consumers, so the same ~1 MB zip is fetched and
  unpacked once instead of twice.

  `sentient` got the same treatment (`runHook`, `description`, `homepage`,
  `license = licenses.unfree`), so both unfree Fontshare fonts are now
  correctly marked.

  **`fonts.nix` was kept**, not deleted: it still owns the nerd font and the
  `fontconfig.defaultFonts` block. Worth recording *why* the nerd font matters,
  because it is load-bearing in a non-obvious way — eww's bar icons are Material
  Design glyphs (󰻞 󰇧 󰨞 󰯜 󰓩 󰅁-󰅄󰤆) rendered at
  `font-family: $mono-font`, i.e. **Comic Mono, which contains none of them**.
  Queried per-codepoint against fontconfig, every one resolves only via
  `DroidSansM Nerd Font`, the second entry in `defaultFonts.monospace`. Satoshi
  is never consulted for icon rendering.

  Satoshi was then dropped from `fonts.nix`'s `packages` entirely, since
  `stylix.fonts.sansSerif` already registers it — it was listed twice pointing
  at one path. `fonts.packages` is now 17 entries over 15 unique store paths;
  the remaining two dupes (`comic-mono`, `noto-fonts-color-emoji`) are
  pre-existing, same-path, and unrelated. No font rebuild is needed for either
  change (`nix build --dry-run` shows only fontconfig/HM regeneration).

- [ ] **4.2 ~7 MB of dead binaries in git.** `stitch_wall_dark.png` at the repo
  root is **md5-identical** to
  `usrs/mods/eww/config/images/wallpapers/stitch_wall_dark.png`;
  `stitch_wall.png` likewise. `stitch_wall_hd.png` (2.6 MB) and all three
  `.webp` files are referenced by nothing. Only `wall.png` is live (README).
  — re-verified 2026-10-06; nothing removed.

  Root image set: `stitch_wall_dark.png` 670375 B, `stitch_wall.png` 1055709 B,
  `stitch_wall_hd.png` 2623915 B, `stitch_wall_dark.webp` 54040 B,
  `stitch_wall.webp` 575310 B, `stitch_wall_hd.webp` 303322 B, `wall.png`
  2211087 B. md5sums match: both `stitch_wall_dark.png` copies have the same
  hash; both `stitch_wall.png` copies match. The eww wallpapers dir contains
  only 5 files (`stitch_wall_dark.png`, `stitch_wall.png`, `cityscape.jpg`,
  `home.jpg`, `retro-street.jpg`, `seerlight.jpg`, `seerlight2.jpg` — 7 total)
  and **no HD and no webp**. Tree-wide grep: `stitch_wall_dark.png` referenced
  by `usrs/mods/eww/config/scripts/theme:14` and
  `usrs/mods/niri/default.nix:272`; `stitch_wall.png` by
  `usrs/mods/eww/config/scripts/theme:15` and
  `usrs/mods/eww/config/scripts/theme_mode:4`; `wall.png` by `README.md:4`.
  `stitch_wall_hd.png` and all three `.webp` files have zero references outside
  AUDIT.md itself.

- [~] **4.3 `sys/host` re-states what niri-flake already sets with `mkDefault`:**
  `hardware.graphics.enable`, `programs.dconf.enable`,
  `services.gnome.gnome-keyring.enable`, and the `xdg.*` set.
  — **half wrong; corrected 2026-10-01, one line now load-bearing**

  Two of the four were already gone from `sys/host` before §2.2 (the
  gnome-keyring line in §2.3b, the `xdg.*` set earlier), so only two lines were
  ever left to check: `sys/host/default.nix:100-101`.

  - `programs.dconf.enable = true` — **still redundant**, but not by
    niri-flake's hand: nixpkgs' `wayland-session.nix:17` sets it
    `mkDefault true`, and `niri.nix:83-86` imports that module. Delete freely.
  - `hardware.graphics.enable = true` — **no longer a duplicate.** niri-flake
    did set it `mkDefault` (`niri-flake/flake.nix:497`), but nixpkgs'
    `niri.nix`/`wayland-session.nix` do not mention `hardware.graphics` at all
    (grepped both). With the flake gone this line is the *only* thing enabling
    it, so removing it is a real behaviour change for GL apps in the session,
    not a cleanup. Left in place deliberately; not pursued further here.

- [x] **4.4 `niri` is in `environment.systemPackages` twice** (from
  `programs.niri.package` and `hardware.graphics.enable`). — false; closed
  (2026-10-01)

  `hardware.graphics.enable` never put `niri` in `systemPackages`, so the
  premise was wrong. With niri-flake gone it is now measurably **once**:
  `nix eval --json` over
  `config.environment.systemPackages` filtered by `pname == "niri"` returns
  length 1. The single entry is `cfg.package` from
  `nixpkgs/nixos/modules/programs/wayland/niri.nix:25-27`.

- [x] **4.5 Personal data outside `setup/`** — the whole premise of the layout.
  Git name/emails, the `qarkdev+*` addresses and the
  `~/Documents/A-Work/1-Fling/gitlab/**` include all lived in
  `usrs/mods/git/default.nix`. Moved to `setup` on 2026-10-06.

  `setup/default.nix` now owns the whole identity, matching how `symLinks` and
  `secrets` are already shaped there:

  ```nix
  git = {
    name = "YorQat";
    email = "qarkdev+gh@gmail.com";
    work = { dir = "Documents/A-Work/1-Fling/gitlab"; email = "qarkdev+gl@gmail.com"; };
  };
  ```

  `work` is the odd one out and deserves a note: git's `gitdir:` patterns are
  matched against the repository path, so that directory has to stay
  `$HOME`-relative even though everything else in `setup` spells out `homeDir`.
  It works because `symLinks` puts `/dat/Documents` at `~/Documents`
  (`setup/default.nix:31`); the comment there says so.

  `usrs/mods/git/default.nix` reads it through `setup`, which was already
  available as a module argument (`home-manager.extraSpecialArgs` in
  `sys/default.nix:60-61`) — no wiring needed. `config` went out of the
  signature, where it was unused. The include is now a plain
  `contents.user.email = setup.git.work.email;`, and the two `# Put your
  GitLab email here` / optional-`signingKey` comments went with the literal
  strings they annotated: the point of this item is that a value you must not
  hand-edit away from `setup` should not be sitting in a module, commented or
  not. The signing config itself is untouched — that is §4.7.

  Verified behaviour-neutral: the rendered `~/.config/git/config` is
  byte-identical (sha256 `b02053ce…`), including the
  `includeIf "gitdir:~/Documents/A-Work/1-Fling/gitlab/**"` line and the store
  path it points at (`6lqzcjgy…-hm_gitconfig`) — that path is a content hash of
  the generated `hm_gitconfig`, so an unchanged path means the per-repo
  `[user] email = "qarkdev+gl@gmail.com"` body is unchanged too. `git grep` for
  `qarkdev|YorQat|A-Work|1-Fling` now hits `setup/default.nix` and nothing else.

- [ ] **4.6 `yor-password-hash` is named twice** — `setup.secrets.root` and
  hardcoded at `sys/host/default.nix:23`. Rename it and the host module breaks
  with an unhelpful error. Drive it from `setup.secrets.root`. — re-verified
  2026-10-06, still intact.

  `setup/default.nix:67` → `root = ["yor-password-hash"];`
  `sys/host/default.nix:23` → `hashedPasswordFile = config.sops.secrets."yor-password-hash".path;`
  Documentation only at `README.md:153,155`. Ref drifted from `:35`. So the
  duplication remains.

- [ ] **4.7 Dead signing config.** `usrs/mods/git/default.nix` still contains:
  `signing.format = null` (`:16`), `# commit.gpgsign = true` (`:41`),
  `gpg.format = "ssh"` (`:42`), `# gpg.ssh.allowedSignersFile` (`:43`),
  `# user.signingkey` (`:44`). — re-verified 2026-10-06. Identity was moved to
  `setup/default.nix` but the signing block was left as-is, so it still signs
  nothing. Note the module now takes `setup` as an arg; the dead config wasn't
  removed.

- [x] **4.8 `opencode` the binary is declared in `apps/neovim`'s
  `extraPackages`,** while its config is in `apps/opencode`. Comment out neovim
  and the binary vanishes. — **already fixed** by refactor; re-verified
  2026-10-06.

  The `opencode` package is now declared at
  `usrs/mods/apps/opencode/default.nix:4` (`package = pkgs.opencode;`) with
  `enable = true` at `:3`; its config lives there. `neovim`'s `extraPackages` at
  `usrs/mods/apps/neovim/default.nix:55-57` contains **only** `ripgrep` (no
  `opencode`). Stale explanatory comments remain at `neovim/default.nix:54` and
  `:92` (`"bare `opencode` binary via extraPackages"`), but the coupling is
  gone.

- [ ] **4.9 Stylix targets programs that aren't installed.** System-level:
  `fish`, `lightdm`, `grub`, `plymouth`, `regreet`, `spicetify`. HM-level:
  `vscode` (its module is commented out), plus `hyprland`, `sway`, `river`,
  `wayfire`, `bspwm`, `i3`, … And `nixvim` is targeted by **both** the system
  and HM stylix instances. — re-verified 2026-10-06; **mostly resolved,
  dual-target claim is stale, but vscode is still orphaned.**

  - `sys/mods/core/stylix.nix` has no `targets` block at all (41 lines, ends at
    the fonts block). HM `usrs/default.nix:68-71` only sets `kde.enable = false;
    gnome.enable = false;`.
  - Grep for `stylix.targets` returns only `usrs/default.nix:68` and
    `usrs/mods/apps/neovim/default.nix:6` — so every program the finding lists
    as mistargeted (`fish`, `lightdm`, `grub`, `plymouth`, `regreet`,
    `spicetify`, `vscode`, `hyprland`, `sway`, `river`, `wayfire`, `bspwm`, `i3`)
    is **absent** from the actual stylix config now.
  - `nixvim` is **only** targeted at HM (`neovim/default.nix:6`); there is no
    system-level `nixvim` stylix target, so the "targeted by both" point is no
    longer true.
  - `vscode` remains an orphan: `usrs/mods/apps/vscode/default.nix` exists but
    `usrs/default.nix:25` is commented out (`# ./mods/apps/vscode`), and nothing
    targets it. Not a "mistargeted", it's unused. The stale comments elsewhere
    aren't it — the thing that *could* be cleaned up is the unused module.

- [ ] **4.10 `flake.nix:47` — misleading alias.** `outputs = {self, ...} @ inputs`
  binds `inputs` to the whole attrset, not `self.inputs` (the module tree uses
  the latter). It's unused and reads backwards. — re-verified 2026-10-06, still
  open.

  `flake.nix:47`: `outputs = {self, ...} @ inputs:`; the tree works because
  `sys/default.nix:7` explicitly does `inputs = self.inputs;` in its local let,
  so nothing depends on the pattern. The pattern is itself a bit misleading but
  doesn't break anything — the finding is correct about it being misleading and
  unused by the alias target. Ref corrected from `:49`.

- [ ] **4.11 No `formatter` output,** despite `AGENTS.md` mandating alejandra.
  — re-verified 2026-10-06, still open.

  `flake.nix` contains no `formatter` key at all. Only package presence is
  `devshell/default.nix:10` (`alejandra`) and the only output keys are
  `nixosConfigurations` and `devShells.x86_64-linux.default` (`flake.nix:53-57`),
  so `nix fmt` does nothing. The finding is correct as-is.

- [ ] **4.12 `devshell` carries tools with no users:** `fnlfmt` (no fennel in
  the tree) and `yaml-language-server` (no yaml). — re-verified 2026-10-06, both
  still there and unused; other possible orphans noted.

  `devshell/default.nix:6-13`: lists `secrets`, `sops`, `age`,
  `yaml-language-server` (`:9`), `alejandra` (`:10`), `fnlfmt` (`:11`),
  `stylua` (`:12`). No `*.fn` files and no `fennel` reference anywhere except
  `:11`. For yaml: only `.sops.yaml` exists; `yaml-language-server` has no
  consumers in the nix/flake. `stylua` is also a borderline orphan (no `.lua`
  files in the tree; lua only used as an interpreter at
  `usrs/mods/shell/default.nix:6` and `neovim/default.nix:112`) — the finding
  only names the first two, but it's fair to note it.

- [~] **4.13 Hardcoded `trusted-public-keys` / `substituters` will rot.**
  `nixpkgs-wayland.cachix.org` and `nix-community.cachix.org` are pinned here
  for flake inputs that may not survive §5.
  ~~(The niri key and `hyprland.cachix.org` used to be in this list too; §2.7
  dropped the first as a duplicate of what niri-flake injects, and the second as
  a flake that is not in the tree.)~~ — **updated by §2.2 (2026-10-01):** the
  niri key is now gone for a *different* reason. It was never a duplicate to
  begin with — niri-flake injected `niri.cachix.org` while §2.7 had also
  hand-listed it, so it was listed twice and the flake had to be disabled to
  make it once. With the flake deleted the entry is simply absent (verified in
  the built `nix.conf`). `hyprland.cachix.org` remains gone as §2.7 found it.
  `nixpkgs-wayland` and `nix-community` are still live inputs and still pinned,
  so this finding stays open for them.

- [x] **4.14 `services.xserver.xkb` in `sys/host` writes nothing.** — found
  2026-10-01, while checking §3.3. **The premise was wrong; corrected
  2026-10-06, and the layout is now pinned.**

  ```nix
  xserver = {
    enable = true;
    xkb = { layout = "us"; variant = ""; };   # sys/host/default.nix:116-119
  };
  ```

  `/etc/X11/xkb` is emitted only under `optionalAttrs cfg.exportConfiguration`
  (`nixos/modules/services/x11/xserver.nix:896-900`), and
  `services.xserver.exportConfiguration` defaults to `false`
  (`xserver.nix:383-385`). This config never sets it — that part holds, proven
  three ways: `environment.etc` has no `X11/xkb` key, the built `etc`
  derivation contains `X11/xorg.conf.d/` but no `X11/xkb`, and the running
  system has no `/etc/X11/xkb`.

  ~~So this is dead config, and deleting it is a no-op.~~ **It is not dead
  config.** It has two live consumers on this box, neither of which is
  `/etc/X11/xkb`:

  - **The greeter's keymap.** `services.displayManager.sddm.wayland` generates
    `weston.ini` with a `[keyboard]` section straight from `xcfg.xkb.*`
    (`nixos/modules/services/display-managers/sddm.nix:135-142`), and that file
    is what `weston --shell=kiosk -c …` runs under. Not gated on
    `xserver.enable`. Verified in the store:
    `keymap_layout=us`, `keymap_model=pc104`,
    `keymap_options=terminate:ctrl_alt_bksp`, `keymap_variant=`.
  - **niri's keymap.** `services.graphical-desktop` renders
    `/etc/X11/xorg.conf.d/00-keyboard.conf` from `xcfg.xkb.{model,layout,
    options,variant}` (`nixos/modules/services/misc/graphical-desktop.nix:23-41`,
    gated on `xserver.enable || displayManager.enable` — both confirmed `true` by
    eval, so sddm keeps it alive with no X server), `systemd-localed` parses that
    file, and niri reads the result over D-Bus because its own `xkb {}` block is
    empty. niri's own documentation (since 25.08): "If the `xkb` section is empty
    (like it is by default), niri will fetch xkb settings from systemd-localed at
    `org.freedesktop.locale1`". Verified live: the conf file carries
    `XkbModel "pc104"` / `XkbLayout "us"` / `XkbOptions "terminate:ctrl_alt_bksp"`,
    and `busctl get-property org.freedesktop.locale1 /org/freedesktop/locale1
    org.freedesktop.locale1 X11Layout` → `"us"` (same for `X11Model "pc104"` and
    `X11Options "terminate:ctrl_alt_bksp"`). localed is D-Bus-activated, so
    nothing has to enable the unit.

  A third consumer exists and is off: `console.useXkbConfig` would build a
  `ckbcomp` console keymap from the same values (`config/console.nix:148-157`),
  but it evaluates `false`, and the TTY keymap is a separate option anyway.

  ~~niri now derives `us` from `LANG=en_PH.UTF-8` via `systemd-localed`.~~
  **The locale is not an input.** localed's `X11Layout` comes from
  `00-keyboard.conf`, not from `LANG`, and libxkbcommon does not consult the
  locale either. Linked against this system's own `libxkbcommon-1.13.2` and
  calling `xkb_keymap_new_from_names(ctx, NULL, …)` — which is what niri ends up
  doing once its block is empty and no names are supplied — returns
  `English (US)` for `LANG` of `en_PH.UTF-8`, `en_US.UTF-8`, `fr_FR.UTF-8`,
  `de_DE.UTF-8` and `ru_RU.UTF-8` alike, with model and options unset. Only
  `XKB_DEFAULT_LAYOUT` moved the result (`=fr` → `French`), and no nixpkgs
  module sets it — `grep -rn XKB_DEFAULT nixos/modules/` finds nothing. "us" is
  libxkbcommon's built-in default, which coincides with what we want. That
  coincidence is why `LANG=en_PH.UTF-8` looks like it works: it is not load-
  bearing, and `symbols/ph` is not even registered as a layout in
  xkeyboard-config 2.48 (`rules/evdev` has no `ph` entry), so there was never a
  Philippine layout for a locale to select.

  **Deleting the block was a no-op by coincidence, not by equivalence.** The old
  `{ layout = "us"; variant = ""; }` was field-for-field the module default
  (`layout = "us"`, `model = "pc104"`, `options = "terminate:ctrl_alt_bksp"`,
  `variant = ""`; `xserver.nix:545-580`), so `00-keyboard.conf` renders
  byte-identically with or without it. What was lost is the *statement of
  intent*: nothing in the tree named the layout any more, so it rode on two
  upstream defaults plus the `displayManager.enable` side effect that emits the
  file. That is the trap this entry created — read literally, it invites
  deleting `00-keyboard.conf`, which looks X-only on a box with
  `xserver.enable = false`, and doing so silently drops the model and the
  options with no error anywhere.

  **Fixed (2026-10-06):** `sys/host/default.nix` sets
  `services.xserver.xkb.layout = "us"` explicitly again, with a comment naming
  the whole chain. Behaviour is unchanged — evaluated before and after, the
  rendered `00-keyboard.conf` is byte-identical (sha256 `c8be7d5d…`). `model`
  and `options` are deliberately left on the nixpkgs defaults and named in the
  comment instead: `terminate:ctrl_alt_bksp` terminates the *X server*, which
  this box does not run, so pinning it would enshrine an inert X-ism.

  **Not done, deliberately:** `exportConfiguration = true`, which this entry
  previously prescribed. Neither live path needs it — `weston.ini` and localed
  both read `xcfg.xkb.*` directly and never touch `/etc/X11/xkb` — and it would
  add an `xorg.conf` to a machine with no X server. The dangling
  `SYSTEMD_XKB_DIRECTORY = "/etc/X11/xkb"`
  (`nixos/modules/system/boot/systemd.nix:625`, unconditional upstream) is left
  alone too: it only matters to `localectl convert`, and "fixing" it means
  putting a store path in the config.

  **Related after all, and it is where this started:** the sddm greeter shows
  its keyboard layout as `zz`. Typing in the greeter is unaffected — that keymap
  comes from `weston.ini`, which does carry `keymap_layout=us` (see the first
  consumer above). `zz` is sddm's own placeholder in its indicator:
  `SddmComponents/LayoutBox.qml` renders `"zz"` when the row has no model item,
  and `WaylandKeyboardBackend::init()` deliberately populates no layouts on
  Wayland ("TODO: We can't actually switch keyboard layout yet"). No option
  reaches it, so `services.xserver.xkb` cannot fix it; the only fixes are
  patching sddm or dropping the wayland greeter. Worth noting the two are easy
  to conflate: sddm cannot *report* the layout on Wayland, while the greeter
  still *applies* the right one via weston.

- [ ] **4.15 `services.xserver.videoDrivers = [ "nvidia" ]` is inert** — a
  consequence of §3.3, recorded 2026-10-01. — re-verified 2026-10-06,
  **partially resolved**: the module is now gated at import time, but the line
  itself remains unconditional.

  `sys/mods/nvidia/default.nix:33` sets it unconditionally. The module is
  conditionally imported: `++ lib.optional setup.includes.nvidia ./mods/nvidia`
  (`sys/default.nix:70`), and `includes.nvidia = !lite` (`setup/default.nix:72`),
  so with `lite = false` it evaluates (and with `lite = true` it won't be
  imported at all) — that matches the "move behind whatever gates the rest"
  suggestion in the finding. `xserver.enable = false` still means nothing reads
  it, so it's still misleading in the sense that it's inert on a Wayland box,
  but it's no longer unconditionally active when not wanted. Left in place as
  conventional documentation.

---

## 5. Follow-up worth considering

- [x] **Delete the `niri` input** and use nixpkgs' NixOS + HM niri modules. —
  done (2026-10-01)

  The predicted wins, checked one by one:

  - **KDE polkit agent** — lost, as intended. Replaced deliberately with
    `polkit-gnome` (`systemd.user.services` in `usrs/mods/niri`, wanted by
    `graphical-session.target`).
  - **Forced GNOME portal** — *not* lost, and this part of the prediction was
    wrong. nixpkgs recommends the same portal upstream
    (`niri.nix:77-79`). It also *gains* `xdg-desktop-portal-gtk` via
    `wayland-session.nix:23`. See §2.2 for the correction.
  - **Duplicate nixpkgs** — lost. 4 lock nodes → 3, stale `b4fd65b1` gone.
  - **Duplicate stylix injection** — lost. `sharedModules` 30 → 27.
  - **Unused binary cache** — lost, and `niri.cachix.org` with it.
  - **Clean `nix.conf`** — not quite: `nix.settings.substituters` still pins
    `fortuneteller2k`, `nixpkgs-wayland` and `nix-community` (§4.13).

  Two things the follow-up did not mention, and both needed work:

  - **stylix has no niri target**, so the cursor/focus-ring/border colours are
    now hand-written in `usrs/mods/niri/default.nix`. This is the one piece of
    niri-flake that was not simply removable.
  - **HM's KDL renderer emits configs niri rejects** for three specific shapes
    (`_children` for actions, `on = {}`, `_props` for scalar key/values). All
    three are now in the config with comments explaining why, and `checkConfig`
    catches regressions at build time.

  Verified with `nix eval …toplevel.drvPath` (clean), a full
  `nix build …toplevel`, `alejandra --check`, a realised `system-path` /
  HM-generation diff against the running system, and a whole-closure diff.

---

## 6. Fresh-install gaps

- [ ] **6.1 Secrets have no bootstrap path, and `lite` doesn't cover it.**
  `sops.age.keyFile = "/persist/var/lib/sops-nix/key.txt"` (`sys/mods/core/secrets.nix:40`),
  still inside `/persist`. The `sops` attrset is gated only on
  `payloads != {} || rootSecrets != []` (`:39`), not on key presence. The
  dereference is unconditional:
  `hashedPasswordFile = config.sops.secrets."yor-password-hash".path;`
  (`sys/host/default.nix:23` — drifts from `:35`). `setup.secrets.root =
  ["yor-password-hash"]` (`setup/default.nix:67`). No `setup.lite` involvement.
  `README.md` still documents the manual procedure only (`66-80`), no check or
  enforcement. — re-verified 2026-10-06, still open. Also worth noting that with
  root non-ephemeral (§1), the `/persist`-pointing key file path is a
  consequence, not the cause, of the current situation.

- [ ] **6.2 `sys/mods/core/secrets.nix:79-88` — the `authorized_keys` template
  is unconditional.** It sits in the `//` arm, so it is defined whenever
  `payloads != {}` regardless of whether `id_ed25519.pub` exists. Rename or
  remove that one payload and you get an opaque eval failure. Other secrets are
  properly gated by `envAvailable` (`:31`); this one isn't. — re-verified
  2026-10-06, still present. Ref corrected from `secrets.nix:79-88` to the
  full path and line numbers.

- [ ] **6.3 Inconsistent tmpfiles force semantics.** `usrs/default.nix:9-11`
  uses `L` for `setup.symLinks` (correctly refuses to clobber a real dir, but
  silently no-ops with a journal warning) while `usrs/mods/niri/default.nix:272`
  uses `L+` for the wallpaper. The requested comment explaining the `L` choice
  does not exist — `setup/default.nix:36-45` has only `# [ "dest" "src" ]`. Add
  a comment in `setup.symLinks` saying the `L` is deliberate. — re-verified
  2026-10-06, still open; refs corrected.

- [ ] **6.4 `/etc/NetworkManager/system-connections` is not in the persistence
  allowlist.** Harmless today only because of §1 (nothing wipes root). The
  moment the root wipe lands, every saved WiFi password is lost on reboot. Add
  it in the same commit as §1. — re-verified 2026-10-06, still open.

  `sys/mods/core/persistence.nix:7-14` lists only `/var/lib/NetworkManager`
  (state) — the connections list lives in `/etc/NetworkManager/system-connections`
  on the root filesystem and is **not** in the allowlist. Also: given
  `persistence.nix:2` now claims "root is blank at boot" (§1), this is no longer
  hypothetical under that wording. The path does not appear anywhere else in
  the tree.

- [ ] **6.5 `usrs/mods/fastfetch/default.nix:11,16`.** `nix-light.png` is
  installed and never referenced; the logo `source` uses `config.home.homeDirectory`
  instead of a store path, so the config isn't reproducible. — re-verified
  2026-10-06, still partially open.

  `"fastfetch/nix-light.png".source = ./config/nix-light.png;` at `:11` is
  deployed but has **zero references** in the tree (only AUDIT.md). At `:16`:
  `source = "${config.home.homeDirectory}/.config/fastfetch/nix-original.png";`
  — it is config-derived, not a literal `$HOME` string, but it still points to a
  mutable runtime path rather than the store copy `./config/nix-original.png`
  (`:10`). Also note: the checked-in `config.jsonc:5` uses `"nix-original.png"`
  relative, but that jsonc is never written — `default.nix:13` generates the
  config from `builtins.toJSON`, so `config.jsonc` is effectively dead weight.

---

## Appendix: things checked that are fine

Recorded so they don't get re-audited:

- `usrs/mods/eww/config/scripts/*` are `100755` in git and executable in the
  store — `deflisten` works.
- The `theme` script's `$GEN/activate` / `specialisation/light/activate` dance
  works, and `home.programs.niri.package` is correctly `mkForce`d to
  `pkgs.niri` (26.04) by the niri-flake module, so `config.kdl` is validated
  against the binary that actually runs.
  **Updated by §2.2 (2026-10-01):** niri-flake is gone, so that `mkForce` came
  from niri-flake, not from HM. The `mkForce` is now written by hand in
  `usrs/mods/niri/default.nix`; the guarantee itself is unchanged and was
  re-verified — the HM-side and system-side `niri` resolve to the same
  `/nix/store/14fnag7q2i1q18nqi56ggqgbd1cl0c3g-niri-26.04`, so `checkConfig`
  validates against the binary that actually runs.
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
