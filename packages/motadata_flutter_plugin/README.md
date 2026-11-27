# motadata_flutter_plugin

Flutter bindings for the **Motadata** Real User Monitoring (RUM) SDK on **Android**.

This package lets a Flutter app initialize Motadata RUM and report views, user
actions, resources, errors and long tasks. All wire behaviour is inherited from
the frozen native Android artifact `com.motadata:motadata-rum-android:1.0.1`; the
Flutter layer only supplies configuration.

> Platform scope: **Android only**. iOS and Web are not supported in this release.

## Install

```yaml
dependencies:
  motadata_flutter_plugin: ^1.0.0
```

## Initialize

```dart
import 'package:motadata_flutter_plugin/motadata_flutter_plugin.dart';

final configuration = MotadataConfiguration(
  clientToken: '<your-client-token>',
  env: 'prod',
  site: MotadataSite.us1,
  rumConfiguration: MotadataRumConfiguration(
    applicationId: '<your-application-id>',
  ),
);

await MotadataSdk.runApp(configuration, TrackingConsent.granted, () {
  runApp(const MyApp());
});
```

## Auto-instrumentation hooks

Unlike the native SDKs, the Flutter RUM SDK needs three hooks wired up for full
automatic instrumentation:

- **Views** — add a `MotadataNavigationObserver` to your `MaterialApp.navigatorObservers`.
- **Actions** — wrap your app in a `RumUserActionDetector`.
- **Resources** — use `motadata_tracking_http_client` and call
  `configuration.enableHttpTracking()`.

See the client SOP for a full integration walkthrough.

## License

Apache-2.0. This project is a rebranded derivative of the Datadog Flutter SDK;
the original Apache-2.0 attribution headers are retained per the license.
