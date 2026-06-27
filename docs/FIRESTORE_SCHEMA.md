# Firestore Schema

Brainiax uses Firestore for cloud-sync metadata only. Firestore documents must
not contain puzzle boards, generated puzzle JSON, active run board state, solver
solutions, clue grids, user-entered board cells, or any other data that can
reconstruct an in-progress or solved board.

All documents include `schemaVersion`. The initial schema version is `1`.
Timestamps are stored as Firestore `Timestamp` values in UTC.

## Security Rules

Rules live at the repository root in `firestore.rules`; root `firebase.json`
points the Firebase CLI at `firestore.rules` and `firestore.indexes.json`.

The V1 rule assumptions are:

- `/users/{uid}` and its supported subcollections are private to
  `request.auth.uid == uid`.
- Client-writable user data is limited to the profile fields documented here,
  `/stats/{puzzleType}`, `/runs/{runId}`, and `/dailyStreak/state`.
- User preferences are stored as a `preferences` map on `/users/{uid}`, not as
  a separate subcollection.
- Client writes reject top-level admin/config fields such as `admin`, `isAdmin`,
  `roles`, `claims`, `config`, `remoteConfig`, and `featureFlags`.
- Client writes reject gameplay payload fields such as `board`, `cells`, `grid`,
  `generatedPuzzleJson`, `solution`, `activeRunState`, and `moves`.
- Leaderboard entries are publicly readable. Writes require authentication,
  path fields matching the document path, and payload `uid` matching
  `request.auth.uid`.
- Leaderboard client writes must leave `rank` absent or `null`; any materialized
  rank is treated as admin-maintained data.
- `/config/**` is readable by clients and not writable by clients.

`firestore.indexes.json` is intentionally empty for V1 because the current
Firestore providers only create document references and collection references;
no composite-query contract has been introduced yet.

### Emulator Validation

The repo includes a dependency-free Firestore rules probe:

```sh
firebase emulators:exec --only firestore --project demo-brainiax-puzzles "node bin/firestore_rules_probe.mjs"
```

If PowerShell splits the Firebase CLI wrapper arguments, call the Firebase CLI
JavaScript entrypoint directly:

```powershell
node "$env:APPDATA\npm\node_modules\firebase-tools\lib\bin\firebase.js" emulators:exec --only firestore --project demo-brainiax-puzzles "node bin/firestore_rules_probe.mjs"
```

The probe validates that owners can write their own metadata, other users cannot
read/write private metadata, `/config` writes are denied, leaderboard writes
require matching auth and payload UIDs, and gameplay/admin fields are rejected.

Manual emulator checklist for BX-0413:

- Run the probe command above against the local Firestore emulator, not a
  production Firebase project.
- Confirm owner-only profile access passes: `owner can write own profile`,
  `owner can read own profile`, `other user cannot read private profile`, and
  `other user cannot write private profile`.
- Confirm owner-only subcollection access passes for runs and stats:
  `owner can write own run`, `other user cannot write private run`,
  `owner can write own stats`, and `other user cannot read private stats`.
- Confirm constrained leaderboard writes pass: matching auth/payload/path fields
  are allowed, mismatched payload UID/path IDs are rejected, and client-provided
  `rank` is rejected.
- Confirm gameplay payload fields such as `board` remain rejected by the run
  write probe.

## Collections

### `/users/{uid}`

User profile and account-level preferences.

| Field | Type | Notes |
| --- | --- | --- |
| `schemaVersion` | number | Firestore schema version. |
| `uid` | string | Firebase Auth uid. |
| `createdAt` | Timestamp | First known account creation time. |
| `lastSeenAt` | Timestamp, null | Last app activity time. |
| `displayName` | string, null | Optional display name. |
| `isAnonymous` | boolean | Whether the auth user is anonymous. |
| `providerIds` | string[] | Auth provider ids. |
| `preferences` | map | User preferences metadata. |

`preferences` fields:

| Field | Type | Notes |
| --- | --- | --- |
| `favoritePuzzleTypes` | string[] | Puzzle type keys selected as favorites. |
| `preferredDifficulties` | map<string,string> | Preferred difficulty by puzzle type key. |
| `updatedAt` | Timestamp, null | Last preferences update time. |

### `/users/{uid}/stats/{puzzleType}`

Per-user aggregate completion stats for one puzzle type.

