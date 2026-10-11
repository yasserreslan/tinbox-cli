# Agent instructions

The tinbox CLI is written in Tin. Build only through `./tin` (the release in `TIN_VERSION`); `scripts/tin-update.sh`
moves the pin after everything passes, and the bump is committed on its own.

- `proto/` is a copy of the server's (github.com/yasserreslan/tinbox): change it there, then `scripts/sync-proto.sh`.
- The sync engine (`cli/engine`) must never delete when its base cannot be trusted, must let edits win over deletes,
  and must check a downloaded file's hash before it replaces anything. `cli/engine/engine_test.tin` holds the decision
  table; extend it with every rule you add.
- This repository is public: never commit a server URL, key, invite code or credential, real or for tests.
- Before a commit: `scripts/test.sh`, and `tests/e2e.sh` against a local server when you change syncing.
- A version is released by tagging it (`git tag vX.Y.Z`); the tag must equal `version` in `cli/main.tin`.
