#!/bin/sh
# Copies proto/ from a checkout of the tinbox server (TINBOX_SERVER_DIR, default ../tinbox), the one place it is
# changed. Commit the copy with a message naming the server commit it came from.
set -eu
cd "$(dirname "$0")/.."
src=${TINBOX_SERVER_DIR:-../tinbox}
awk 'NR == 1 { print; print ""; print "// Copied from the tinbox server (github.com/yasserreslan/tinbox, proto/): the hash layout, the signing text and the"; print "// JSON shapes both sides use. scripts/sync-proto.sh copies it again; never change it here alone."; next } { print }' "$src/proto/proto.tin" > proto/proto.tin
cp "$src/proto/proto_test.tin" proto/proto_test.tin
./tin test ./proto
echo "proto/ is now the server's at $(git -C "$src" rev-parse --short HEAD)"
