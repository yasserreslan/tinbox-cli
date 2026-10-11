#!/bin/sh
# Installs the tinbox CLI: a release from github.com/yasserreslan/tinbox-cli, checked against its SHA256SUMS,
# into ~/.local/bin (TINBOX_INSTALL_DIR overrides it).
#   curl -fsSL https://raw.githubusercontent.com/yasserreslan/tinbox-cli/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/yasserreslan/tinbox-cli/main/install.sh | sh -s 0.1.0
set -eu
repo=yasserreslan/tinbox-cli
dir=${TINBOX_INSTALL_DIR:-$HOME/.local/bin}
version=${1:-latest}
case $(uname -s) in Darwin) os=darwin ;; Linux) os=linux ;; *) echo 'tinbox: this system is not supported' >&2; exit 1 ;; esac
case $(uname -m) in arm64|aarch64) arch=arm64 ;; x86_64|amd64) arch=amd64 ;; *) echo 'tinbox: this CPU is not supported' >&2; exit 1 ;; esac
if [ "$os-$arch" = darwin-amd64 ]; then
  echo 'tinbox: Intel Macs are not supported, only Apple silicon' >&2
  exit 1
fi
asset=tinbox-$os-$arch
if [ "$version" = latest ]; then
  base=https://github.com/$repo/releases/latest/download
else
  base=https://github.com/$repo/releases/download/v${version#v}
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
curl -fsSL "$base/SHA256SUMS" -o "$work/SHA256SUMS"
curl -fsSL "$base/$asset" -o "$work/$asset"
want=$(awk -v a="$asset" '$2 == a { print $1 }' "$work/SHA256SUMS")
if command -v sha256sum > /dev/null 2>&1; then
  got=$(sha256sum "$work/$asset" | awk '{ print $1 }')
else
  got=$(shasum -a 256 "$work/$asset" | awk '{ print $1 }')
fi
if [ -z "$want" ] || [ "$want" != "$got" ]; then
  echo 'tinbox: the download does not match SHA256SUMS; nothing installed' >&2
  exit 1
fi
mkdir -p "$dir"
chmod +x "$work/$asset"
mv "$work/$asset" "$dir/tinbox"
echo "Installed $("$dir/tinbox" version) in $dir/tinbox"
case ":$PATH:" in
  *":$dir:"*) ;;
  *) echo "Add it to your PATH:  echo 'export PATH=\"$dir:\$PATH\"' >> ~/.zshrc && exec zsh" ;;
esac
echo 'Next: tinbox login SERVER_URL --invite CODE'
