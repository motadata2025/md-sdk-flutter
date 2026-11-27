# Phase 3 — pub.dev publish runbook

Both packages are **publish-ready** (dry-run audited 2026-11-27):
- `motadata_flutter_plugin` 1.0.0 — **0 warnings** (250 KB archive).
- `motadata_tracking_http_client` 1.0.0 — **0 warnings, 1 hint** ("Non-dev dependencies are
  overridden") — the expected `dependency_overrides` on `motadata_flutter_plugin`, removed in step 3.

Publishing is pub.dev **automated publishing via GitHub Actions OIDC** (no stored token).

## One-time pub.dev setup (USER, in the pub.dev web UI)
1. Sign in to pub.dev with the Google account that will own the packages.
2. Create a **verified publisher** for **`motadata.com`** (domain verification).
3. Enable **Automated publishing → GitHub Actions** for each package, trusting repo
   `motadata2025/md-sdk-flutter`. For a brand-new package name the Admin tab doesn't exist until
   the first publish, so either do the first `1.0.0` publish manually (one-time `dart pub publish`
   from a logged-in machine) and then switch automated publishing on, or use pub.dev's
   pre-configure-automated-publishing flow for a reserved name.

## Publish order (MANDATORY — tracking depends on the plugin)
### Step 1 — publish `motadata_flutter_plugin` 1.0.0
- USER dispatches the real publish (agent-triggered real publishes are blocked, same as RN npm):
  ```
  gh workflow run motadata-publish.yml -R motadata2025/md-sdk-flutter --ref motadata-dev \
    -f package=motadata_flutter_plugin -f dry_run=false
  ```
- Verify it appears on pub.dev as `motadata_flutter_plugin 1.0.0`, published by motadata.com.

### Step 2 — remove the tracking dependency_override (now the plugin is live)
- The override exists only so CI/local resolves the local plugin before it was on pub.dev. Once the
  plugin is published, delete the `dependency_overrides:` block from
  `packages/motadata_tracking_http_client/pubspec.yaml`, commit + push.
- CI (build/test) now resolves `motadata_flutter_plugin: ^1.0.0` from pub.dev. Confirm green.

### Step 3 — re-dry-run then publish `motadata_tracking_http_client` 1.0.0
- Dry-run again — should now be **0 hints** (the override is gone):
  ```
  gh workflow run motadata-publish.yml ... -f package=motadata_tracking_http_client -f dry_run=true
  ```
- USER dispatches the real publish:
  ```
  gh workflow run motadata-publish.yml ... -f package=motadata_tracking_http_client -f dry_run=false
  ```

## Step 4 — audit the published archives (RN lesson)
- Confirm both packages render correctly on pub.dev (README, no Datadog branding, correct platform =
  Android only, example present). The RN lesson was that late bugs came from archive/README hygiene,
  not the rename.

## What is NOT needed (unlike the Android SDK)
No Maven Central / GPG signing — we only *depend on* the already-published native `1.0.1`.
