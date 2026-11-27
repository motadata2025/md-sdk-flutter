// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
// Dart 3.9 made it so meta is no longer needed for `@internal`, but we
// still need it for versions below 3.9.
// ignore: unnecessary_import
import 'package:meta/meta.dart';

import 'motadata_internal.dart';
import 'src/motadata_configuration.dart';
import 'src/motadata_noop_platform.dart';
import 'src/motadata_plugin.dart';
import 'src/rum/mdrum_noop_platform.dart';
import 'src/rum/mdrum_platform_interface.dart';
import 'src/rum/rum.dart';
import 'src/version.dart' show mdPackageVersion;

export 'src/motadata_configuration.dart';
export 'src/motadata_plugin.dart';
export 'src/rum/rum.dart';
export 'src/tracing/tracing_headers.dart' show TracingHeaderType;

typedef AppRunner = void Function();

enum CoreLoggerLevel { debug, warn, error, critical }

/// A singleton for the Motadata SDK.
///
/// Once initialized, individual features can be access through the [logs]
/// and [rum] member variables. If a feature is disabled (either
/// because they were not configured or the SDK has not been initialized) the
/// member variables will default to `null`
class MotadataSdk {
  static MotadataSdkPlatform get _platform {
    return MotadataSdkPlatform.instance;
  }

  MotadataSdk._();

  static MotadataSdk? _singleton;
  static MotadataSdk get instance {
    _singleton ??= MotadataSdk._();
    return _singleton!;
  }

  /// Set Motadata to use No Op platform implementations.
  ///
  /// Not that this disables Motadata, and should only be used when performing
  /// headless integration tests where the underlying platform is not available
  static void initializeForTesting() {
    MotadataSdkPlatform.instance = MotadataSdkNoOpPlatform();
    MdRumPlatform.instance = MdNoOpRumPlatform();
  }

  bool _initialized = false;
  MotadataConfiguration? _configuration;
  MotadataConfiguration? get configuration => _configuration;

  MotadataRum? _rum;
  MotadataRum? get rum => _rum;

  List<FirstPartyHost> _firstPartyHosts = [];

  final Map<Type, MotadataPlugin> _plugins = {};

  /// An unmodifiable list of first party hosts for tracing.
  List<FirstPartyHost> get firstPartyHosts =>
      List.unmodifiable(_firstPartyHosts);
  void _setFirstPartyHosts(Map<String, Set<TracingHeaderType>> value) {
    _firstPartyHosts = FirstPartyHost.createSanitized(value, internalLogger);
  }

  /// The version of this SDK.
  static String get sdkVersion => mdPackageVersion;

  /// Logger used internally by Motadata to report errors.
  @internal
  final InternalLogger internalLogger = InternalLogger();

  /// Internal extension access to the configured platform
  MotadataSdkPlatform get platform => _platform;

  /// Set the verbosity of the Motadata SDK. Set to [CoreLoggerLevel.warn] by
  /// default. All internal logging is enabled only when [kDebugMode] is
  /// set.
  CoreLoggerLevel get sdkVerbosity => internalLogger.sdkVerbosity;
  set sdkVerbosity(CoreLoggerLevel value) {
    internalLogger.sdkVerbosity = value;
    if (_initialized) {
      unawaited(_platform.setSdkVerbosity(value));
    }
  }

  /// Get an instance of a MotadataPlugin that was registered with
  /// [MotadataConfiguration.addPlugin]
  T? getPlugin<T>() => _plugins[T] as T?;

  /// INTERNAL USE ONLY
  /// Force any pending data to upload to Motadata now. Blocks until the upload
  /// completes (or fails).
  ///
  /// This function is not part of the public interface for Motadata and is used
  /// for integration testing purposes. It is not guaranteed to be available on
  /// all platforms and may leave the SDK in an unreliable state.
  Future<void> flush() async {
    await _platform.flush();
  }

  /// This function is not part of the public interface for Motadata, and may not
  /// be available in all targets. Used for integration and E2E testing purposes only.
  @visibleForTesting
  Future<void> flushAndDeinitialize() async {
    await _platform.flushAndDeinitialize();
    for (final plugin in _plugins.values) {
      plugin.shutdown();
    }
    _plugins.clear();
    _rum?.deinitialize();
    _rum = null;

    _configuration = null;
    _initialized = false;
  }

