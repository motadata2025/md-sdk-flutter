# Motadata Flutter RUM SDK — docs

Motadata-branded Flutter RUM SDK, forked from `DataDog/dd-sdk-flutter` (Apache-2.0) and repointed to
the frozen, published Motadata Android SDK (`com.motadata:motadata-rum-android:1.0.1`).

**Scope this round:** Android only (iOS deferred), RUM-focused. Base tag `datadog_flutter_plugin/v3.4.1`.

| Doc | Purpose |
|---|---|
| [MOTADATA_FLUTTER_SDK_REBRAND_PLAN.md](MOTADATA_FLUTTER_SDK_REBRAND_PLAN.md) | Master plan: goal, decisions, scope, token map, phases, risks |
| [PROGRESS.md](PROGRESS.md) | Execution log (phase by phase, green CI run ids + commit SHAs) |
| [WORKFLOW.md](WORKFLOW.md) | CI runbook — the golden rule + `gh` commands |
| [functional-changes/](functional-changes/README.md) | Implement / skip / inherited analysis (exactly the RN set) |

## Non-negotiables
- **Golden rule:** nothing compiles on the laptop — all build/test/publish run on GitHub Actions via `gh`.
- **Android SDK is FROZEN** — we only *depend on* `com.motadata:motadata-rum-android:1.0.1`; never rebuild it.
- **Single branch `motadata-dev`** — rebrand + functional both land here (RN model); ships `1.0.0`.
- **Apache-2.0 attribution header** is the only whitelisted "Datadog" string on shipped surfaces.
- **Two shipping packages:** `motadata_flutter_plugin`, `motadata_tracking_http_client` → **pub.dev**.
