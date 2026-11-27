# motadata_tracking_http_client

An `HttpClient` wrapper that automatically reports HTTP requests as **resource**
events to the [motadata_flutter_plugin](https://pub.dev/packages/motadata_flutter_plugin)
RUM SDK, and injects distributed-tracing headers for first-party hosts.

> Platform scope: **Android only**.

## Install

```yaml
dependencies:
  motadata_flutter_plugin: ^1.0.0
  motadata_tracking_http_client: ^1.0.0
```

## Usage

Enable HTTP tracking on your Motadata configuration before initializing:

```dart
final configuration = MotadataConfiguration(
  clientToken: '<your-client-token>',
  env: 'prod',
  site: MotadataSite.us1,
  firstPartyHosts: ['example.com'],
  rumConfiguration: MotadataRumConfiguration(
    applicationId: '<your-application-id>',
  ),
)..enableHttpTracking();
```

Once enabled, requests made through the tracking client are reported as RUM
resources. For first-party hosts, standard APM distributed-tracing headers are
added so RUM resources can be correlated with backend traces.

## License

Apache-2.0. This project is a rebranded derivative of the Datadog Flutter SDK;
the original Apache-2.0 attribution headers are retained per the license.
