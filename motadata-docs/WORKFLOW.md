# CI Runbook (the golden rule)

**Nothing compiles on the laptop.** Editing files and reading repos is free; *compiling*
(`flutter pub get`, `dart analyze`, `flutter build`, `flutter test`, gradle) is offloaded to
**GitHub Actions**, triggered and inspected via `gh`.

Repo: `motadata2025/md-sdk-flutter` · Branch: `motadata-dev` · Runners: `ubuntu-latest`.

## Toolchain the CI assumes
- Flutter **stable ≥ 3.27.0**, Dart **≥ 3.6.0** (installed via `subosito/flutter-action`).
- JDK **17** (Android gradle) — `actions/setup-java` temurin 17.
- Android build via the package `example/` app (`flutter build apk`); native dep resolves
  `com.motadata:motadata-rum-android:1.0.1` from Maven Central (Phase 1 onward).

## Scope of the gates
CI targets **only the two shipping packages** (`datadog_flutter_plugin` → `motadata_flutter_plugin`,
`datadog_tracking_http_client` → `motadata_tracking_http_client`) + `datadog_common_test` for tests.
The sibling monorepo packages we are dropping (session_replay, webview, dio, grpc, gql, flags…) are
**not** built — building them on the untouched base would be noise for code we delete in Phase 1.

## Workflows (`.github/workflows/`)
| File | Trigger | What it does |
|---|---|---|
| `motadata-build.yml` | push `motadata-dev` + dispatch | `flutter pub get` + `dart analyze` on both packages; `flutter build apk` on each `example/` |
| `motadata-test.yml` | push `motadata-dev` + dispatch | `flutter test` on both packages (+ `datadog_common_test`) |
| `motadata-nodatadog.yml` | dispatch (→ push in Phase 1) | Grep shipped surfaces for datadog; whitelist Apache header + `_dd.*` config keys only |
| `motadata-publish.yml` | dispatch | `dart pub publish` of each package to **pub.dev** (OIDC; `dry_run` input, default true) |
| `codeql-analysis.yml` | push `motadata-dev` + dispatch | CodeQL security scan (dart/java-kotlin) |

## Common commands
```bash
# always target the Motadata repo (the clone also has an 'upstream' DataDog remote)
gh workflow run motadata-build.yml     -R motadata2025/md-sdk-flutter --ref motadata-dev
gh workflow run motadata-test.yml      -R motadata2025/md-sdk-flutter --ref motadata-dev
gh workflow run motadata-nodatadog.yml -R motadata2025/md-sdk-flutter --ref motadata-dev

# watch / inspect
gh run list  -R motadata2025/md-sdk-flutter -L 10
gh run watch <run-id> -R motadata2025/md-sdk-flutter --exit-status
gh run view  <run-id> -R motadata2025/md-sdk-flutter --log-failed

# publish (Phase 3) — dry run first, repeatedly, until green
gh workflow run motadata-publish.yml -R motadata2025/md-sdk-flutter --ref motadata-dev -f dry_run=true
```

## Secrets / auth the CI needs
- Build / test / no-datadog / CodeQL: **none** (`GITHUB_TOKEN` auto-provided).
- Publish: **pub.dev via OIDC** — no stored token. Needs a pub.dev *verified publisher* (verified
  against `motadata.com`) + the repo granted as a trusted publisher. Configured on pub.dev at Phase 3,
  after the package first exists. Job needs `permissions: id-token: write`.

## Phase gate
Each phase ends with its gate **green**, a short report, then **STOP for go-ahead** before the next
phase. Nothing advances on red. `motadata-nodatadog` is EXPECTED RED on the untouched base (it is still
DataDog-branded) — it is dispatch-only until Phase 1, where it must go green.
