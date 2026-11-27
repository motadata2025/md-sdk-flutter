// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'dart:io';

import 'package:motadata_common_test/motadata_common_test.dart';
import 'package:motadata_flutter_plugin/motadata_flutter_plugin.dart';
import 'package:motadata_tracking_http_client/motadata_tracking_http_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'scenario_config.dart';
import 'scenario_select_screen.dart';

// This file sets up a different application for testing auto instrumentation
// Using the widgets in this library by themselves won't send any RUM events
// but, by utilizing this entry point instead, we can test that
// auto-instrumentation added to an existing app gives us the expected results.
TestingConfiguration? testingConfiguration;

class ClientListener extends MotadataTrackingHttpClientListener {
  @override
  void requestStarted(
      {required Object resourceKey,
      required HttpClientRequest request,
      required Map<String, Object?> userAttributes}) {
    if (kDebugMode) {
      print('($resourceKey) Request started');
    }
  }

  @override
  void responseFinished(
      {required Object resourceKey,
      required HttpClientResponse response,
      required Map<String, Object?> userAttributes,
      Object? error}) {
    if (kDebugMode) {
      print('($resourceKey) Request finished');
    }
  }
}

Future<void> main() async {
  final merge = kIsWeb ? <String, String>{} : Platform.environment;
  await dotenv.load(mergeWith: merge);

  var clientToken = dotenv.get('DD_CLIENT_TOKEN', fallback: '');
  var applicationId = dotenv.maybeGet('DD_APPLICATION_ID');
  String? customEndpoint = dotenv.maybeGet('DD_CUSTOM_ENDPOINT');

  if (testingConfiguration != null) {
    if (testingConfiguration!.customEndpoint != null) {
      customEndpoint = testingConfiguration!.customEndpoint;
    }
    if (testingConfiguration!.clientToken != null) {
      clientToken = testingConfiguration!.clientToken!;
    }
    if (testingConfiguration!.applicationId != null) {
      applicationId = testingConfiguration!.applicationId;
    }
  }

  final firstPartyHosts = ['motadata.com'];
  if (testingConfiguration != null) {
    firstPartyHosts.addAll(testingConfiguration!.firstPartyHosts);
  }

  MotadataSdk.instance.sdkVerbosity = CoreLoggerLevel.debug;

  final configuration = MotadataConfiguration(
    clientToken: clientToken,
    env: dotenv.get('DD_ENV', fallback: ''),
    site: MotadataSite.us1,
    uploadFrequency: UploadFrequency.frequent,
    batchSize: BatchSize.small,
    nativeCrashReportEnabled: true,
    firstPartyHosts: firstPartyHosts,
    rumConfiguration: applicationId != null
        ? MotadataRumConfiguration(
            detectLongTasks: false,
            applicationId: applicationId,
            traceSampleRate: 100,
            customEndpoint: customEndpoint,
            trackResourceHeaders: ResourceHeadersExtractor(
              captureHeaders: [
                'accept-ranges',
                'content-disposition',
                'server',
                'user-agent',
                'via',
                'x-cache-hits',
                'x-served-by',
                'x-datadog-trace-id',
                'x-datadog-parent-id',
                'x-datadog-origin',
                'traceparent',
              ],
            ),
          )
        : null,
  );
  if (testingConfiguration != null) {
    // Add clear text if we're running an actual test.
    configuration.additionalConfig['_dd.needsClearTextHttp'] = true;
  }

  if (RumAutoInstrumentationScenarioConfig.instance.enableIoHttpTracking) {
    configuration.enableHttpTracking(
      clientListener: ClientListener(),
    );
  }

  await MotadataSdk.runApp(configuration, TrackingConsent.granted, () async {
    // User for testing baggage headers
    MotadataSdk.instance.setUserInfo(id: 'integration_test_user');
    MotadataSdk.instance.setAccountInfo(id: 'integration_test_account');

    runApp(const MotadataAutoIntegrationTestApp());
  });
}

class MotadataAutoIntegrationTestApp extends StatelessWidget {
  const MotadataAutoIntegrationTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final navObserver =
        MotadataNavigationObserver(motadataSdk: MotadataSdk.instance);
    return MotadataNavigationObserverProvider(
      navObserver: navObserver,
      child: MaterialApp(
          title: 'Flutter Demo',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          navigatorObservers: [
            navObserver,
          ],
          home: const ScenarioSelectScreen()),
    );
  }
}
