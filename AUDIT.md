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

  **Behaviour change, deliberate:** the empty `input.keyboard.xkb` block is gone
  from the generated config (verified absent), so niri now reads the locale
  (`us`, `pc104`, `terminate:ctrl_alt_bksp` from `localectl`) instead of
  overriding all three with empty strings. That is the right direction — the
  block was the flake writing out *niri's own defaults*, not configuration — but
  it does mean the first session after the switch picks up `localectl` settings
  that were previously masked. Worth one manual login check.

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
    writes nothing — unchanged, see §4.14.

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
  this config it writes nothing at all, module or not:

  - `/etc/X11/xkb` is emitted only under `optionalAttrs cfg.exportConfiguration`
    (`nixos/modules/services/x11/xserver.nix:896-900`), and
    `services.xserver.exportConfiguration` defaults to **`false`**
    (`xserver.nix:383-385`) and is never set here. Verified: the built `etc`
    derivation has `X11/xorg.conf.d/` but no `X11/xkb`, and there is no
    `/etc/X11/xkb` on the running system.
  - So the layout niri actually used was the one niri-flake wrote into
    `config.kdl`, and `services.xserver.xkb` was dead weight. Tracked on its own
    in §4.14.
  - §2.2 then removed that `config.kdl` block too (it was niri's own default,
    not configuration). niri now resolves its layout from the locale chain —
    `/etc/locale.conf` (`LANG=en_PH.UTF-8`) → `systemd-localed` → `us`.
    Verified live: `niri msg -j keyboard-layouts` →
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

- [ ] **3.20 `/boot` is world-readable, so the boot loader's entropy seed is.**
  — found 2026-10-01, blocks phase 4

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

- [ ] **4.14 `services.xserver.xkb` in `sys/host` writes nothing.** — found
  2026-10-01, while checking §3.3

  ```nix
  xserver = {
    enable = true;
    xkb = { layout = "us"; variant = ""; };   # sys/host/default.nix:116-119
  };
  ```

  `/etc/X11/xkb` is emitted only under `optionalAttrs cfg.exportConfiguration`
  (`nixos/modules/services/x11/xserver.nix:896-900`), and
  `services.xserver.exportConfiguration` defaults to `false`
  (`xserver.nix:383-385`). This config never sets it, so the option is inert —
  proven three ways: `environment.etc` has no `X11/xkb` key, the built `etc`
  derivation contains `X11/xorg.conf.d/` but no `X11/xkb`, and the running
  system has no `/etc/X11/xkb`.

  It was never what set the layout either. niri was reading
  `input.keyboard.xkb` out of `config.kdl`, and §2.2 removed that block as
  niri-flake's own default. niri now derives `us` from
  `LANG=en_PH.UTF-8` via `systemd-localed` — verified live with
  `niri msg -j keyboard-layouts` → `{"names":["English (US)"],"current_idx":0}`.

  So this is dead config, and deleting it is a no-op. The part that matters:
  **§3.3's fix interacts with it.** Setting `xserver.enable = false` does not
  resurrect the file (the gate is `exportConfiguration`, not `!enable`), so the
  layout keeps riding on the locale either way. If the intent is for
  `services.xserver.xkb` to be the source of truth, the honest fix is to set
  `exportConfiguration = true` alongside it — which is also what puts the
  `xkeyboard-config` symlink where X11 clients would look. Deciding that is
  part of §3.3, not a cleanup.

- [ ] **4.15 `services.xserver.videoDrivers = [ "nvidia" ]` is inert** — a
  consequence of §3.3, recorded 2026-10-01

  `sys/mods/nvidia/default.nix:33` sets it unconditionally in the nvidia module.
  With no X server (§3.3) nothing reads it: `videoDrivers` is consumed only by
  `xserver.nix` when building the X server's driver arguments, and niri gets its
  NVIDIA support from the kernel module plus `hardware.nvidia`. It still
  evaluates fine, so it is misleading rather than broken.

  Left in place rather than removed, because the option is the conventional
  place to record "this box runs NVIDIA" and would become live again if X11 ever
  comes back. But it should not be read as load-bearing, and it should move
  behind whatever gates the rest of `sys/mods/nvidia` if that module ever gains a
  `setup.lite` guard.

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
