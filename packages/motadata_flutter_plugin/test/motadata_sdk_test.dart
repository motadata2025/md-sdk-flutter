// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2016-Present Datadog, Inc.

import 'package:motadata_flutter_plugin/motadata_flutter_plugin.dart';
import 'package:motadata_flutter_plugin/motadata_internal.dart';
import 'package:motadata_flutter_plugin/src/rum/ddrum_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMotadataSdkPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements MotadataSdkPlatform {}

class FakeMotadataConfiguration extends Fake implements MotadataConfiguration {}

class MockMotadataPluginConfiguration extends Mock
    implements MotadataPluginConfiguration {}

class MockMotadataPlugin extends Mock implements MotadataPlugin {}

class CapturingMotadataPluginConfiguration extends MotadataPluginConfiguration {
  MotadataConfiguration? configurationOnInitialize;

  @override
  MotadataPlugin create(MotadataSdk motadataInstance) {
    return CapturingMotadataPlugin(
      motadataInstance,
      onInitialize: (configuration) {
        configurationOnInitialize = configuration;
      },
    );
  }
}

class CapturingMotadataPlugin extends MotadataPlugin {
  final void Function(MotadataConfiguration?) onInitialize;

  CapturingMotadataPlugin(
    super.instance, {
    required this.onInitialize,
  });

  @override
  void initialize() {
    onInitialize(instance.configuration);
  }
}

class MockRumPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements MdRumPlatform {}

