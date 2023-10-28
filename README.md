# YorPuter
A pretty cool system on wayland with some cool widgets.

<img src="wall.png" alt="my current wallpaper" width="100%">

<br />

# Required directories
Since these are located at `/` it would be desirable if these are mountpoints or symlinks.
.

> **Note:** Ability to change locations rolling out soon.

## [`/dat`](usrs/default.nix#L31)
Home folders: `Desktop`, `Documents`, `Videos`, `Pictures`, `Music`
## [`/cred`](usrs/default.nix#L38)
Secrets like `.ssh` and `.wakatime.cfg`
```

# Try it out!
```sh
$ git clone https://github.com/YorQat/my-nixos/
$ chmod +x do
$ ./do --gen-hardware # Generate hardware configuration first
$ ./do --install
```

## Install from another nixos machine/live environment
Since this is manual installation, consider reading on [nixos mount points]("https://nixos.org/manual/nixos/stable/index.html#sec-installation-manual-partitioning")
```sh
$ ./do --meta-install # installs on /mnt
```

## Launch window manager
```sh
$ Hyprland
```

> **Warning:** Changing [`userName`](setup/default.nix#L16) don't move your stuff but will create a new home directory I'm almost sure of it.