#!/usr/bin/env bash
# One-time migration: /cred files -> sops-encrypted secrets/
# Safe to re-run; already-migrated files are skipped.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_DIR="${CRED_DIR:-/cred}"
KEY_FILE="/var/lib/sops-nix/key.txt"
USER_KEY="$HOME/.config/sops/age/keys.txt"
SECRETS_DIR="$ROOT/secrets"

log() { printf '%s\n' "==> $*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v sops >/dev/null || die "sops not found (enter the direnv shell, or: nix shell nixpkgs#sops nixpkgs#age)"
command -v age-keygen >/dev/null || die "age-keygen not found (enter the direnv shell, or: nix shell nixpkgs#sops nixpkgs#age)"
[ -d "$CRED_DIR/.ssh" ] || die "$CRED_DIR/.ssh not found; nothing to migrate (set CRED_DIR to override)"

# 1. age key: user copy for editing, root copy for sops-nix decryption
if [ ! -f "$USER_KEY" ]; then
  log "generating age key at $USER_KEY"
  mkdir -p "$(dirname "$USER_KEY")"
  chmod 700 "$(dirname "$USER_KEY")"
  age-keygen -o "$USER_KEY"
  chmod 600 "$USER_KEY"
fi

if [ -f "$KEY_FILE" ]; then
  root_pub="$(sudo cat "$KEY_FILE" | age-keygen -y)"
  user_pub="$(age-keygen -y "$USER_KEY")"
  [ "$root_pub" = "$user_pub" ] || die "$KEY_FILE and $USER_KEY are different keys; resolve manually"
else
  log "installing age key for sops-nix at $KEY_FILE"
  sudo install -d -m 700 /var/lib/sops-nix
  sudo install -m 600 "$USER_KEY" "$KEY_FILE"
fi
PUB="$(age-keygen -y "$USER_KEY")"

# 2. creation rules for sops
if [ ! -f "$ROOT/.sops.yaml" ]; then
  log "writing .sops.yaml"
  cat > "$ROOT/.sops.yaml" <<EOF
creation_rules:
  - path_regex: secrets/
    age: $PUB
EOF
fi

# 3. stage + encrypt (binary format: whole file is the secret)
mkdir -p "$SECRETS_DIR"
staged=0
stage() {
  local src="$1"
  local name dst
  name="$(basename "$src")"
  dst="$SECRETS_DIR/$name"
  if [ -e "$dst" ]; then
    log "skip $name (already migrated)"
    return
  fi
  log "encrypting $src -> secrets/$name"
  install -m 600 "$src" "$dst"
  if ! SOPS_AGE_KEY_FILE="$USER_KEY" sops --encrypt --in-place "$dst"; then
    rm -f "$dst"
    die "failed to encrypt $src"
  fi
  staged=$((staged + 1))
}

for f in "$CRED_DIR"/.ssh/*; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in
    *.old | authorized_keys*) continue ;;
  esac
  stage "$f"
done

if [ -f "$CRED_DIR/.wakatime.cfg" ]; then
  stage "$CRED_DIR/.wakatime.cfg"
fi

# 4. drop stale symlinks so sops deploys into real files
for link in "$HOME/.ssh" "$HOME/.wakatime.cfg"; do
  if [ -L "$link" ]; then
    log "removing stale symlink $link"
    rm "$link"
  fi
done

# 5. flakes only see tracked files
git -C "$ROOT" add .sops.yaml secrets/ 2>/dev/null || true

log "staged $staged new secret(s)"
printf '%s\n' \
  "next steps:" \
  "  1. review:    git diff --cached" \
  "  2. rebuild:   nixos-rebuild switch --flake .#qat" \
  "  3. verify:    ls -la ~/.ssh" \
  "  4. cleanup:   remove /cred from hardware-configuration.nix, wipe the partition" \
  "                (move /cred/Games and /cred/.ssh.pub elsewhere first)"
