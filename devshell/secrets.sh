#!/usr/bin/env bash
# repo devshell util for managing sops-nix payloads in secrets/
set -euo pipefail

REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  printf 'error: not inside the nixo repo\n' >&2
  exit 1
}
SECRETS="$REPO/secrets"
SETUP="$REPO/setup/default.nix"

usage() {
  cat <<'EOF'
usage: secrets <command> ...

commands:
  add <name> <file>   encrypt <file> into secrets/<name>
  edit <name>         decrypt, open $EDITOR, re-encrypt
  rename <old> <new>  rename a payload (no re-encryption needed)
  rm <name>           remove a payload
  list                show payload status and configuration
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

# lines of the `<key> = { ... };` attrset in setup/default.nix
attr_block() {
  awk -v key="$1" '
    $0 ~ key" *= *\\{" { on = 1; next }
    on && /\};/ { exit }
    on { print }
  ' "$SETUP"
}

# lines of the `<key> = [ ... ];` list in setup/default.nix
list_block() {
  awk -v key="$1" '
    $0 ~ key" *= *\\[" { on = 1 }
    on { print }
    on && /\];/ { exit }
  ' "$SETUP"
}

# pinned home-relative deploy path, empty if none
pinned_path() {
  attr_block deployPaths | grep -F "\"$1\" =" |
    sed -E 's/^[^=]*= *"([^"]*)".*/\1/'
}

# env var name the payload is exported as, empty if none
env_var_for() {
  attr_block envNames | grep -F "\"$1\" =" |
    sed -E 's/^[^=]*= *"([^"]*)".*/\1/'
}

is_root_secret() {
  list_block root | grep -Fq "\"$1\""
}

is_tracked() {
  git -C "$REPO" ls-files --error-unmatch -- "secrets/$1" >/dev/null 2>&1
}

deploy_dest() {
  local pin
  pin="$(pinned_path "$1" || true)"
  if [ -n "$pin" ]; then
    printf '~/%s' "$pin"
  else
    printf '~/.config/secrets/%s' "$1"
  fi
}

hint_env() {
  printf 'note: "%s" deploys to %s\n' "$1" "$(deploy_dest "$1")"
  printf '      to export it as an env var, add      "%s" = "<VAR>" to setup.secrets.envNames\n' "$1"
  printf '      to deploy elsewhere, add             "%s" = "<path>" to setup.secrets.deployPaths\n' "$1"
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
    hint_env "$name"
    printf 'rebuild to deploy: sudo nixos-rebuild switch --flake .#qat\n'
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
    if is_tracked "$old"; then
      git -C "$REPO" mv "secrets/$old" "secrets/$new"
    else
      mv "$SECRETS/$old" "$SECRETS/$new"
    fi
    printf 'renamed secrets/%s -> secrets/%s (re-encryption not needed)\n' "$old" "$new"
    if [ -n "$(pinned_path "$old" || true)" ] || [ -n "$(env_var_for "$old" || true)" ]; then
      printf 'note: update "%s" keys in setup.secrets (setup/default.nix)\n' "$old"
    fi
    printf 'rebuild to deploy: sudo nixos-rebuild switch --flake .#qat\n'
    ;;
  rm)
    [ $# -eq 1 ] || die "usage: secrets rm <name>"
    name="$1"
    [ -f "$SECRETS/$name" ] || die "no such secret: $name"
    if is_tracked "$name"; then
      git -C "$REPO" rm -qf "secrets/$name"
    else
      rm -f "$SECRETS/$name"
    fi
    printf 'removed secrets/%s\n' "$name"
    if [ -n "$(pinned_path "$name" || true)" ] || [ -n "$(env_var_for "$name" || true)" ]; then
      printf 'note: remove "%s" from setup.secrets (setup/default.nix)\n' "$name"
    fi
    ;;
  list)
    printf '%-24s %-10s %-10s %s\n' 'PAYLOAD' 'ENCRYPTED' 'GIT' 'DEPLOY / ENV'
    for f in "$SECRETS"/*; do
      name="$(basename "$f")"
      [ "$name" = ".gitkeep" ] && continue
      if encrypted "$f"; then enc=yes; else enc=NO; fi
      if is_tracked "$name"; then git_=yes; else git_=NO; fi
      if is_root_secret "$name"; then
        dest='root (neededForUsers)'
      else
        dest="$(deploy_dest "$name")"
      fi
      var="$(env_var_for "$name" || true)"
      [ -n "$var" ] && dest="$dest [$var]"
      printf '%-24s %-10s %-10s %s\n' "$name" "$enc" "$git_" "$dest"
    done
    ;;
  *)
    usage
    exit 1
    ;;
esac
