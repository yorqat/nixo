# YorPuter
A pretty cool system on wayland with some cool widgets.

<img src="wall.png" alt="my current wallpaper" width="100%">

<br />

## Config in a config
You may tailor the [config](setup/default.nix) to how you want it.

<br />

# Required directories
Since these are located at `/` it would be desirable if these are mountpoints or symlinks.


> **Note:** Ability to change locations rolling out soon.

## [`/dat`](usrs/default.nix)
Home folders: `Desktop`, `Documents`, `Videos`, `Pictures`, `Music`

## Secrets
Managed by [sops-nix](https://github.com/Mic92/sops-nix): payloads are encrypted in [`secrets/`](secrets/) with age, committed to the repo, and deployed at boot into their home locations (`~/.ssh/*`, `~/.wakatime.cfg`) with `0600` permissions. The age key lives at `~/.config/sops/age/keys.txt` (for editing) and `/var/lib/sops-nix/key.txt` (for boot decryption) — they must be the same key.

Use the `secrets` util from the devshell:

```sh
$ nix develop
$ secrets add <name> <file>   # stage, encrypt, git add; warns if unregistered
$ secrets edit <name>         # decrypt, open $EDITOR, re-encrypt
$ secrets rename <old> <new>  # git mv, no re-encryption needed
$ secrets rm <name>           # remove a payload
$ secrets list                # encryption and registration status
```

New names must be registered in [`userSecrets`](sys/mods/core/secrets.nix) — and `deployPath` extended if they should not land in `~/.ssh/` — the util will remind you.

One-time migration from an old `/cred` partition: `./migrate-cred.sh`

# Try it out!
```
$ git clone git@github.com:yorqat/nixo.git
```

## Installing from a nixos live environment
* Since this is manual installation, consider reading on [nixos mount points]("https://nixos.org/manual/nixos/stable/index.html#sec-installation-manual-partitioning")

* Partitions should look like this on your live environment. Tip: I just turned on esp flag for boot partition using [gparted](https://gparted.org/)
```
/
├── mnt/
│   └── boot/
└── ...
```

> **Note:** Make sure you are cd'd correctly as it will override [hardware-configuration.nix](hardware-configuration.nix)
```sh
# Generate config to persist mount points
$ nixos-generate-config --root /mnt --show-hardware-config > hardware-configuration.nix

# Install on /mnt
# Replace <hostName> with your host name like .#qat
$ nixos-install --root /mnt --flake .#<hostName>
```

## Launch window manager
```sh
$ niri-session
```

## Rebuilding on changes

> **Note:** If you update hardware or change mount points just regenerate hardware configuration
> 
> `$ nixos-generate-config --show-hardware-config > hardware-configuration.nix`
```sh
$ nixos-rebuild switch --flake .#<hostName> -v
```


> **Warning:** Changing [`userName`](setup/default.nix) don't move your stuff but will create a new home directory.