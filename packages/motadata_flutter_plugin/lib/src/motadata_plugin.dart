// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:flutter/material.dart';

import '../motadata_flutter_plugin.dart';

abstract class MotadataPluginConfiguration {
  const MotadataPluginConfiguration();

  MotadataPlugin create(MotadataSdk motadataInstance);

  /// Indicate that this plugin can be used from and initialized from background
  /// isolates when [MotadataSdk.attachToBackgroundIsolate] is called. Plugins
  /// that have this set to `true` will have
  /// [MotadataPlugin.initializeFromBackgroundIsolate] called when background
  /// isolate is attached, which by default calls [MotadataPlugin.initialize].
  ///
  /// Any subclass that has this flag set to `true` must also be marked as
  /// [immutable] so that the configuration can be sent to the background isolate.
  ///
  /// If this flag is set to `false` (the default), no initialization of the
  /// plugin will occur when Motadata is attached to a background isolate, which
  /// may mean the features of this plugin will not be available.
  bool get supportsBackgroundIsolates => false;
}

abstract class MotadataPlugin {
  @protected
  final MotadataSdk instance;

  MotadataPlugin(this.instance);

  void initialize();
  void initializeFromBackgroundIsolate() {
    initialize();
  }

  void shutdown() {}
}