void main() {
  late MotadataSdk motadataSdk;
  late MockMotadataSdkPlatform mockPlatform;
  late MockRumPlatform mockRumPlatform;

  setUpAll(() {
    registerFallbackValue(TrackingConsent.granted);
    registerFallbackValue(FakeMotadataConfiguration());
    registerFallbackValue(MotadataAttachConfiguration());
    registerFallbackValue(LateConfigurationProperty.trackErrors);
    registerFallbackValue(InternalLogger());
    registerFallbackValue(CoreLoggerLevel.error);
    registerFallbackValue(MotadataRumConfiguration(applicationId: ''));
    registerFallbackValue(MotadataSdk.instance);
  });

  setUp(() {
    mockPlatform = MockMotadataSdkPlatform();
    when(
      () => mockPlatform.initialize(
        any(),
        any(),
        internalLogger: any(named: 'internalLogger'),
        logCallback: any(named: 'logCallback'),
      ),
    ).thenAnswer(
      (_) => Future<PlatformInitializationResult>.value(
        const PlatformInitializationResult(logs: true, rum: true),
      ),
    );
    when(() => mockPlatform.attachToExisting(any())).thenAnswer(
      (_) => Future<AttachResponse?>.value(
        AttachResponse(loggingEnabled: false, rumEnabled: false),
      ),
    );
    when(
      () => mockPlatform.setSdkVerbosity(any()),
    ).thenAnswer((invocation) => Future<void>.value());

    when(
      () => mockPlatform.setUserInfo(any(), any(), any(), any()),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockPlatform.addUserExtraInfo((any())),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockPlatform.clearUserInfo(),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockPlatform.setAccountInfo(any(), any(), any()),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockPlatform.addAccountExtraInfo((any())),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockPlatform.clearAccountInfo(),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockPlatform.setTrackingConsent(any()),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockPlatform.flushAndDeinitialize(),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockPlatform.updateTelemetryConfiguration(any(), any()),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockPlatform.clearAllData(),
    ).thenAnswer((_) => Future<void>.value());
    MotadataSdkPlatform.instance = mockPlatform;
    motadataSdk = MotadataSdk.instance;

    mockRumPlatform = MockRumPlatform();
    when(
      () => mockRumPlatform.enable(any(), any()),
    ).thenAnswer((_) => Future<void>.value());
    when(
      () => mockRumPlatform.deinitialize(),
    ).thenAnswer((_) => Future.value());
    MdRumPlatform.instance = mockRumPlatform;
  });

  tearDown(() async {
    await motadataSdk.flushAndDeinitialize();
  });

  test('initialize passes configuration to platform', () async {
    final configuration = MotadataConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: MotadataSite.us1,
    );
    await motadataSdk.initialize(configuration, TrackingConsent.granted);

    verify(
      () => mockPlatform.initialize(
        configuration,
        TrackingConsent.granted,
        internalLogger: any(named: 'internalLogger'),
        logCallback: any(named: 'logCallback'),
      ),
    );
  });

  test('initialize makes configuration available to plugins', () async {
    final pluginConfiguration = CapturingMotadataPluginConfiguration();
    final configuration = MotadataConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: MotadataSite.us1,
    )..addPlugin(pluginConfiguration);

    await motadataSdk.initialize(configuration, TrackingConsent.granted);

    expect(motadataSdk.configuration, same(configuration));
    expect(pluginConfiguration.configurationOnInitialize, same(configuration));
  });

  test('encode base configuration', () {
    final configuration = MotadataConfiguration(
      clientToken: 'fake-client-token',
      env: 'prod',
      site: MotadataSite.us1,
    );
    final encoded = configuration.encode();
    expect(encoded, {
      'clientToken': 'fake-client-token',
      'env': 'prod',
      'site': 'MotadataSite.us1',
      'nativeCrashReportEnabled': false,
      'service': null,
      'batchSize': null,
      'uploadFrequency': null,
      'batchProcessingLevel': null,
      'additionalConfig': <String, Object?>{},
    });
  });

  test('initialize encoding serializes enums correctly', () {
    final configuration = MotadataConfiguration(
      clientToken: 'fakeClientToken',
      env: 'environment',
      site: MotadataSite.us1,
    )
      ..batchSize = BatchSize.small
      ..uploadFrequency = UploadFrequency.frequent
      ..batchProcessingLevel = BatchProcessingLevel.low
      ..site = MotadataSite.eu1;

    final encoded = configuration.encode();
    expect(encoded['batchSize'], 'BatchSize.small');
    expect(encoded['uploadFrequency'], 'UploadFrequency.frequent');
    expect(encoded['batchProcessingLevel'], 'BatchProcessingLevel.low');
    expect(encoded['site'], 'MotadataSite.eu1');
  });

  test('configuration encodes service name', () {
    final configuration = MotadataConfiguration(
      clientToken: 'fakeClientToken',
      env: 'fake-env',
      service: 'com.servicename',
      site: MotadataSite.us1,
    );

    final encoded = configuration.encode();
    // Logging configuration is purposefully not encoded
    expect(encoded['service'], 'com.servicename');
  });

  test('version added to additionalConfiguration', () {
    final configuration = MotadataConfiguration(
      clientToken: 'fakeClientToken',
      env: 'fake-env',
      site: MotadataSite.us1,
      version: '1.9.8+123',
    );

    final encoded = configuration.encode();
    final additionalConfig =
        encoded['additionalConfig'] as Map<String, Object?>;
    expect(additionalConfig[MotadataConfigKey.version], '1.9.8-123');
  });

  test('flavor added to additionalConfiguration', () {
    final configuration = MotadataConfiguration(
      clientToken: 'fakeClientToken',
      env: 'fake-env',
      site: MotadataSite.us1,
      flavor: 'strawberry',
    );

    final encoded = configuration.encode();
    final additionalConfig =
        encoded['additionalConfig'] as Map<String, Object?>;
    expect(additionalConfig[MotadataConfigKey.variant], 'strawberry');
  });

  test('initialize with rum configuration creates RUM', () async {
    when(
      () => mockPlatform.initialize(
        any(),
        any(),
        internalLogger: any(named: 'internalLogger'),
        logCallback: any(named: 'logCallback'),
      ),
    ).thenAnswer(
      (_) => Future<PlatformInitializationResult>.value(
        const PlatformInitializationResult(logs: true, rum: false),
      ),
    );

    final rumConfiguration = MotadataRumConfiguration(
      applicationId: 'fake-application-id',
      vitalUpdateFrequency: VitalsFrequency.frequent,
      detectLongTasks: false,
    );
    final configuration = MotadataConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: MotadataSite.us1,
      rumConfiguration: rumConfiguration,
    );
    await motadataSdk.initialize(configuration, TrackingConsent.pending);

    final rum = motadataSdk.rum;
    expect(rum, isNotNull);
    verify(() => mockRumPlatform.enable(motadataSdk, rumConfiguration));
  });

  test('attachToExisting calls out to platform', () async {
    await motadataSdk.attachToExisting(MotadataAttachConfiguration());

    verify(() => mockPlatform.attachToExisting(any()));
    expect(motadataSdk.rum, isNull);
  });

  test('attachToExisting forwards creation firstPartyHosts', () async {
    await motadataSdk.attachToExisting(
      MotadataAttachConfiguration(
        firstPartyHosts: ['example.com', 'motadata.com'],
      ),
    );

    expect(motadataSdk.firstPartyHosts.length, 2);
    expect(motadataSdk.firstPartyHosts[0].hostName, 'example.com');
    expect(motadataSdk.firstPartyHosts[0].headerTypes, {
      TracingHeaderType.motadata,
      TracingHeaderType.tracecontext,
    });
    expect(motadataSdk.firstPartyHosts[1].hostName, 'motadata.com');
    expect(motadataSdk.firstPartyHosts[1].headerTypes, {
      TracingHeaderType.motadata,
      TracingHeaderType.tracecontext,
    });
  });

  test('attachToExisting with rumEnabled creates RUM bridge', () async {
    when(() => mockPlatform.attachToExisting(any())).thenAnswer(
      (invocation) => Future<AttachResponse?>.value(
        AttachResponse(loggingEnabled: false, rumEnabled: true),
      ),
    );

    await motadataSdk.attachToExisting(
      MotadataAttachConfiguration(detectLongTasks: false),
    );
    expect(motadataSdk.rum, isNotNull);
  });

  test('attachToExisting with rumEnabled forwards RUM parameters', () async {
    when(() => mockPlatform.attachToExisting(any())).thenAnswer(
      (invocation) => Future<AttachResponse?>.value(
        AttachResponse(loggingEnabled: false, rumEnabled: true),
      ),
    );

    await motadataSdk.attachToExisting(
      MotadataAttachConfiguration(
        longTaskThreshold: 0.5,
        traceSampleRate: 100.0,
        detectLongTasks: false,
      ),
    );

    expect(motadataSdk.rum?.traceSampleRate, 100.0);
  });

  test('first party hosts get set to sdk', () async {
    final configuration = MotadataConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: MotadataSite.us1,
      firstPartyHosts: ['example.com', 'motadata.com'],
    );
    await motadataSdk.initialize(configuration, TrackingConsent.granted);

    expect(motadataSdk.firstPartyHosts.length, 2);
    expect(motadataSdk.firstPartyHosts[0].hostName, 'example.com');
    expect(motadataSdk.firstPartyHosts[0].headerTypes, {
      TracingHeaderType.motadata,
      TracingHeaderType.tracecontext,
    });
    expect(motadataSdk.firstPartyHosts[1].hostName, 'motadata.com');
    expect(motadataSdk.firstPartyHosts[1].headerTypes, {
      TracingHeaderType.motadata,
      TracingHeaderType.tracecontext,
    });
  });

  test('first party hosts with tracing headers set to sdk', () async {
    final configuration = MotadataConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: MotadataSite.us1,
      firstPartyHostsWithTracingHeaders: {
        'example.com': {TracingHeaderType.b3},
        'motadata.com': {TracingHeaderType.motadata},
      },
    );
    await motadataSdk.initialize(configuration, TrackingConsent.pending);

    expect(motadataSdk.firstPartyHosts.length, 2);
    expect(motadataSdk.firstPartyHosts[0].hostName, 'example.com');
    expect(motadataSdk.firstPartyHosts[0].headerTypes, {TracingHeaderType.b3});
    expect(motadataSdk.firstPartyHosts[1].hostName, 'motadata.com');
    expect(motadataSdk.firstPartyHosts[1].headerTypes, {
      TracingHeaderType.motadata,
    });
  });

  test('first party hosts combined tracing headers set to sdk', () async {
    final configuration = MotadataConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: MotadataSite.us1,
      firstPartyHosts: ['motadata.com'],
      firstPartyHostsWithTracingHeaders: {
        'example.com': {TracingHeaderType.b3},
      },
    );
    await motadataSdk.initialize(configuration, TrackingConsent.granted);

    expect(motadataSdk.firstPartyHosts.length, 2);
    expect(motadataSdk.firstPartyHosts[0].hostName, 'example.com');
    expect(motadataSdk.firstPartyHosts[0].headerTypes, {TracingHeaderType.b3});
    expect(motadataSdk.firstPartyHosts[1].hostName, 'motadata.com');
    expect(motadataSdk.firstPartyHosts[1].headerTypes, {
      TracingHeaderType.motadata,
      TracingHeaderType.tracecontext,
    });
  });

  test('headerTypesForHost with no hosts returns empty set', () async {
    final configuration = MotadataConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: MotadataSite.us1,
    );
    await motadataSdk.initialize(configuration, TrackingConsent.granted);

    var uri = Uri.parse('https://first_party');
    expect(motadataSdk.headerTypesForHost(uri), isEmpty);
  });

  test(
    'headerTypesForHost with matching host returns motadata by default',
    () async {
      var firstPartyHosts = ['example.com', 'motadata.com'];

      final configuration = MotadataConfiguration(
        clientToken: 'clientToken',
        env: 'env',
        site: MotadataSite.us1,
        firstPartyHosts: firstPartyHosts,
      );
      await motadataSdk.initialize(configuration, TrackingConsent.pending);

      var uri = Uri.parse('https://motadata.com/path');
      expect(motadataSdk.headerTypesForHost(uri), {
        TracingHeaderType.motadata,
        TracingHeaderType.tracecontext,
      });
    },
  );

  test(
    'headerTypesForHost with matching host with subdomain returns header type',
    () async {
      var firstPartyHosts = ['example.com', 'motadata.com'];

      final configuration = MotadataConfiguration(
        clientToken: 'clientToken',
        env: 'env',
        site: MotadataSite.us1,
        firstPartyHosts: firstPartyHosts,
      );
      await motadataSdk.initialize(configuration, TrackingConsent.pending);

      var uri = Uri.parse('https://test.motadata.com/path');
      expect(motadataSdk.headerTypesForHost(uri), {
        TracingHeaderType.motadata,
        TracingHeaderType.tracecontext,
      });
    },
  );

  test(
    'headerTypesForHost with matching subdomain does not match root',
    () async {
      var firstPartyHosts = ['example.com', 'test.motadata.com'];

      final configuration = MotadataConfiguration(
        clientToken: 'clientToken',
        env: 'env',
        site: MotadataSite.us1,
        firstPartyHosts: firstPartyHosts,
      );
      await motadataSdk.initialize(configuration, TrackingConsent.granted);

      var uri = Uri.parse('https://motadata.com/path');
      expect(motadataSdk.headerTypesForHost(uri), isEmpty);
    },
  );

  test('headerTypesForHost escapes special characters in hosts', () async {
    var firstPartyHosts = ['test.motadata.com'];

    final configuration = MotadataConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: MotadataSite.us1,
      firstPartyHosts: firstPartyHosts,
    );
    await motadataSdk.initialize(configuration, TrackingConsent.pending);

    var uri = Uri.parse('https://testmotadata.com/path');
    expect(motadataSdk.headerTypesForHost(uri), isEmpty);
  });

  test('headerTypesForHost merges header types', () async {
    var firstPartyHosts = {
      'motadata.com': {TracingHeaderType.motadata},
      'test.motadata.com': {TracingHeaderType.b3},
    };

    final configuration = MotadataConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: MotadataSite.us1,
      firstPartyHostsWithTracingHeaders: firstPartyHosts,
    );
    await motadataSdk.initialize(configuration, TrackingConsent.granted);

    var uri = Uri.parse('https://test.motadata.com/path');
    expect(motadataSdk.headerTypesForHost(uri), {
      TracingHeaderType.motadata,
      TracingHeaderType.b3,
    });
  });

  test('firstPartyHosts sanitizes schemas', () async {
    var firstPartyHosts = {
      'https://motadata.com': {TracingHeaderType.motadata},
      'http://test.motadata.com': {TracingHeaderType.b3},
      'ws://ws.motadata.com': {TracingHeaderType.b3multi},
    };

    final configuration = MotadataConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: MotadataSite.us1,
      firstPartyHostsWithTracingHeaders: firstPartyHosts,
    );
    await motadataSdk.initialize(configuration, TrackingConsent.granted);

    expect(motadataSdk.firstPartyHosts.length, 3);
    expect(motadataSdk.firstPartyHosts[0].hostName, 'motadata.com');
    expect(motadataSdk.firstPartyHosts[0].headerTypes, {
      TracingHeaderType.motadata,
    });
    expect(motadataSdk.firstPartyHosts[1].hostName, 'test.motadata.com');
    expect(motadataSdk.firstPartyHosts[1].headerTypes, {TracingHeaderType.b3});
    expect(motadataSdk.firstPartyHosts[2].hostName, 'ws.motadata.com');
    expect(motadataSdk.firstPartyHosts[2].headerTypes, {
      TracingHeaderType.b3multi,
    });
  });

  test('set user info calls into platform', () {
    motadataSdk.setUserInfo(
      id: 'fake_id',
      name: 'fake_name',
      email: 'fake_email',
    );

    verify(
      () => mockPlatform.setUserInfo('fake_id', 'fake_name', 'fake_email', {}),
    );
  });

  test('set user info calls into platform passing extraInfo', () {
    motadataSdk.setUserInfo(
      id: 'fake_id',
      name: 'fake_name',
      email: 'fake_email',
      extraInfo: {'attribute': 32.0},
    );

    verify(
      () => mockPlatform.setUserInfo('fake_id', 'fake_name', 'fake_email', {
        'attribute': 32.0,
      }),
    );
  });

  test('addUserExtraInfo passes through to platform', () {
    motadataSdk.addUserExtraInfo({'example_1': 'test', 'example_2': null});

    verify(
      () => mockPlatform.addUserExtraInfo({
        'example_1': 'test',
        'example_2': null,
      }),
    );
  });

  test('clearUserInfo passes through to platform', () {
    motadataSdk.clearUserInfo();

    verify(() => mockPlatform.clearUserInfo());
  });

  test('set user info calls into platform', () {
    motadataSdk.setUserInfo(
      id: 'fake_id',
      name: 'fake_name',
      email: 'fake_email',
    );

    verify(
      () => mockPlatform.setUserInfo('fake_id', 'fake_name', 'fake_email', {}),
    );
  });

  test('setAccountInfo calls into platform passing extraInfo', () {
    motadataSdk.setAccountInfo(
      id: 'fake_id',
      name: 'fake_name',
      extraInfo: {'attribute': 32.0},
    );

    verify(
      () => mockPlatform.setAccountInfo('fake_id', 'fake_name', {
        'attribute': 32.0,
      }),
    );
  });

  test('addAccountExtraInfo passes through to platform', () {
    motadataSdk.addAccountExtraInfo({'example_1': 'test', 'example_2': null});

    verify(
      () => mockPlatform.addAccountExtraInfo({
        'example_1': 'test',
        'example_2': null,
      }),
    );
  });

  test('clearAccountInfo passes through to platform', () {
    motadataSdk.clearAccountInfo();

    verify(() => mockPlatform.clearAccountInfo());
  });

  test('set tracking consent calls into platform', () {
    motadataSdk.setTrackingConsent(TrackingConsent.notGranted);

    verify(() => mockPlatform.setTrackingConsent(TrackingConsent.notGranted));
  });


  test(
    'plugin added to configuration is created during initialization',
    () async {
      final mockPluginConfig = MockMotadataPluginConfiguration();
      final mockPlugin = MockMotadataPlugin();
      when(
        () => mockPluginConfig.create(motadataSdk),
      ).thenAnswer((_) => mockPlugin);

      final config = MotadataConfiguration(
        clientToken: 'fake_token',
        env: 'env',
        site: MotadataSite.us1,
      )..addPlugin(mockPluginConfig);

      await motadataSdk.initialize(config, TrackingConsent.pending);

      verify(() => mockPluginConfig.create(motadataSdk));
      verify(() => mockPlugin.initialize());
      expect(motadataSdk.getPlugin<MockMotadataPlugin>(), mockPlugin);
    },
  );

  test(
    'plugin added to configuration is created during attachToExisting',
    () async {
      when(() => mockPlatform.attachToExisting(any())).thenAnswer(
        (invocation) => Future<AttachResponse?>.value(
          AttachResponse(loggingEnabled: false, rumEnabled: false),
        ),
      );

      final mockPluginConfig = MockMotadataPluginConfiguration();
      final mockPlugin = MockMotadataPlugin();
      when(
        () => mockPluginConfig.create(motadataSdk),
      ).thenAnswer((_) => mockPlugin);

      final config = MotadataAttachConfiguration()..addPlugin(mockPluginConfig);

      await motadataSdk.attachToExisting(config);

      verify(() => mockPluginConfig.create(motadataSdk));
      verify(() => mockPlugin.initialize());
      expect(motadataSdk.getPlugin<MockMotadataPlugin>(), mockPlugin);
    },
  );

  test('updateConfigurationInfo calls to platform', () async {
    final configuration = MotadataConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: MotadataSite.us1,
    );
    await motadataSdk.initialize(configuration, TrackingConsent.pending);

    motadataSdk.updateConfigurationInfo(
      LateConfigurationProperty.trackInteractions,
      true,
    );
    motadataSdk.updateConfigurationInfo(
      LateConfigurationProperty.trackViewsManually,
      false,
    );

    verify(
      () =>
          mockPlatform.updateTelemetryConfiguration('trackInteractions', true),
    );
    verify(
      () => mockPlatform.updateTelemetryConfiguration(
        'trackViewsManually',
        false,
      ),
    );
  });

  test('clearAllData calls to platform', () async {
    final configuration = MotadataConfiguration(
      clientToken: 'clientToken',
      env: 'env',
      site: MotadataSite.us1,
    );
    await motadataSdk.initialize(configuration, TrackingConsent.pending);

    motadataSdk.clearAllData();

    verify(() => mockPlatform.clearAllData());
  });
}
