#!/bin/sh
# End to end: two Macs (each its own HOME) syncing one team's folder through a local tinbox server.
#   TINBOX_DB_URL=postgres://tinbox:tinbox@127.0.0.1:5432/tinbox?sslmode=disable tests/e2e.sh
# It builds the server from a checkout of github.com/yasserreslan/tinbox beside this one (TINBOX_SERVER_DIR).
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
server_dir=${TINBOX_SERVER_DIR:-$root/../tinbox}
port=${TINBOX_E2E_PORT:-18190}
url=http://127.0.0.1:$port
: "${TINBOX_DB_URL:?set TINBOX_DB_URL to a Postgres the test may use}"
work=$(mktemp -d /tmp/tin-test-tinbox-cli.XXXXXX)
cd "$root" && ./tin build cli/main.tin -o bin/tinbox
(cd "$server_dir" && ./tin build server/main.tin -o bin/tinbox)
cli=$root/bin/tinbox
srv=$server_dir/bin/tinbox
export TINBOX_STORE=dir TINBOX_STORE_DIR=$work/blocks TINBOX_LISTEN=127.0.0.1:$port TINBOX_PUBLIC_URL=$url
"$srv" migrate > /dev/null
team="cli-e2e-$$"
code=$("$srv" admin invite "a-$$@example.com" --team "$team" | awk '/TBI-/ { print $1 }')
"$srv" run > "$work/server.log" 2>&1 &
spid=$!
cleanup() { kill $spid 2>/dev/null || true; }
trap cleanup EXIT INT TERM
until curl -fs "$url/healthz" > /dev/null 2>&1; do sleep 0.1; done

