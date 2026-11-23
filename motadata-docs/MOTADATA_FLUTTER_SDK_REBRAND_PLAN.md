# Motadata Flutter RUM SDK — Rebrand Plan & Phases

Fork/rebrand of the **Datadog Flutter RUM SDK** into a **Motadata Flutter RUM SDK**, mirroring
the already-shipped Motadata Android (`md-sdk-android`) and React Native (`md-sdk-reactnative`) SDKs.
This doc is the single source of truth for *what* we do and *in what order*. A companion
`PROGRESS.md` (created in Phase 0) tracks *status* per step with green CI run ids + commit SHAs.

---

## 0. Goal & end product

**End product:** two packages published to **pub.dev**, with zero Datadog branding anywhere a
customer or the backend can see it (only the Apache-2.0 legal header remains):

- **`motadata_flutter_plugin`** `1.0.0` — the RUM core plugin (rebrand of `datadog_flutter_plugin`)
- **`motadata_tracking_http_client`** `1.0.0` — HTTP resource tracking (rebrand of `datadog_tracking_http_client`)

A Flutter app integrates the SDK with a **fully rebranded snippet** (`MotadataSdk.runApp(...)`, no
`Datadog*` names), pointing at a Motadata intake, and the wire it produces is 100% Motadata
(`mdsource=flutter`, `md-api-key`, `_md` envelope, `MD-*` headers), backend-compatible with the same
parser that already handles Android + RN.

---

## 1. Locked decisions

