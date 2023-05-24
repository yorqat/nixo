#!/usr/bin/env bash

case "$1" in
    "--install")
        echo "Performing installation..."
        sudo nixos-rebuild switch --flake .#qaten
        ;;
    "--gen-hardware")
        echo "Generating hardware information..."
        sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
        ;;
    "--meta-install")
        echo "Installing on /mnt"
        sudo nixos-generate-config --root /mnt --show-hardware-config > hardware-configuration.nix
        sudo nixos-install --root /mnt --flake .#qaten
        ;;
    *)
        ./do --install
        ;;
esac