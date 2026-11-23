# Functional changes — implement / skip / inherited

The Flutter layer adds **no** functional code (same as RN). All wire/functional behavior is
**inherited** from the frozen native `com.motadata:motadata-rum-android:1.0.1`. The Dart/Kotlin bridge
only supplies config and must not strip fields. This is the **exact RN functional set — nothing more**.

## Inherited from native (no Flutter code) — verify on the wire
| Behavior | Wire effect | Source |
|---|---|---|
| `md-api-key` query param | `…?…&md-api-key=<clientToken>` | native builds it from the Dart `clientToken` |
| `_md` envelope (was `_dd`) | top-level `_md{…}` | native does the `_dd`→`_md` rebrand on the wire |
| `mdtags` (was `ddtags`) | `…&mdtags=…` | native |
| `MD-*` headers (was `DD-*`) | `MD-API-KEY`, `MD-EVP-ORIGIN`, … | native |
| `session.created` (epoch ms) | on session events | native RUM automatic |
| `_md.document_version` | rides in `_md` envelope | native automatic |

## Supplied by the Flutter layer (config only, no new logic)
| Behavior | How |
|---|---|
| `mdsource=flutter` | via the `_dd.source` config key the native SDK reads → native emits `mdsource=flutter` |
| custom endpoint | Dart `customEndpoint` → native `useCustomEndpoint` (per-feature: set on rum + logging) |

## NOT ported (same as RN — backend ignores)
- ❌ `context._timing` — no code. (May ride along if native emits it; we don't add it.)
- ❌ `view.is_view_completed` — **not present in RN; not added here.** No code.
- ❌ Logs / Session Replay / WebView / NDK native-crash / Feature Flags — not shipped
  (dropped `dd-sdk-android-logs` + `dd-sdk-android-ndk`; native crashes not reported).

## Event types produced (Android, inherited)
`view`, `action`, `resource`, `error` (Dart-level), `long_task`, plus vitals **on** view events.
The 3 manual Flutter integration hooks (nav observer, action detector, http tracking) are **client-SOP
steps, not SDK code** — see the Phase 5 client SOP.
