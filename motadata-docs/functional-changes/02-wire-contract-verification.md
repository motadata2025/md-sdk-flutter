# Phase 2 — wire-contract verification

All functional/wire behaviour is **inherited from the frozen native
`com.motadata:motadata-rum-android:1.0.1`**. The Flutter layer adds no functional
code (RN needed none either) — it supplies config and must not strip fields. This
doc records the code-level evidence that each IN-scope wire item is correctly wired.

Paths are under `packages/motadata_flutter_plugin/`.

## 1. `md-api-key` (built by native from `clientToken`)
- Dart passes `clientToken` straight through, no validation/stripping.
- Kotlin `MotadataSdkPlugin.configurationBuilderFromEncoded` reads `encoded["clientToken"]`
  and constructs `Configuration.Builder(clientToken, env, variant, service)`
  (`android/src/main/kotlin/com/motadata/flutter/MotadataSdkPlugin.kt:249,263`).
- The native SDK builds the intake URL with `md-api-key` from that client token.
- **Verified: Dart does not touch the key.**

## 2. `mdsource=flutter`
- `MotadataConfigKey.source = '_dd.source'` — the kept config key the native reads
  (`lib/src/attributes.dart:6`).
- The facade sets it on every init:
  `configuration.additionalConfig[MotadataConfigKey.source] = 'flutter'`
  (`lib/motadata_flutter_plugin.dart:171`).
- Kotlin forwards `additionalConfig` to native via
  `builder.setAdditionalConfiguration(it)` (`MotadataSdkPlugin.kt:282-283`).
- The native SDK rebrands `_dd.source` → `mdsource` on the wire (value `flutter`).
- Test: `test/motadata_sdk_test.dart` — "source is set to flutter on initialize".
- **Verified.**

## 3. `session.created` (epoch ms)
- Emitted automatically by the native RUM SDK when a session starts. No Dart code
  produces or strips it; the Flutter event mappers never see the session envelope.
- **Verified: native-only, nothing to port (same as RN).**

## 4. `_md.document_version`
- Rides in the native `_md` envelope automatically on view updates. The Dart view
  event model round-trips `document_version` (`lib/src/rum/mdrum_events.g.dart:57,63`)
  but never strips it; it is not added by Dart.
- **Verified: native-emitted, preserved by the Dart layer.**

## 5. Custom endpoint (Dart `customEndpoint` → native `useCustomEndpoint`)
- Dart field `MotadataRumConfiguration.customEndpoint`
  (`lib/src/rum/rum_configuration.dart:195`) is encoded
  (`'customEndpoint': customEndpoint`, `rum_configuration.dart:277`).
- Kotlin `MotadataRumPlugin` applies it:
  `(encoded["customEndpoint"] as? String)?.let { builder = builder.useCustomEndpoint(it) }`
  (`android/src/main/kotlin/com/motadata/flutter/MotadataRumPlugin.kt:601-602`).
- Test: `test/rum/mdrum_test.dart` asserts the encoded rum config carries `customEndpoint`.
- **Verified: the Dart customEndpoint reaches the native RUM endpoint override.**

## Out of scope (not ported — same as RN)
- `context._timing`, `view.is_view_completed` — not added (not present).
- Logs / Session Replay / WebView / NDK native-crash / Feature Flags — not shipped
  (removed in Phase 1). NDK removal means native crashes (`source_type:ndk`) are not
  reported; Dart-level errors still are.

## Conclusion
No new Dart functional code was required (matches RN). All five IN-scope wire items
are correctly wired Dart→native; the wire itself is produced by the frozen native
artifact. One focused test was added for `source=flutter`; `customEndpoint` was
already covered.
