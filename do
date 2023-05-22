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
    *)
        ./do --install
        ;;
esac