| Decision | Choice | Why |
|---|---|---|
| Repo strategy | **Standalone public repo** `motadata2025/md-sdk-flutter` (not a GitHub fork) | Same as RN; avoids fork restrictions on Actions/secrets. Keep `upstream` remote for ancestry. |
| Local folder | **`~/Documents/Repos/Rum-Flutter-SDK/md-sdk-flutter`** (clone lives here) | Same pattern as `Rum-Android-SDK/md-sdk-android`, `Rum-ReactNative-SDK/md-sdk-reactnative`. |
| Fork base | **`datadog_flutter_plugin/v3.4.1`** (Dart `^3.6.0`, Flutter `≥3.27.0`) | Closest exact native pin (`3.11.0`); override one line to native `1.0.1` (= `3.10.0`). Fallback `v3.4.0`. |
| Native dependency | Repoint Android dep → **`com.motadata:motadata-rum-android:1.0.1`** | Inherit the entire Motadata wire contract from the frozen native artifact (RN model). |
| Platform scope | **Android-only**, iOS deferred | No Motadata iOS native artifact exists; iOS would emit stock-Datadog wire. Matches RN. |
| Branch model | **Single branch `motadata-dev`** → ships `1.0.0` | Rebrand + functional inherited together (RN model, not Android's two-branch split). |
| Source value | **`mdsource=flutter`** | Keep Flutter's distinct source (matches captured `ddsource=flutter`). |
| Publishing | **pub.dev** via GitHub Actions **OIDC** (no stored token) | We only *depend on* the already-published native `1.0.1`; no Maven Central/GPG needed. |

---

## 2. Scope — packages kept vs dropped (RUM-only)

From the `v3.4.1` monorepo `packages/` tree, **keep 2 shipping packages + 1 test helper**:

| Package | Action | New name |
|---|---|---|
| `datadog_flutter_plugin` | **KEEP** (RUM core) | `motadata_flutter_plugin` |
| `datadog_tracking_http_client` | **KEEP** (resource events — the `enableHttpTracking()` hook) | `motadata_tracking_http_client` |
| `datadog_common_test` | keep for tests only | (internal) |
| `datadog_session_replay` | DROP | — |
| `datadog_webview_tracking` | DROP | — |
| `datadog_inappwebview_tracking` | DROP | — |
| `datadog_dio` | DROP | — |
| `datadog_grpc_interceptor` | DROP | — |
| `datadog_gql_link` | DROP | — |
| `datadog_flags`, `datadog_flags_flutter` | DROP | — |

**Android native modules:** keep the Motadata RUM stack (rum + trace + okhttp + core + internal).
**Drop** the plugin's `dd-sdk-android-logs` and `dd-sdk-android-ndk` deps — there is no Motadata
native Logs/NDK artifact. **Consequence:** Android **native crashes** (`source_type:ndk`, SIGSEGV)
are **not** reported (Dart-level errors still are). Same limitation as the Android/RN SDKs.

---

## 3. Rebrand token map (shipped surfaces — zero datadog)

The grep-based **no-datadog CI gate** fails the build if any of these survive on a shipped surface
(whitelisting only the Apache-2.0 attribution header).

| Old | New |
|---|---|
| `datadog_flutter_plugin` (pkg) | `motadata_flutter_plugin` |
| `datadog_tracking_http_client` (pkg) | `motadata_tracking_http_client` |
| `DatadogSdk` / `Datadog` (Dart facade) | `MotadataSdk` / `Motadata` |
| `Dd*` Dart/Kotlin types (`DdRum`, `DdSdk`, `DdLogs`→dropped) | `Md*` (`MdRum`, `MdSdk`) |
| `DatadogConfiguration`, `DatadogRumConfiguration` | `MotadataConfiguration`, `MotadataRumConfiguration` |
| method-channel names `datadog_sdk_flutter`, `datadog_sdk_flutter.rum` | `motadata_sdk_flutter*` |
| Kotlin pkg `com.datadoghq.flutter` | `com.motadata.flutter` |
| Gradle dep `com.datadoghq:dd-sdk-android-*` | `com.motadata:motadata-rum-android*:1.0.1` |
| `_dd` envelope | `_md` *(done by native)* |
| `ddsource` query | `mdsource` *(native; value `flutter`)* |
| `ddtags` query | `mdtags` *(native)* |
| `DD-*` headers | `MD-*` *(native)* |
| `ddsource=flutter` | `mdsource=flutter` |

Note: like RN, some `_dd.*` **config keys** the native SDK reads (e.g. `_dd.source`,
`_dd.needsClearTextHttp`) are intentionally kept in the Dart layer — the frozen native SDK does the
`_dd`→`_md` rebrand on the wire. The gate whitelists those config keys; only branding on shipped
surfaces is forbidden.

---

## 4. Functional scope — EXACTLY the RN set (nothing more)

All functional/wire behavior is **inherited from the frozen native `1.0.1`**; the Flutter layer adds
**no** functional code (RN added none either) — it only supplies config and must not strip fields.

**IN scope (backend-consumed — verify on the wire):**
1. **`md-api-key`** query param — built by native from the Dart `clientToken`. Don't validate/strip it.
2. **`mdsource=flutter`** — keep Flutter's source override (our chosen value).
3. **`session.created`** (epoch ms) — emitted automatically by native RUM.
4. **`_md.document_version`** — rides in the `_md` envelope automatically.
5. **Custom endpoint** — ensure the Dart `customEndpoint` reaches native `useCustomEndpoint`.

**OUT of scope (NOT ported — same as RN):**
- ❌ `context._timing` — backend ignores. No code. (May ride along if native emits it; we don't add it.)
- ❌ `view.is_view_completed` — backend ignores. No code. **Not present in RN; not in Flutter.**
- ❌ Logs / Session Replay / WebView / NDK native-crash / Feature Flags — not shipped.

Event types produced: `view`, `action`, `resource`, `error` (Dart), `long_task`, plus vitals **on**
view events. (The 3 manual Flutter hooks — nav observer, action detector, http tracking — are
integration steps in the client SOP, not SDK code.)

---

## 5. The phases (each ends GREEN, then STOP for "go")

> Golden rule: **nothing compiles on the laptop.** Every build/test/publish runs on GitHub Actions,
> triggered + watched via `gh`. One "go gate" per step; nothing advances on red.

### Phase 0 — Bootstrap & CI (gate: green on UNTOUCHED Datadog base)
- Create repo `motadata2025/md-sdk-flutter`.
- Clone `datadog_flutter_plugin/v3.4.1` into `~/Documents/Repos/Rum-Flutter-SDK/md-sdk-flutter`;
  set `origin`=Motadata, `upstream`=DataDog; push base.
- Seed `motadata-docs/` (this plan, `WORKFLOW.md`, `PROGRESS.md`, `functional-changes/`).
- Author `motadata-*` workflows (Flutter-adapted): `motadata-build.yml` (`flutter pub get` + `flutter build`/`dart analyze`), `motadata-test.yml` (`flutter test`), `motadata-nodatadog.yml` (grep gate), `motadata-publish.yml` (pub.dev, `dry_run` input), `codeql-analysis.yml` (dart/js).
- Cut branch `motadata-dev`.
- **Gate:** dispatch build + test → green on the untouched base (proves CI before any change).

### Phase 1 — Rebrand + repoint native + zero-datadog (gate: no-datadog + build + test green)
- Trim repo to the 2 packages (+ common_test); delete dropped packages.
- Full rename per the token map (§3) across Dart + Android Kotlin + method channels + pubspecs.
- Repoint Android `ext.datadog_version`/deps → `com.motadata:motadata-rum-android:1.0.1`; drop logs/ndk.
- Set source → `flutter` (via the `_dd.source` config key the native reads).
- **Gate:** `motadata-nodatadog` green (zero leaks) + build + test green → publishable as `1.0.0`.

### Phase 2 — Functional verification (gate: build + test green)
- Confirm (code + test) the inherited wire: `md-api-key`, `mdsource=flutter`, `session.created`,
  `_md.document_version`, custom-endpoint chain. Expect little/no Dart code (RN needed none).

### Phase 3 — Publish to pub.dev (gate: dry-run green → real publish)
- Arrange a **pub.dev verified publisher** (verified against `motadata.com`) + OIDC trust for the repo.
- `motadata-publish.yml` dry-run ×N green → real publish of both packages at `1.0.0`.
- Audit the actual published archive (RN lesson: tarball/README hygiene, not the rename, caused late bugs).

### Phase 4 — Live capture verification (gate: captures show 100% Motadata)
- Point the Event Lab Flutter app at `motadata_flutter_plugin`; run the existing capture tooling
  (`tools/datadog_capture_server.py` + the rich UI driver).
- Verify on the wire: `mdsource=flutter`, `md-api-key`, `_md` envelope, `MD-*` headers, `session.created`;
  zero `datadog`/`_dd` leaks across all event types.

### Phase 5 — Client SOP (deliverable)
- Write `MOTADATA_FLUTTER_CLIENT_SOP.md` mirroring the RN/Android SOP structure
  (Prerequisites → Install → Initialize → View/Action/Resource tracking → Verify → Notes), **plus**
  the 3 Flutter-specific hooks (`MotadataNavigationObserver`, `RumUserActionDetector`,
  `enableHttpTracking()`) that Flutter needs for full auto-instrumentation.

---

## 6. Local setup (already done / needed)

- ✅ `gh` authenticated as **motadata2025** (`repo`, `workflow`, `write:packages`, `delete:packages`, `read:org`).
- ✅ git identity set (`motadata2025` / `shaunak.mehta@motadata.com`).
- ✅ Flutter SDK at `~/flutter` (local fallback; CI uses `subosito/flutter-action`).
- ⏳ **pub.dev verified publisher** — only needed at Phase 3.

## 7. Secrets (far fewer than Android — no Maven/GPG)
- Build / test / no-datadog gates: **none**.
- Publish: pub.dev via **OIDC** (no stored secret) — configured on pub.dev after the package first exists.
- `GITHUB_TOKEN` is auto-provided; just set job `permissions` (`contents: write` for any autocommit,
  `security-events: write` for CodeQL, `id-token: write` for pub.dev OIDC).
