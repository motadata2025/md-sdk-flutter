// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:ui';

import 'package:meta/meta.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../motadata_flutter_plugin.dart';
import '../motadata_internal.dart';
import 'motadata_sdk_method_channel.dart';

typedef LogCallback = void Function(String line);

@immutable
class AttachResponse {
  final bool loggingEnabled;
  final bool rumEnabled;

  const AttachResponse({
    required this.loggingEnabled,
    required this.rumEnabled,
  });

  static AttachResponse? decode(Map<String, Object?> json) {
    try {
      return AttachResponse(
        loggingEnabled: json['loggingEnabled'] as bool,
        rumEnabled: json['rumEnabled'] as bool,
      );
    } catch (e, st) {
      MotadataSdk.instance.internalLogger.sendToMotadata(
        'Failed to deserialize AttachResponse: $e',
        st,
        null,
      );
    }

    return null;
  }
}

@immutable
class CapturedConfiguration {
  final bool loggingEnabled;
  final bool rumEnabled;
  final double? traceSampleRate;
  final TraceContextInjection? traceContextInjection;
  final ResourceHeadersExtractor? resourceHeadersExtractor;
  final Map<String, Set<TracingHeaderType>> firstPartyHosts;
  final List<MotadataPluginConfiguration> configuredPlugins;

  const CapturedConfiguration({
    required this.loggingEnabled,
    required this.rumEnabled,
    required this.traceSampleRate,
    required this.traceContextInjection,
    required this.resourceHeadersExtractor,
    required this.firstPartyHosts,
    required this.configuredPlugins,
  });
}

@immutable
class IsolateAttachResponse {
  final RootIsolateToken rootIsolateToken;
  final CapturedConfiguration capturedConfiguration;

  const IsolateAttachResponse({
    required this.rootIsolateToken,
    required this.capturedConfiguration,
  });
}

/// Result from initializing the platform. Individual members are set to `false`
/// If there is an error loading that feature, such as being unable to load
/// required JavaScript modules on web.
@immutable
class PlatformInitializationResult {
  final bool logs;
  final bool rum;

  const PlatformInitializationResult({required this.logs, required this.rum});
}

@immutable
class MotadataContext {
  final String? sessionId;
  final String? userId;
  final String? accountId;

  const MotadataContext(
      {required this.sessionId, required this.userId, required this.accountId});
}

abstract class MotadataSdkPlatform extends PlatformInterface {
  MotadataSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static MotadataSdkPlatform _instance = MotadataSdkMethodChannel();

  static MotadataSdkPlatform get instance => _instance;

  static set instance(MotadataSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<IsolateAttachResponse?> attachToIsolate();

  MotadataContext? getContext();

  Future<void> setSdkVerbosity(CoreLoggerLevel verbosity);
  Future<void> setTrackingConsent(TrackingConsent trackingConsent);
  Future<void> setUserInfo(
    String id,
    String? name,
    String? email,
    Map<String, Object?> extraInfo,
  );
  Future<void> clearUserInfo();
  Future<void> addUserExtraInfo(Map<String, Object?> extraInfo);

  Future<void> setAccountInfo(
    String id,
    String? name,
    Map<String, Object?> extraInfo,
  );
  Future<void> clearAccountInfo();
  Future<void> addAccountExtraInfo(Map<String, Object?> extraInfo);

  Future<void> sendTelemetryDebug(String message);
  Future<void> sendTelemetryError(String message, String? stack, String? kind);

  Future<PlatformInitializationResult> initialize(
    MotadataConfiguration configuration,
    TrackingConsent trackingConsent, {
    LogCallback? logCallback,
    required InternalLogger internalLogger,
  });
  Future<AttachResponse?> attachToExisting(
    MotadataAttachConfiguration attachConfig,
  );
  Future<void> flush();
  Future<void> flushAndDeinitialize();
  Future<void> clearAllData();

  Future<void> updateTelemetryConfiguration(String property, bool value);
}
