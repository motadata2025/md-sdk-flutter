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

## Phase 1 — Rebrand / repoint native / zero-datadog  (⬜ not started)
## Phase 2 — Functional verification  (⬜ not started)
## Phase 3 — Publish to pub.dev  (⬜ not started)
## Phase 4 — Live capture verification  (⬜ not started)
## Phase 5 — Client SOP  (⬜ not started)
