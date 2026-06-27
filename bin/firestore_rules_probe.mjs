const projectId =
  process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  'demo-brainiax-puzzles';
const host = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const base =
  `http://${host}/v1/projects/${projectId}/databases/(default)/documents`;

function b64url(value) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function token(uid) {
  return `${b64url({alg: 'none', typ: 'JWT'})}.${b64url({
    aud: projectId,
    auth_time: 0,
    exp: 4102444800,
    iat: 0,
    iss: `https://securetoken.google.com/${projectId}`,
    sub: uid,
    user_id: uid,
    firebase: {sign_in_provider: 'custom'},
  })}.`;
}

function headers(uid) {
  const result = {'Content-Type': 'application/json'};
  if (uid) {
    result.Authorization = `Bearer ${token(uid)}`;
  }
  return result;
}

const value = {
  int: (item) => ({integerValue: String(item)}),
  str: (item) => ({stringValue: item}),
  bool: (item) => ({booleanValue: item}),
  ts: (item) => ({timestampValue: item}),
  null: () => ({nullValue: null}),
  arr: (items) => ({arrayValue: {values: items}}),
  map: (fields) => ({mapValue: {fields}}),
};

async function request(method, path, uid, fields) {
  const options = {method, headers: headers(uid)};
  if (fields) {
    options.body = JSON.stringify({fields});
  }
  return fetch(`${base}/${path}`, options);
}

async function expectStatus(label, expected, promise) {
  const response = await promise;
  if (response.status !== expected) {
    const text = await response.text();
    throw new Error(
      `${label}: expected ${expected}, got ${response.status}: ${text}`,
    );
  }
  console.log(`${label}: ${response.status}`);
}

async function expectNotForbidden(label, promise) {
  const response = await promise;
  if (response.status === 403) {
    const text = await response.text();
    throw new Error(`${label}: expected non-403 response: ${text}`);
  }
  console.log(`${label}: ${response.status}`);
}

function profileFields(uid) {
  return {
    schemaVersion: value.int(1),
    uid: value.str(uid),
    createdAt: value.ts('2026-06-27T00:00:00Z'),
    lastSeenAt: value.ts('2026-06-27T00:01:00Z'),
    displayName: value.str('Ada'),
    isAnonymous: value.bool(false),
    providerIds: value.arr([value.str('password')]),
    preferences: value.map({
      favoritePuzzleTypes: value.arr([value.str('sudoku_classic')]),
      preferredDifficulties: value.map({sudoku_classic: value.str('hard')}),
      updatedAt: value.ts('2026-06-27T00:02:00Z'),
    }),
  };
}

function runFields(uid, runId) {
  return {
    schemaVersion: value.int(1),
    runId: value.str(runId),
    uid: value.str(uid),
    puzzleType: value.str('sudoku_classic'),
    mode: value.str('daily'),
    difficulty: value.str('hard'),
    size: value.str('9x9'),
    dailyDateKeyUtc: value.str('2026-06-27'),
    startedAt: value.ts('2026-06-27T00:00:00Z'),
    completedAt: value.ts('2026-06-27T00:05:00Z'),
    sessionUpdatedAt: value.ts('2026-06-27T00:04:00Z'),
    elapsedMs: value.int(300000),
    moveCount: value.int(45),
    hintsUsed: value.int(1),
  };
}

function statsFields(uid, puzzleType) {
  return {
    schemaVersion: value.int(1),
    uid: value.str(uid),
    puzzleType: value.str(puzzleType),
    totalCompletions: value.int(1),
    randomCompletions: value.int(0),
    dailyCompletions: value.int(1),
    totalElapsedMs: value.int(300000),
    totalMoveCount: value.int(45),
    totalHintsUsed: value.int(1),
    bestElapsedMs: value.int(300000),
    firstCompletedAt: value.ts('2026-06-27T00:05:00Z'),
    lastCompletedAt: value.ts('2026-06-27T00:05:00Z'),
    byDifficulty: value.map({}),
  };
}

function leaderboardFields(uid, entryId = 'entry-1') {
  return {
    schemaVersion: value.int(1),
    entryId: value.str(entryId),
    periodId: value.str('2026-06'),
    puzzleType: value.str('sudoku_classic'),
    uid: value.str(uid),
    displayName: value.str('Ada'),
    score: value.int(1000),
    rank: value.null(),
    elapsedMs: value.int(300000),
    moveCount: value.int(45),
    hintsUsed: value.int(1),
    difficulty: value.str('hard'),
    size: value.str('9x9'),
    completedAt: value.ts('2026-06-27T00:05:00Z'),
    updatedAt: value.ts('2026-06-27T00:06:00Z'),
  };
}

await expectStatus(
  'owner can write own profile',
  200,
  request('PATCH', 'users/alice', 'alice', profileFields('alice')),
);
await expectStatus(
  'owner can read own profile',
  200,
  request('GET', 'users/alice', 'alice'),
);
await expectStatus(
  'other user cannot read private profile',
  403,
  request('GET', 'users/alice', 'bob'),
);
await expectStatus(
  'other user cannot write private profile',
  403,
  request('PATCH', 'users/alice', 'bob', profileFields('alice')),
);
await expectStatus(
  'unauthenticated user cannot write profile',
  403,
  request('PATCH', 'users/guest', null, profileFields('guest')),
);
await expectStatus(
  'profile write rejects admin fields',
  403,
  request('PATCH', 'users/alice', 'alice', {
    ...profileFields('alice'),
    isAdmin: value.bool(true),
  }),
);
await expectStatus(
  'owner can write own run',
  200,
  request('PATCH', 'users/alice/runs/run-1', 'alice', runFields('alice', 'run-1')),
);
await expectStatus(
  'other user cannot write private run',
  403,
  request('PATCH', 'users/bob/runs/run-2', 'alice', runFields('bob', 'run-2')),
);
await expectStatus(
  'owner can write own stats',
  200,
  request(
    'PATCH',
    'users/bob/stats/sudoku_classic',
    'bob',
    statsFields('bob', 'sudoku_classic'),
  ),
);
await expectStatus(
  'other user cannot read private stats',
  403,
  request('GET', 'users/bob/stats/sudoku_classic', 'alice'),
);
await expectNotForbidden(
  'config read is allowed',
  request('GET', 'config/appConfig'),
);
await expectStatus(
  'config write is denied',
  403,
  request('PATCH', 'config/appConfig', 'alice', {
    schemaVersion: value.int(1),
    cloudSyncEnabled: value.bool(true),
  }),
);
await expectStatus(
  'leaderboard write allows matching auth uid',
  200,
  request(
    'PATCH',
    'leaderboards/2026-06/puzzleTypes/sudoku_classic/entries/entry-1',
    'alice',
    leaderboardFields('alice'),
  ),
);
await expectStatus(
  'leaderboard write rejects mismatched payload uid',
  403,
  request(
    'PATCH',
    'leaderboards/2026-06/puzzleTypes/sudoku_classic/entries/entry-2',
    'alice',
    leaderboardFields('bob', 'entry-2'),
  ),
);
await expectStatus(
  'leaderboard write rejects mismatched path period',
  403,
  request(
    'PATCH',
    'leaderboards/2026-07/puzzleTypes/sudoku_classic/entries/entry-3',
    'alice',
    leaderboardFields('alice', 'entry-3'),
  ),
);
await expectStatus(
  'leaderboard write rejects mismatched path entry id',
  403,
  request(
    'PATCH',
    'leaderboards/2026-06/puzzleTypes/sudoku_classic/entries/entry-4',
    'alice',
    leaderboardFields('alice', 'entry-mismatch'),
  ),
);
await expectStatus(
  'leaderboard write rejects client rank',
  403,
  request(
    'PATCH',
    'leaderboards/2026-06/puzzleTypes/sudoku_classic/entries/entry-5',
    'alice',
    {
      ...leaderboardFields('alice', 'entry-5'),
      rank: value.int(1),
    },
  ),
);
await expectStatus(
  'run write rejects gameplay payload fields',
  403,
  request('PATCH', 'users/alice/runs/run-3', 'alice', {
    ...runFields('alice', 'run-3'),
    board: value.str('not allowed'),
  }),
);
