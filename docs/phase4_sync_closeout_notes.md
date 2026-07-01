# Phase 4 sync closeout notes

Failed sync items are retried before pending items are processed from startup,
app resume, Profile manual sync, and the sync trigger service's explicit flush
path.

There is no connectivity-restored listener in the current app dependency stack.
Phase 4 deliberately defers a network-restored trigger rather than adding a new
connectivity dependency during closeout. Failed items remain durable in the
local queue and are retried by the next startup, resume, manual, or explicit
sync-trigger flush.

The coverage command excludes `apps/app/test/performance/performance_test.dart`
and `apps/app/test/integration/app_flow_test.dart`. The frame-timing tests are
device/runtime-sensitive and caused Flutter coverage collection to hang after the
skipped performance isolate disappeared. The app-flow test now uses the normal
widget-test binding and passes in `melos test`, but it still makes combined
Flutter coverage collection lose the test isolate when run after the wider app
suite. Performance validation remains covered by `melos run perf_gate`; the app
coverage command writes the real `apps/app/coverage/lcov.info` file through
`flutter test --coverage`.
