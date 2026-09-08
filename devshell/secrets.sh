#!/usr/bin/env bash
# repo devshell util for managing sops-nix payloads in secrets/
set -euo pipefail

REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'error: not inside the nixo repo\n' >&2
  exit 1
}
SECRETS="$REPO/secrets"
MODULE="$REPO/sys/mods/core/secrets.nix"

usage() {
  cat <<'EOF'
usage: secrets <command> ...

commands:
  add <name> <file>   encrypt <file> into secrets/<name>
  edit <name>         decrypt, open $EDITOR, re-encrypt
  rename <old> <new>  rename a payload (no re-encryption needed)
  rm <name>           remove a payload
  list                show payload status and registration
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

registered() {
  grep -q "\"$1\"" "$MODULE"
}

registration_hint() {
  printf 'note: "%s" is not registered\n' "$1"
  printf '      add it to userSecrets in sys/mods/core/secrets.nix\n'
  printf '      and extend deployPath if it should not land in ~/.ssh/%s\n' "$1"
}

encrypted() {
  grep -q '"sops"' "$1"
}

cmd="${1:-}"
if [ $# -gt 0 ]; then
  shift
fi

case "$cmd" in
  add)
    [ $# -eq 2 ] || die "usage: secrets add <name> <file>"
    name="$1"
    src="$2"
    case "$name" in
      "" | .* | */*) die "invalid name: $name" ;;
    esac
    [ -f "$src" ] || die "no such file: $src"
    dst="$SECRETS/$name"
    if [ -e "$dst" ]; then
      die "secrets/$name already exists (use: secrets edit $name)"
    fi
    install -m 600 "$src" "$dst"
    if ! sops --encrypt --in-place "$dst"; then
      rm -f "$dst"
      die "encryption failed"
    fi
    git -C "$REPO" add "$dst"
    printf 'encrypted secrets/%s\n' "$name"
    if registered "$name"; then
      printf 'rebuild to deploy: sudo nixos-rebuild switch --flake .#qat\n'
    else
      registration_hint "$name"
    fi
    ;;
  edit)
    [ $# -eq 1 ] || die "usage: secrets edit <name>"
    name="$1"
    dst="$SECRETS/$name"
    [ -f "$dst" ] || die "no such secret: $name"
    sops "$dst"
    git -C "$REPO" add "$dst"
    printf 'updated secrets/%s\n' "$name"
    ;;
  rename)
    [ $# -eq 2 ] || die "usage: secrets rename <old> <new>"
    old="$1"
    new="$2"
    [ -f "$SECRETS/$old" ] || die "no such secret: $old"
    if [ -e "$SECRETS/$new" ]; then
      die "secrets/$new already exists"
    fi
    case "$new" in
      "" | .* | */*) die "invalid name: $new" ;;
    esac
    if git -C "$REPO" ls-files --error-unmatch "secrets/$old" >/dev/null 2>&1; then
      git -C "$REPO" mv "secrets/$old" "secrets/$new"
    else
      mv "$SECRETS/$old" "$SECRETS/$new"
    fi
    printf 'renamed secrets/%s -> secrets/%s (re-encryption not needed)\n' "$old" "$new"
    if registered "$new"; then
      printf 'rebuild to deploy: sudo nixos-rebuild switch --flake .#qat\n'
    else
      registration_hint "$new"
    fi
    ;;
  rm)
    [ $# -eq 1 ] || die "usage: secrets rm <name>"
    name="$1"
    [ -f "$SECRETS/$name" ] || die "no such secret: $name"
    if git -C "$REPO" ls-files --error-unmatch "secrets/$name" >/dev/null 2>&1; then
      git -C "$REPO" rm -qf "secrets/$name"
    else
      rm -f "$SECRETS/$name"
    fi
    printf 'removed secrets/%s\n' "$name"
    if registered "$name"; then
      printf 'note: remove "%s" from userSecrets in sys/mods/core/secrets.nix\n' "$name"
    fi
    ;;
  list)
    for f in "$SECRETS"/*; do
      name="$(basename "$f")"
      [ "$name" = ".gitkeep" ] && continue
      if encrypted "$f"; then
        enc=yes
      else
        enc=NO
      fi
      if registered "$name"; then
        reg=yes
      else
        reg=no
      fi
      printf '%-24s encrypted:%-4s registered:%s\n' "$name" "$enc" "$reg"
    done
    ;;
  *)
    usage
    exit 1
    ;;
esac
