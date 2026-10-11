# tinbox CLI

Keep a folder on your Mac in sync with a tinbox server: every Mac on your team sees the same files, like iCloud
Drive. Written in [Tin](https://github.com/yasserreslan/tin).

```sh
curl -fsSL https://raw.githubusercontent.com/yasserreslan/tinbox-cli/main/install.sh | sh
```

That installs `tinbox` in `~/.local/bin` after checking it against the release's SHA256SUMS. Apple silicon Macs and
Linux (arm64, x86-64). `tinbox update` installs newer releases; `tinbox uninstall` removes it.

## Start

```sh
tinbox login https://your-server --invite TBI-XXXX-XXXX-XXXX-XXXX-XXXX   # or no --invite: approve from another Mac
mkdir ~/Tinbox && cd ~/Tinbox
tinbox init                                                               # link it to your team and start syncing
tinbox status                                                             # what is happening
```

`tinbox init` starts the background agent: it keeps syncing after the terminal closes and starts again at login.
`tinbox stop` turns everything off, so nothing of tinbox runs; `tinbox start` turns it back on.

## Commands

| | |
|---|---|
| `tinbox login SERVER [--invite CODE]` | sign this Mac in; without a code it shows one to approve on a signed-in Mac |
| `tinbox logout` | revoke this Mac and forget its key |
| `tinbox whoami` · `tinbox devices [revoke ID]` · `tinbox approve CODE` | you and your Macs |
| `tinbox teams` · `tinbox team create NAME` · `tinbox invite EMAIL [--team T] [--role owner\|member]` · `tinbox members` | teams |
| `tinbox init [--team T]` · `tinbox unlink` | link this folder, or stop syncing it (its files stay) |
| `tinbox status [--watch\|--skipped\|--json]` · `tinbox log` | what is happening, and what was synced |
| `tinbox start` · `tinbox stop` · `tinbox pause\|resume [--folder]` | the background agent |
| `tinbox sync [--confirm-deletes]` | one sync by hand, while the agent is stopped |
| `tinbox versions FILE` · `tinbox restore FILE [--rev N]` · `tinbox trash` · `tinbox rewind SEQ` | history (30 days) |
| `tinbox config [set KEY VALUE \| unset KEY] [--folder]` | settings |

## Settings

| key | default | |
|---|---|---|
| `max-file-size` | `2MB` | larger files are not uploaded; `tinbox status --skipped` lists them (`0`: no limit) |
| `upload-limit` | `50kbps` | the upload speed cap: `50kbps`, `2mbps` (bits), `50KB/s`, `1MB/s` (bytes), `0` for none |
| `download-limit` | `0` | the same for downloads |
| `scan-interval` | `5s` | how often folders are checked for changes |

`tinbox config set upload-limit 1MB/s` sets it for every folder; add `--folder` inside a folder for that one only.
Files matching a line of the folder's `.tinboxignore` (`*.log`, `build/`) are not synced, nor are `.DS_Store`,
`._*` and the other files macOS leaves around.

## How it syncs

Each sync compares three things for every path: the folder on this Mac, the server's copy, and what both last agreed
on. A change on one side goes to the other. Two different edits keep both: yours becomes
`name (conflicted copy, Mac, date).ext`. An edit wins over a delete. The first sync of a folder, or one after the
server was restored from a backup, never deletes anything. Deleted files go to the Trash, and the server keeps 30 days
of versions and deletes. A folder that suddenly looks empty (an unmounted disk) is not emptied on the server.
"✓ matches the server" in `tinbox status` means the folder's Merkle hash equals the server's: the two are identical.

Your key and settings live in `~/.config/tinbox`, readable by you alone; each folder keeps its sync state in a hidden
`.tinbox` directory.

## Building

```sh
./tin build cli/main.tin -o bin/tinbox   # ./tin runs the Tin release in TIN_VERSION, installing it the first time
scripts/test.sh                          # unit tests and builds
tests/e2e.sh                             # two Macs against a real server (needs Postgres and the server's checkout)
scripts/tin-update.sh                    # move to a newer Tin, only if everything passes
```
