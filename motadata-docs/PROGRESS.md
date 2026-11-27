# Progress log

Living status tracker. Each phase cites the green CI run id + commit SHA that closed its gate.
Status key: ✅ done · 🔄 in progress · ⬜ not started.

## Phase 0 — Repo & CI bootstrap  (✅ DONE, 2026-11-23)
- ✅ Studied Android (`md-sdk-android`) + RN (`md-sdk-reactnative`) reference repos; distilled the
  go-gated `gh` methodology into this repo's docs.
- ✅ Locked decisions (see REBRAND_PLAN §1): fork base **`datadog_flutter_plugin/v3.4.1`** (Dart `^3.6.0`,
  Flutter `≥3.27.0`); **RUM-only**, Android-only; wire source **`mdsource=flutter`**; native dep
  **`com.motadata:motadata-rum-android:1.0.1`**; single branch **`motadata-dev`** → ships `1.0.0`;
  publish to **pub.dev** via OIDC.
- ✅ Created public repo `motadata2025/md-sdk-flutter`; base = untouched upstream `datadog_flutter_plugin/v3.4.1`
  tree (commit `1e67e8ad`); single branch `motadata-dev` (default); remotes `origin`=Motadata, `upstream`=DataDog.
- ✅ Seeded `motadata-docs/` (this plan, README, WORKFLOW, PROGRESS, functional-changes/).
- ✅ Authored CI: `motadata-build`, `motadata-test`, `motadata-nodatadog`, `motadata-publish`,
  `codeql-analysis` (scoped to the 2 shipping packages). Upstream `stale.yml` removed.
- ✅ **CI shake-out (untouched base):** pinned **Flutter 3.44.7** (stable current on the tag's 2026-07-20
  date; latest 3.50+ breaks on the "built-in Kotlin" migration the legacy-KGP example apps aren't ready for);
  scoped `analyze` to `lib`; generated a placeholder `.env` (flutter_dotenv asset) for the example APK build.
- ✅ **GATE GREEN on untouched base (commit `daa7873c`):** `motadata-build` run `45186520003` (both example
  APKs compile; native dep resolves) + `motadata-test` run `45186520115` (both packages' Dart tests pass).
  CodeQL green on prior same-source commit. Source tree still DataDog — this proves the pipeline before Phase 1.
  - `motadata-nodatadog` is EXPECTED RED here (base is DataDog) — dispatch-only until Phase 1.
- ✅ Added `paths-ignore: motadata-docs/**` to build/test so docs commits don't burn a full APK build.

## Phase 1 — Rebrand / repoint native / zero-datadog  (✅ DONE, 2026-11-27)
- ✅ Trimmed to the 2 shipping packages (+ `motadata_common_test`); deleted the 8 dropped packages
  (session_replay, webview, inappwebview, dio, grpc, gql, flags) and all Datadog dev/release tooling.
- ✅ Dropped **iOS** (native Swift dir; Android-only), **Web** (self-contained), **Logs** and **NDK**
  (no Motadata native module → public Logs API, NDK crash path, log mappers, Kotlin logs plugin all removed).
- ✅ Full rebrand per the token map across Dart + Android Kotlin + method channels + pubspecs via a
  uniform content+path pass (`Datadog→Motadata`, `com.datadoghq.flutter→com.motadata.flutter`,
  native `com.datadog.android→com.motadata.android` incl. `DatadogSite→MotadataSite`,
  `DatadogContext→MotadataContext`, channel `datadog_sdk_flutter→motadata_sdk_flutter`, `DdRum→MdRum`,
  lowercase `ddrum→mdrum`). jnigen JNI runtime paths match the frozen native by construction
  (verified against the cached AARs).
- ✅ Repointed Android dep → `com.motadata:motadata-rum-android:1.0.1` (drop logs/ndk). Set source
  via the kept `_dd.source` config key → `flutter`. Added the `motadata_tracking_http_client` →
  `motadata_flutter_plugin` path override.
- ✅ Gate whitelist intentionally keeps (wire/native identifiers the frozen native owns, documented in
  `PHASE1_EXECUTION_NOTES.md`): Apache attribution header, `_dd.*` config keys, `x-datadog-*` APM
  propagation headers, and the native method name `getDatadogContext`.
- ✅ **GATE GREEN (commit `fb61ac28`):** `motadata-nodatadog` run `45980909699` (zero datadog on
  shipped surfaces) + `motadata-build` run `45980909463` (both example APKs compile; native dep
  resolves; Kotlin compiles against the fork) + `motadata-test` run `45980909538` (Dart tests pass).
  Publishable as `1.0.0`.
  - CodeQL (`45980909656`) is RED — informational only (java-kotlin autobuild hits transient Maven
    fetches on the example gradle project); not part of the Phase 1 gate. Follow-up: set build-mode none.

## Phase 2 — Functional verification  (✅ DONE, 2026-11-27)
- ✅ Code-audited the 5 IN-scope wire items and confirmed each is correctly wired Dart→native
  (evidence with file:line in `functional-changes/02-wire-contract-verification.md`):
  `md-api-key` (clientToken passthrough), `mdsource=flutter` (`_dd.source='flutter'` →
  `setAdditionalConfiguration`), custom-endpoint (`customEndpoint` → `useCustomEndpoint`),
  `session.created` + `_md.document_version` (native-emitted, not stripped).
- ✅ No new Dart functional code required (matches RN). Added a focused test
  ("source is set to flutter on initialize"); `customEndpoint` was already covered.
- ✅ **GATE GREEN (commit `81ea58de`):** `motadata-build` + `motadata-test` + `motadata-nodatadog`
  all green. CodeQL still informational-red (unchanged; follow-up).

## Phase 3 — Publish to pub.dev  (⬜ not started)
## Phase 4 — Live capture verification  (⬜ not started)
## Phase 5 — Client SOP  (⬜ not started)
