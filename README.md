# Yor Puter
contains my system configuration and dotfiles proudly in NixOs. For personal use only obviously.

<img src="wall.png" alt="my current wallpaper" width="100%">

<br />

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