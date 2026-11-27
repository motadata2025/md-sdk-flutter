# Motadata Flutter RUM SDK

Flutter Real User Monitoring (RUM) SDK for **Android**, published to pub.dev as two
packages. It is a rebranded fork of the Datadog Flutter SDK, mirroring the Motadata
Android (`md-sdk-android`) and React Native (`md-sdk-reactnative`) SDKs, and inherits
its entire wire contract from the frozen native artifact
`com.motadata:motadata-rum-android:1.0.1`.

## Packages

| Package | Description |
|---|---|
| [`motadata_flutter_plugin`](packages/motadata_flutter_plugin) | RUM core — views, actions, resources, errors, long tasks |
| [`motadata_tracking_http_client`](packages/motadata_tracking_http_client) | HTTP resource tracking + distributed-tracing headers |

## Scope

- **Android only** (iOS and Web are not supported in this release).
- RUM only. Logs, Session Replay, WebView tracking, NDK native-crash reporting and
  Feature Flags are not shipped.

## Development

All building, testing and publishing runs on GitHub Actions (see `.github/workflows`
and `motadata-docs/WORKFLOW.md`). Nothing is built locally.

## License

Apache-2.0. This project is a rebranded derivative of the Datadog Flutter SDK;
the original Apache-2.0 attribution headers (`NOTICE`, `LICENSE`, and per-file
headers) are retained per the terms of the license.