passed=0
failed=0
ok() { passed=$((passed + 1)); echo "ok   $1"; }
bad() { failed=$((failed + 1)); echo "FAIL $1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
# A and B are two Macs: their own HOME, their own folder
mkdir -p "$work/a-home/.Trash" "$work/b-home/.Trash" "$work/a" "$work/b"
A() { (cd "$work/a" && HOME=$work/a-home "$cli" "$@"); }
B() { (cd "$work/b" && HOME=$work/b-home "$cli" "$@"); }
same() { diff -r -x .tinbox -x '.DS_Store' "$work/a" "$work/b" > /dev/null 2>&1; }

A login "$url" --invite "$code" --name "Mac A" > /dev/null
check "Mac A signs in with the invite" 'A whoami | grep -q "a-$$@example.com"'
# Mac B joins the same account by approval
(cd "$work/b" && HOME=$work/b-home "$cli" login "$url" --link --name "Mac B" > "$work/b-login.txt" 2>&1) &
lpid=$!
i=0
until grep -q "tinbox approve" "$work/b-login.txt" 2>/dev/null; do i=$((i + 1)); [ $i -lt 100 ] || break; sleep 0.1; done
linkcode=$(awk '/tinbox approve/ { print $NF }' "$work/b-login.txt" | sed 's/\x1b\[[0-9;]*m//g')
A approve "$linkcode" > /dev/null
wait $lpid
check "Mac B signs in by approval from Mac A" 'B whoami | grep -q "Mac B"'

# A's folder, with content
mkdir -p "$work/a/Docs/Notes"
printf 'hello\n' > "$work/a/Docs/hello.txt"
printf 'shared from A\n' > "$work/a/shared.txt"
printf '#!/bin/sh\necho hi\n' > "$work/a/run.sh"; chmod +x "$work/a/run.sh"
printf 'ignored' > "$work/a/.DS_Store"
head -c 3145728 /dev/urandom > "$work/a/big.bin"
A init --team "$team" --no-start > /dev/null
A sync > /dev/null
check "Mac A's first sync uploads (3 files; the big one is skipped)" 'A status --json | grep -q "\"files\":3"'
check "a file over 2 MB is skipped" 'A status --skipped | grep -q "big.bin"'
# B already has a file of its own, and a different shared.txt: the first sync deletes nothing
printf 'only on B\n' > "$work/b/b-only.txt"
printf 'shared from B\n' > "$work/b/shared.txt"
B init --no-start > /dev/null
B sync > /dev/null
check "Mac B gets A's files" '[ -f "$work/b/Docs/hello.txt" ] && [ -d "$work/b/Docs/Notes" ]'
check "the executable bit comes along" '[ -x "$work/b/run.sh" ]'
check "the big file stays on A" '[ ! -f "$work/b/big.bin" ]'
check "the first sync keeps B's own file" '[ -f "$work/b/b-only.txt" ]'
check "two different shared.txt: B keeps its own as a conflicted copy" 'ls "$work/b" | grep -q "shared (conflicted copy, Mac B"'
check "shared.txt is A's version" 'grep -q "from A" "$work/b/shared.txt"'
A sync > /dev/null
rm -f "$work/a/big.bin"
check "after both sync, both folders are the same" 'same'
check "status says it matches the server" 'A sync | grep -q "matches the server"'

# an edit on B reaches A
printf 'edited on B\n' >> "$work/b/Docs/hello.txt"
B sync > /dev/null; A sync > /dev/null
check "an edit on B reaches A" 'grep -q "edited on B" "$work/a/Docs/hello.txt"'
# both edit the same file
printf 'A wins?\n' > "$work/a/Docs/hello.txt"
sleep 1
printf 'B wins?\n' > "$work/b/Docs/hello.txt"
A sync > /dev/null; B sync > /dev/null; A sync > /dev/null
check "both edited: one version, plus a conflicted copy on both Macs" 'ls "$work/a/Docs" | grep -q "conflicted copy" && same'
# deletes
rm "$work/a/run.sh"
A sync > /dev/null; B sync > /dev/null
check "a delete on A reaches B" '[ ! -f "$work/b/run.sh" ]'
check "B's deleted file went to its Trash" 'ls "$work/b-home/.Trash" | grep -q "run.sh"'
rm -rf "$work/b/Docs/Notes"
B sync > /dev/null; A sync > /dev/null
check "a deleted folder on B goes on A" '[ ! -d "$work/a/Docs/Notes" ]'
# edit wins over delete
printf 'keep me\n' > "$work/a/keep.txt"
A sync > /dev/null; B sync > /dev/null
printf 'edited\n' >> "$work/a/keep.txt"
rm "$work/b/keep.txt"
A sync > /dev/null; B sync > /dev/null
check "an edit wins over a delete" 'grep -q edited "$work/b/keep.txt"'
# history
check "versions of a file" 'A versions Docs/hello.txt | grep -q "rev"'
A trash > "$work/trash.txt"
check "the trash lists the deleted file" 'grep -q "run.sh" "$work/trash.txt"'
A restore run.sh > /dev/null
A sync > /dev/null; B sync > /dev/null
check "a restored file comes back on both Macs" '[ -f "$work/a/run.sh" ] && [ -f "$work/b/run.sh" ]'
# the upload speed cap: 300 KB at 800kbps (100 KB/s) takes about 3 s
A config set upload-limit 800kbps --folder > /dev/null
head -c 307200 /dev/urandom > "$work/a/capped.bin"
t0=$(date +%s)
A sync > /dev/null
t1=$(date +%s)
check "the upload speed cap holds (took $((t1 - t0)) s, at least 2)" '[ $((t1 - t0)) -ge 2 ]'
B sync > /dev/null
check "the capped upload arrives intact" 'cmp -s "$work/a/capped.bin" "$work/b/capped.bin"'
check "settings show the folder's own limit" 'A config | grep -q "800kbps"'
# everything agrees at the end
A sync > /dev/null; B sync > /dev/null
check "in the end both folders are the same" 'same'
check "status renders" 'A status | grep -q "files"'
# the background agent: it syncs by itself, shows in status, and tinbox stop leaves nothing running
export TINBOX_NO_LAUNCHD=1
A config set scan-interval 1s > /dev/null
A start > /dev/null
check "tinbox start runs the agent" 'A status | grep -Eq "running|syncing|up to date"'
printf 'by the agent\n' > "$work/a/agent.txt"
i=0
until A status --json | grep -q '"files":7' || [ $i -gt 40 ]; do i=$((i + 1)); sleep 0.5; done
B sync > /dev/null
check "the agent uploads a new file by itself" '[ -f "$work/b/agent.txt" ]'
pid=$(A status --json | sed 's/.*"pid":\([0-9]*\).*/\1/')
A stop > /dev/null
check "tinbox stop ends the agent" '! kill -0 "$pid" 2>/dev/null'
check "status says stopped" 'A status | grep -q "stopped"'
unset TINBOX_NO_LAUNCHD
# signing out revokes the Mac
B logout > /dev/null
check "a signed-out Mac cannot sync" '! B sync > /dev/null 2>&1'

echo "$passed passed, $failed failed"
if [ $failed -gt 0 ]; then
  echo "--- work dir: $work"
  tail -20 "$work/server.log"
  exit 1
fi
rm -rf "$work"
