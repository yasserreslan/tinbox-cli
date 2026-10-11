#!/bin/sh
# Unit tests and builds with the pinned Tin: the CLI for this machine and for Linux arm64 and x86-64.
# tests/e2e.sh runs two Macs against a real server on top (it needs Postgres and the tinbox server's checkout).
set -eu
cd "$(dirname "$0")/.."
for p in proto cli/home cli/settings cli/api cli/local cli/engine cli/agent cli/ui; do
  echo "== $p"
  ./tin test "./$p"
done
mkdir -p bin/linux-arm64 bin/linux-amd64
echo "== build"
./tin build cli/main.tin -o bin/tinbox
./tin build --target linux-arm64 cli/main.tin -o bin/linux-arm64/tinbox
./tin build --target linux-amd64 cli/main.tin -o bin/linux-amd64/tinbox
bin/tinbox version
