# Phase 1 — execution notes (ground truth + decisions)

Working notes captured during Phase 1 so the rename is correct-by-construction and auditable.

## Ground truth verified against the frozen native `com.motadata:motadata-rum-android:1.0.1`
Inspected the cached AARs/sources (`~/.gradle/caches/.../com.motadata/...`). The fork is a
**uniform rename** of dd-sdk-android:
- package `com.datadog.android.*` → `com.motadata.android.*`
- class `Datadog` → `Motadata`; `DatadogSite` → `MotadataSite`;
  `com.datadog.android.api.context.DatadogContext` → `...MotadataContext`
- all other classes keep their names, only the package is relocated
  (`RumConfiguration`, `RumMonitor`, `TrackingConsent`, `Configuration`, `AccountInfo`,
  `UserInfo`, `DeviceInfo`, `NetworkInfo`, `ProcessInfo`, `TimeInfo`, …)
- **NO `log` and NO `ndk` packages exist** in the fork (artifacts: rum, core, internal, trace,
  trace-api, trace-internal, okhttp). So the plugin's `dd-sdk-android-logs`/`-ndk` deps and all
  Kotlin `com.datadog.android.log.*` / `.ndk.*` imports MUST be removed or the APK won't compile.
- trace wire headers are **kept** as `x-datadog-trace-id` / `x-datadog-parent-id` (the fork did
  NOT rebrand the APM propagation header names).

## The uniform substitution rule (applied to BOTH file contents AND file/dir paths)
Dart and Kotlin get the exact same rules, so relative imports, Kotlin package dirs, and the
jnigen JNI runtime strings (`com/datadoghq/flutter/DatadogRumPlugin`, `Lcom/datadog/android/...;`)
all stay consistent and match the fork's real class names by construction.

Order (longest/most-specific first), per line, skipping protected lines:
1. **skip** lines matching `developed at Datadog` or `Datadog, Inc` (Apache attribution — keep verbatim).
2. protect `x-datadog-` substrings (wire propagation header names — must stay; see below).
3. `datadoghq` → `motadata`   (before `datadog`, so `datadoghq`→`motadata` not `motadatahq`)
4. `Datadog` → `Motadata`     (class names: DatadogSite→MotadataSite, DatadogContext→MotadataContext, DatadogRumPlugin→MotadataRumPlugin, DatadogSdk→MotadataSdk, native Datadog→Motadata)
5. `datadog` → `motadata`     (packages com/datadog/android→com/motadata/android, identifiers datadog_flutter_plugin→motadata_flutter_plugin, channel datadog_sdk_flutter→motadata_sdk_flutter)
6. `DATADOG` → `MOTADATA`
7. `\bDd([A-Z])` → `Md\1`     (DdRum→MdRum, DdSdk→MdSdk, DdFlutterEncodable→MdFlutterEncodable; matches the gate's `\bDd[A-Z]`)
8. `ddsource`→`mdsource`, `ddtags`→`mdtags`, `DD-([A-Z])`→`MD-\1`
9. restore `x-datadog-`.

Config keys intentionally KEPT (native reads them; gate-whitelisted): `_dd.source`,
`_dd.needsClearTextHttp`, `_dd.sdk_version`, `_dd.version`. These are lowercase `_dd` and are not
touched by any rule above.

## Scope cuts inside `datadog_flutter_plugin` (all out of scope → removed)
- **iOS native** (`ios/` Swift dir) deleted; pubspec declares **android only**. iOS *Dart* bridge
  (`lib/src/ios/*`, except the log mapper) is kept+renamed — it compiles on Android (dart.library.io)
  and is inert (Platform.isIOS never true).
- **Web** deleted (self-contained, no `dart.library.html` conditional imports): `lib/*_web.dart`,
  `lib/src/rum/web/`, web block + `web:` dep in pubspec.
- **Logs** removed: `lib/src/logs/`, `lib/src/{android,ios}/*_log_event_mapper.dart`, Kotlin
  `DatadogLogsPlugin.kt` + `DatadogLogEventMapper.kt` (+ test), public `logs` API in the facade,
  `loggingConfiguration` in config, example `logging_screen.dart`. Generic inert `logs`/`loggingEnabled`
  booleans remain in the platform plumbing (not branding, not a public API). The renamed-but-dead
  logs JNI bindings in the generated bridge are left (unreferenced after the mapper is deleted).
- **NDK** removed: gradle `dd-sdk-android-ndk` dep + `NdkCrashReports.enable()` path in SdkPlugin.kt.
  Consequence (same as Android/RN): native crashes (`source_type:ndk`) not reported; Dart errors are.

## Native dep repoint (android/build.gradle)
`com.datadoghq:dd-sdk-android-rum:$datadog_version` → `com.motadata:motadata-rum-android:1.0.1`;
drop the `-logs` and `-ndk` deps; drop unused `ext.datadog_version`. No `-trace` needed (the plugin's
main Kotlin imports no trace module). Example toolchain is Gradle 9.1.0 / AGP 9.0.0 (> the
metrics-performance 8.6 floor) so no RN-style version gymnastics are required.

## Open decision flagged to the user (branding vs wire-compat)
`x-datadog-trace-id` / `x-datadog-parent-id` (+ `tracestate: dd=…`) are kept literal in
`tracing_headers.dart` because the **frozen native keeps them** (APM distributed-tracing propagation
format; renaming breaks RUM↔trace correlation, and matches RN's native behavior). The `TracingHeaderType.datadog`
**enum value** is renamed → `.motadata`. The gate whitelists `x-datadog-` exactly like `_dd.*`.