| Field | Type | Notes |
| --- | --- | --- |
| `schemaVersion` | number | Firestore schema version. |
| `uid` | string | Firebase Auth uid. |
| `puzzleType` | string | Puzzle type key and document id. |
| `totalCompletions` | number | Completed runs count. |
| `randomCompletions` | number | Random mode completed runs count. |
| `dailyCompletions` | number | Daily mode completed runs count. |
| `totalElapsedMs` | number | Sum of completed elapsed time. |
| `totalMoveCount` | number | Sum of moves. |
| `totalHintsUsed` | number | Sum of hints. |
| `bestElapsedMs` | number, null | Fastest completion. |
| `firstCompletedAt` | Timestamp, null | Earliest completed run. |
| `lastCompletedAt` | Timestamp, null | Latest completed run. |
| `byDifficulty` | map | Aggregate stats keyed by difficulty. |

Each `byDifficulty` value stores the same aggregate counters for that
difficulty, excluding `uid` and `puzzleType`.

### `/users/{uid}/runs/{runId}`

Completed run result metadata. This collection stores outcomes only; it does not
store in-progress board state.

| Field | Type | Notes |
| --- | --- | --- |
| `schemaVersion` | number | Firestore schema version. |
| `runId` | string | Completed run id and document id. |
| `uid` | string | Firebase Auth uid. |
| `puzzleType` | string | Puzzle type key. |
| `mode` | string | `daily` or `random`. |
| `difficulty` | string | Difficulty key/label. |
| `size` | string | Puzzle size label. |
| `dailyDateKeyUtc` | string, null | `YYYY-MM-DD` for daily runs. |
| `startedAt` | Timestamp, null | Run start time if known. |
| `completedAt` | Timestamp | Completion time. |
| `sessionUpdatedAt` | Timestamp, null | Last local session update time. |
| `elapsedMs` | number | Completion duration. |
| `moveCount` | number | User move count. |
| `hintsUsed` | number | Hints used. |

Do not add `board`, `cells`, `grid`, `generatedPuzzleJson`, `solution`,
`activeRunState`, `moves`, or seed-derived generated puzzle payload fields to
this document.

### `/users/{uid}/dailyStreak/state`

Current daily challenge streak state.

| Field | Type | Notes |
| --- | --- | --- |
| `schemaVersion` | number | Firestore schema version. |
| `uid` | string | Firebase Auth uid. |
| `currentStreak` | number | Current daily streak length. |
| `bestStreak` | number | Best daily streak length. |
| `lastCompletedDateKeyUtc` | string, null | Last completed daily date key. |
| `updatedAt` | Timestamp, null | Last streak update time. |

### `/leaderboards/{periodId}/puzzleTypes/{puzzleType}/entries/{entryId}`

Leaderboard entry metadata for one period and puzzle type.

| Field | Type | Notes |
| --- | --- | --- |
| `schemaVersion` | number | Firestore schema version. |
| `entryId` | string | Leaderboard entry id and document id. |
| `periodId` | string | Leaderboard period id. |
| `puzzleType` | string | Puzzle type key. |
| `uid` | string | Firebase Auth uid. |
| `displayName` | string, null | Optional display name. |
| `score` | number | Ranking score. |
| `rank` | number, null | Materialized rank when available. |
| `elapsedMs` | number | Completion duration. |
| `moveCount` | number | User move count. |
| `hintsUsed` | number | Hints used. |
| `difficulty` | string | Difficulty key/label. |
| `size` | string | Puzzle size label. |
| `completedAt` | Timestamp | Completion time. |
| `updatedAt` | Timestamp, null | Last leaderboard update time. |

### `/config/appConfig`

App-wide cloud configuration metadata.

| Field | Type | Notes |
| --- | --- | --- |
| `schemaVersion` | number | Firestore schema version. |
| `cloudSyncEnabled` | boolean | Enables cloud-sync clients. |
| `leaderboardsEnabled` | boolean | Enables leaderboard surfaces. |
| `minSupportedSchemaVersion` | number | Oldest schema version accepted. |
| `updatedAt` | Timestamp, null | Last config update time. |

## Prohibited Firestore Data

Firestore is not the storage layer for gameplay payloads. The following data
must remain local-only unless a future schema explicitly changes this policy:

- Puzzle boards and clue grids.
- Generated puzzle JSON.
- Active run board state or partial user entries.
- Solver solutions or answer keys.
- Raw move histories that reveal board state.
