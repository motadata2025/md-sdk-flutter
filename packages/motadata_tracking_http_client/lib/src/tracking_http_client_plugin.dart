// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:io';

import 'package:motadata_flutter_plugin/motadata_flutter_plugin.dart';
import 'package:motadata_flutter_plugin/motadata_internal.dart';
import 'package:flutter/foundation.dart';

import '../motadata_tracking_http_client.dart';

/// An interface for providing attributes to Motadata RUM resources by listening
/// to HttpClient requests and responses.
///
/// MotadataTrackingHttpClient allows you to receive a callback when an
/// HttpClientRequest starts and when an HttpClientResponse finishes. They
/// provide a resource key and a mutable Map<String, Object?> of attributes that
/// you can modify to add attributes to the resulting Motadata RUM resource.
///
/// The userAttributes parameter supplied in [requestStarted] and
/// [responseFinished] are the same map, and it is possible to inspect and
/// modify attributes between the two calls. Only the attributes remaining after
/// [responseFinished] is called will be sent to Motadata.
///
/// If you are performing network calls from background isolates, Flutter will
/// attempts to serialize and recreate this class on the background isolate
/// during your call to [MotadataSdk.attachToBackgroundIsolate], and any state
/// changed in the listener from the main isolate from that point forward will
/// not be reflected in the background isolate. It is generally best practice to
/// set any state variables in this listener to `final` (or not use any at all)
/// to avoid unexpected value discrepancies between isolates.
abstract class MotadataTrackingHttpClientListener {
  /// Called when an HttpClientRequest is started.
  ///
  /// [resourceKey] can be used to connect the request and response or to
  /// connect to other user operations.
  void requestStarted({
    required Object resourceKey,
    required HttpClientRequest request,
    required Map<String, Object?> userAttributes,
  });

  /// Called when an HttpClientResponse is finished.
  ///
  /// [resourceKey] can be used to connect the request and response or to
  /// connect to other user operations.
  void responseFinished({
    required Object resourceKey,
    required HttpClientResponse response,
    required Map<String, Object?> userAttributes,
    Object? error,
  });
}

@immutable
class MdHttpTrackingPluginConfiguration extends MotadataPluginConfiguration {
  final MotadataTrackingHttpClientListener? clientListener;
  final List<RegExp> ignoreUrlPatterns;

  @override
  bool get supportsBackgroundIsolates => true;

  MdHttpTrackingPluginConfiguration({
    this.clientListener,
    this.ignoreUrlPatterns = const [],
  });

  @override
  MotadataPlugin create(MotadataSdk motadataInstance) {
    return _DdHttpTrackingPlugin(motadataInstance, this);
  }
}

class _DdHttpTrackingPlugin extends MotadataPlugin {
  final MdHttpTrackingPluginConfiguration configuration;

  _DdHttpTrackingPlugin(
    MotadataSdk motadataInstance,
    this.configuration,
  ) : super(motadataInstance);

  @override
  void initialize() {
    _setHttpOverrides();
    instance.updateConfigurationInfo(
        LateConfigurationProperty.trackNetworkRequests, true);
  }

  @override
  void initializeFromBackgroundIsolate() {
    _setHttpOverrides();
  }

  void _setHttpOverrides() {
    final existingOverrides = HttpOverrides.current;
    HttpOverrides.global = MotadataTrackingHttpOverrides(
      instance,
      configuration,
      existingOverrides,
    );
  }
}