  /// A helper function that will initialize Motadata and setup error reporting
  ///
  /// See also, [MotadataRum.handleFlutterError], [MotadataTrackingHttpClient]
  static Future<void> runApp(
    MotadataConfiguration configuration,
    TrackingConsent trackingConsent,
    AppRunner runner,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      MotadataSdk.instance.rum?.handleFlutterError(details);
      originalOnError?.call(details);
    };
    final platformOriginalOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (e, st) {
      MotadataSdk.instance.rum?.addErrorInfo(
        e.toString(),
        RumErrorSource.source,
        stackTrace: st,
      );
      return platformOriginalOnError?.call(e, st) ?? false;
    };

    await MotadataSdk.instance.initialize(configuration, trackingConsent);
    MotadataSdk.instance.updateConfigurationInfo(
      LateConfigurationProperty.trackErrors,
      true,
    );

    runner();
  }

  /// Initialize the MotadataSdk with the provided [configuration].
  Future<void> initialize(
    MotadataConfiguration configuration,
    TrackingConsent trackingConsent,
  ) async {
    // First set our SDK verbosity. We can assume WidgetsFlutterBinding has been initialized at this point
    await _platform.setSdkVerbosity(internalLogger.sdkVerbosity);

    configuration.additionalConfig[MotadataConfigKey.source] = 'flutter';
    configuration.additionalConfig[MotadataConfigKey.sdkVersion] = sdkVersion;

    _setFirstPartyHosts(configuration.firstPartyHostsWithTracingHeaders);

    await _platform.initialize(
      configuration,
      trackingConsent,
      logCallback: _platformLog,
      internalLogger: internalLogger,
    );
    _configuration = configuration;

    if (configuration.rumConfiguration != null) {
      _rum = await MotadataRum.enable(this, configuration.rumConfiguration!);
    }

    _initializePlugins(configuration.additionalPlugins);
    _initialized = true;
  }

  /// Attach an initialized Motadata Flutter SDK the currently active background isolate.
  ///
  /// Motadata must already be initialized in the root isolate for [attachToBackgroundIsolate]
  /// to work properly.
  Future<void> attachToBackgroundIsolate() async {
    try {
      final attachResponse = await platform.attachToIsolate();
      if (attachResponse == null) {
        internalLogger.warn(
          'Could not attach to background isolate. Did not recieve a configuration from the main isolate.'
          ' You are either trying to attach on a platform that does not support isolates, or trying to attach before Motadata initialization is complete.',
        );
      } else {
        _setFirstPartyHosts(
          attachResponse.capturedConfiguration.firstPartyHosts,
        );
        if (attachResponse.capturedConfiguration.rumEnabled) {
          _rum = MotadataRum.forBackgroundIsolate(
            this,
            attachResponse.capturedConfiguration.traceSampleRate ?? 100.0,
            attachResponse.capturedConfiguration.traceContextInjection ??
                TraceContextInjection.sampled,
            attachResponse.capturedConfiguration.resourceHeadersExtractor,
          );
        }

        for (final pluginConfig
            in attachResponse.capturedConfiguration.configuredPlugins) {
          var plugin = pluginConfig.create(this);
          if (_plugins.containsKey(plugin.runtimeType)) {
            internalLogger.error(
              'Attempting to setup two plugins of the same type: ${plugin.runtimeType}. The second plugin will be ignored.',
            );
          } else {
            plugin.initializeFromBackgroundIsolate();
            _plugins[plugin.runtimeType] = plugin;
          }
        }
      }
    } catch (e, st) {
      internalLogger.sendToMotadata(
        'Failed to attach background isolate: $e',
        st,
        e.runtimeType.toString(),
      );
      internalLogger.warn(
        'Encountered an error attempting to attach to a background isolate: $e',
      );
    }
  }

  /// Attach the Motadata Flutter SDK to an already initialized Motadata Native
  /// (iOS or Android) SDK.  This is used for "app in app" embedding of Flutter.
  Future<void> attachToExisting(MotadataAttachConfiguration config) async {
    // First set our SDK verbosity. We can assume WidgetsFlutterBinding has been initialized at this point
    await _platform.setSdkVerbosity(internalLogger.sdkVerbosity);

    final attachResponse = await wrapAsync<AttachResponse>(
      'attachToExisting',
      internalLogger,
      null,
      () async {
        return await _platform.attachToExisting(config);
      },
    );

    if (attachResponse != null) {
      _setFirstPartyHosts(config.firstPartyHostsWithTracingHeaders);

      if (attachResponse.rumEnabled) {
        _rum = MotadataRum.fromExisting(this, config);
      }

      _initializePlugins(config.additionalPlugins);
      _initialized = true;
    } else {
      internalLogger.error(
        'Failed to attach to an existing native instance of the Motadata SDK.',
      );
    }
  }

  /// Sets current user information. User information will be added to logs,
  /// traces and RUM events automatically.
  void setUserInfo({
    required String id,
    String? name,
    String? email,
    Map<String, Object?> extraInfo = const {},
  }) {
    wrap('setUserInfo', internalLogger, extraInfo, () {
      return _platform.setUserInfo(id, name, email, extraInfo);
    });
  }

  /// Clear the current user information.
  ///
  /// User information will be `null`. Following Logs, Traces, RUM Events will
  /// not include the user information anymore.
  ///
  /// Any active RUM Session, active RUM View at the time of call will have
  /// their `user` attribute emptied.
  ///
  /// If you want to retain the current `user` on the active RUM session, you
  /// need to stop the session first by using [MotadataRum.stopSession].
  ///
  /// If you want to retain the current `user` on the active RUM views, you need
  /// to stop the view first by using [MotadataRum.stopView].
  void clearUserInfo() {
    wrap('clearUserInfo', internalLogger, null, () {
      return _platform.clearUserInfo();
    });
  }

  /// Add custom attributes to the current user information
  ///
  /// This extra info will be added to already existing extra info that is added
  /// to logs, traces, and RUM events automatically.
  ///
  /// Setting an existing attribute to `null` will remove that attribute from
  /// the user's extra info
  void addUserExtraInfo(Map<String, Object?> extraInfo) {
    wrap('addUserExtraInfo', internalLogger, extraInfo, () {
      return _platform.addUserExtraInfo(extraInfo);
    });
  }

  /// Sets current account information.
  ///
  /// Those will be added to logs, traces and RUM events automatically.
  void setAccountInfo({
    required String id,
    String? name,
    Map<String, Object?> extraInfo = const {},
  }) {
    wrap('setAccountInfo', internalLogger, extraInfo, () {
      return _platform.setAccountInfo(id, name, extraInfo);
    });
  }

  /// Clear the current account information.
  ///
  /// Account information will be `null`. Following Logs, Traces, RUM Events will
  /// not include the account information anymore.
  ///
  /// Any active RUM Session, active RUM View at the time of call will have
  /// their `account` attribute emptied.
  ///
  /// If you want to retain the current `account` on the active RUM session, you
  /// need to stop the session first by using [MotadataRum.stopSession].
  ///
  /// If you want to retain the current `account` on the active RUM views, you need
  /// to stop the view first by using [MotadataRum.stopView].
  void clearAccountInfo() {
    wrap('clearAccountInfo', internalLogger, null, () {
      return _platform.clearAccountInfo();
    });
  }

  /// Add custom attributes to the current account information.
  ///
  /// This extra info will be added to already existing extra info that is added
  /// to logs, traces, and RUM events automatically.
  ///
  /// Setting an existing attribute to `null` will remove that attribute from
  /// the account's extra info.
  void addAccountExtraInfo(Map<String, Object?> extraInfo) {
    wrap('addAccountExtraInfo', internalLogger, extraInfo, () {
      return _platform.addAccountExtraInfo(extraInfo);
    });
  }

  /// Clears all data that has not already been sent to Motadata servers.
  ///
  /// This method is not supported on Flutter Web.
  void clearAllData() {
    wrap('clearAllData', internalLogger, null, () {
      return _platform.clearAllData();
    });
  }

  void setTrackingConsent(TrackingConsent trackingConsent) {
    wrap('setTrackingConsent', internalLogger, null, () {
      return _platform.setTrackingConsent(trackingConsent);
    });
  }

  // Determine if the provided URI is a first party host as determined by the
  // value of [firstPartyHosts].
  bool isFirstPartyHost(Uri uri) {
    return headerTypesForHost(uri).isNotEmpty;
  }

  Set<TracingHeaderType> headerTypesForHost(Uri uri) {
    var tracingHeaderTypes = <TracingHeaderType>{};
    for (var host in firstPartyHosts) {
      if (host.matches(uri)) {
        tracingHeaderTypes = tracingHeaderTypes.union(host.headerTypes);
      }
    }
    return tracingHeaderTypes;
  }

  void _platformLog(String log) {
    if (kDebugMode) {
      print(log);
    }
  }

  void _initializePlugins(List<MotadataPluginConfiguration> plugins) {
    for (final pluginConfig in plugins) {
      var plugin = pluginConfig.create(this);
      if (_plugins.containsKey(plugin.runtimeType)) {
        internalLogger.error(
          'Attempting to setup two plugins of the same type: ${plugin.runtimeType}. The second plugin will be ignored.',
        );
      } else {
        plugin.initialize();
        _plugins[plugin.runtimeType] = plugin;
      }
    }
  }
}
