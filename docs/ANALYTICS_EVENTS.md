# Analytics Events

Phase 4 analytics covers gameplay, profile/account, auth bootstrap/linking, and
sync outcomes. Analytics payloads must stay metadata-only and must not include
puzzle boards, generated puzzle JSON, clue grids, solver solutions,
user-entered cells, move histories, or raw sync payloads.

## Covered In Phase 4

| Area | Events |
| --- | --- |
| App/profile | `app_open`, `profile_viewed` |
| Puzzle play | `puzzle_started`, `puzzle_completed`, `hint_used` |
| Daily Challenge | `daily_started`, `daily_completed` |
| Account prompt | `auth_upgrade_prompt_shown` |
| Anonymous auth bootstrap | `auth_anonymous_bootstrap_started`, `auth_anonymous_bootstrap_succeeded`, `auth_anonymous_bootstrap_failed` |
| Google/Apple account flows | `auth_link_started`, `auth_link_succeeded`, `auth_link_failed`, `auth_link_cancelled`, `auth_link_unavailable`, `auth_sign_in_started`, `auth_sign_in_succeeded`, `auth_sign_in_failed`, `auth_sign_in_cancelled`, `auth_sign_in_unavailable` |
| Sync | `sync_succeeded`, `sync_failed` |

Auth link events use `upgrade_path=anonymous_link`. Direct provider sign-in
events use `upgrade_path=direct_sign_in`.

## Deferred

Ad analytics are Phase 5/deferred because banner and rewarded ad surfaces are
not implemented in Phase 4.

Onboarding analytics are not applicable in Phase 4 because there is no real
onboarding surface to instrument. Do not emit synthetic onboarding events until
that product flow exists.
