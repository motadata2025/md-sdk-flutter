// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:jni/jni.dart';

import '../../motadata_internal.dart';
import 'motadata_android_bridge.dart' as bridge;

class AndroidMotadataFlutterPlugin {
  static final JString _javaRumKey = JString.fromString('rum');
  static final JString _javaSessionId = JString.fromString('session_id');

  static MotadataContext? getContext() {
    final javaContext = bridge.MotadataSdkPlugin.Companion.getCoreContext();
    if (javaContext == null) return null;

    String? sessionId;
    final rumContext = javaContext.getFeaturesContext()[_javaRumKey];
    if (rumContext != null) {
      final javaSessionId = rumContext[_javaSessionId];
      if (javaSessionId != null) {
        sessionId = javaSessionId.toString();
        javaSessionId.release();
      }
    }

    final context = MotadataContext(
      sessionId: sessionId,
      accountId: javaContext.getAccountInfo()?.getId().toDartString(),
      userId: javaContext.getUserInfo().getId()?.toDartString(),
    );
    javaContext.release();
    return context;
  }
}
