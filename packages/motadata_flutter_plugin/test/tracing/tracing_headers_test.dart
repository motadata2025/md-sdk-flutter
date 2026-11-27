// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'package:motadata_common_test/motadata_common_test.dart';
import 'package:motadata_flutter_plugin/motadata_flutter_plugin.dart';
import 'package:motadata_flutter_plugin/motadata_internal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMotadataSdk extends Mock implements MotadataSdk {}

class MockMotadataPlatform extends Mock implements MotadataSdkPlatform {}

class MockDdRum extends Mock implements MotadataRum {}

void main() {
  late MockMotadataSdk mockSdk;
  late MockMotadataPlatform mockPlatform;
  late MockDdRum mockRum;

  setUp(() {
    registerFallbackValue(TracingId(BigInt.one));

    mockPlatform = MockMotadataPlatform();

    mockSdk = MockMotadataSdk();
    when(() => mockSdk.platform).thenReturn(mockPlatform);

    mockRum = MockDdRum();
    when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
  });

  test('TracingIdRepresentation generates proper values', () {
    // Create a value in 128-bit hex that has leading zeros on both
    // the low and high 64-bits, and ensure we get the proper values
    const low0 = 0xd89934bb;
    const low32 = 0x01445fee;
    const high0 = 0xd89934ba;
    const high32 = 0x01222f00;

    var combined = BigInt.from(high32);
    combined = (combined << 32) + BigInt.from(high0);
    combined = (combined << 32) + BigInt.from(low32);
    combined = (combined << 32) + BigInt.from(low0);

    final tracingId = TracingId(combined);

    expect(
      tracingId.asString(TracingIdRepresentation.hex),
      '1222f00d89934ba01445feed89934bb',
    );
    expect(
      tracingId.asString(TracingIdRepresentation.hex32Chars),
      '01222f00d89934ba01445feed89934bb',
    );
    expect(
      tracingId.asString(TracingIdRepresentation.hex16Chars),
      '01445feed89934bb',
    );
    expect(
      tracingId.asString(TracingIdRepresentation.highHex16Chars),
      '01222f00d89934ba',
    );
    expect(
      tracingId.asString(TracingIdRepresentation.decimal),
      '1506719429260448406838152867989763259',
    );
    expect(
      tracingId.asString(TracingIdRepresentation.lowDecimal),
      '91303371895026875',
    );
  });

  test('traceId generates proper values', () {
    final nowSeconds = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final traceId = TracingId.traceId();

    final traceIdString = traceId.asString(TracingIdRepresentation.hex);
    int traceSeconds = int.parse(traceIdString.substring(0, 8), radix: 16);
    expect(traceSeconds, closeTo(nowSeconds, 1));
    expect('00000000', traceIdString.substring(8, 16));
    expect(traceIdString.substring(16), isNot('0000000000000000'));
  });

  test('generateTracingContext generates proper bit values', () {
    final context = generateTracingContext(mockSdk, mockRum);

    expect(context.traceId.value.bitLength, lessThanOrEqualTo(128));
    expect(context.spanId.value.bitLength, lessThanOrEqualTo(63));
    expect(context.sampled, true);
  });

  test('Motadata attributes generated correctly', () {
    final context = generateTracingContext(mockSdk, mockRum);

    final attributes = generateMotadataAttributes(context, 30.0);

    expect(
      attributes['_dd.trace_id'],
      context.traceId.asString(TracingIdRepresentation.hex32Chars),
    );
    expect(
      attributes['_dd.span_id'],
      context.spanId.asString(TracingIdRepresentation.decimal),
    );
    expect(attributes['_dd.rule_psr'], 0.3);
  });

  test('Unsampled context does not generate motadata attributes', () {
    when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
    final context = generateTracingContext(mockSdk, mockRum);

    final attributes = generateMotadataAttributes(context, 30.0);

    expect(attributes['_dd.trace_id'], isNull);
    expect(attributes['_dd.span_id'], isNull);
    expect(attributes['_dd.rule_psr'], 0.3);
  });

  // The TraceContextInjection value shouldn't matter in the sampled cases, so
  // make sure all tests work the same way for all TraceContextInjection options
  for (final contextInjection in TraceContextInjection.values) {
    test(
      'Motadata tracing headers are generated correctly { $contextInjection, sampled }',
      () {
        final context = generateTracingContext(mockSdk, mockRum);

        final headers = <String, String>{};
        injectTracingHeaders(
          context,
          TracingHeaderType.motadata,
          headers,
          contextInjection: contextInjection,
        );

        expect(
          headers['x-datadog-trace-id'],
          context.traceId.asString(TracingIdRepresentation.lowDecimal),
        );
        expect(
          headers['x-datadog-tags'],
          '_dd.p.tid=${context.traceId.asString(TracingIdRepresentation.highHex16Chars)}',
        );
        expect(
          headers['x-datadog-parent-id'],
          context.spanId.asString(TracingIdRepresentation.decimal),
        );
        expect(headers['x-datadog-sampling-priority'], '1');
        expect(headers['x-datadog-origin'], 'rum');
      },
    );

    test(
      'b3 tracing headers are generated correctly { $contextInjection, sampled }',
      () {
        final context = generateTracingContext(mockSdk, mockRum);

        final headers = <String, String>{};
        injectTracingHeaders(
          context,
          TracingHeaderType.b3,
          headers,
          contextInjection: contextInjection,
        );

        final traceString = context.traceId.asString(
          TracingIdRepresentation.hex32Chars,
        );
        final spanString = context.spanId.asString(
          TracingIdRepresentation.hex16Chars,
        );
        final expectedHeader = '$traceString-$spanString-1'.toLowerCase();

        expect(headers['b3'], expectedHeader);
      },
    );

    test(
      'b3multi tracing headers are generated correctly { $contextInjection, sampled }',
      () {
        final context = generateTracingContext(mockSdk, mockRum);

        final headers = <String, String>{};
        injectTracingHeaders(
          context,
          TracingHeaderType.b3multi,
          headers,
          contextInjection: contextInjection,
        );

        final traceString = context.traceId.asString(
          TracingIdRepresentation.hex32Chars,
        );
        final spanString = context.spanId.asString(
          TracingIdRepresentation.hex16Chars,
        );

        expect(headers['X-B3-TraceId'], traceString.toLowerCase());
        expect(headers['X-B3-SpanId'], spanString.toLowerCase());
        expect(headers['X-B3-ParentSpanId'], isNull);
        expect(headers['X-B3-Sampled'], '1');
      },
    );

    test(
      'tracecontext tracing headers are generated correctly { $contextInjection, sampled }',
      () {
        final context = generateTracingContext(mockSdk, mockRum);

        final headers = <String, String>{};
        injectTracingHeaders(
          context,
          TracingHeaderType.tracecontext,
          headers,
          contextInjection: contextInjection,
        );

        final traceString = context.traceId.asString(
          TracingIdRepresentation.hex32Chars,
        );
        final spanString = context.spanId.asString(
          TracingIdRepresentation.hex16Chars,
        );
        final expectedParentHeader = '00-$traceString-$spanString-01';
        final expectedStateHeader = 'dd=s:1;o:rum;p:$spanString';

        expect(headers['traceparent'], expectedParentHeader.toLowerCase());
        expect(headers['tracestate'], expectedStateHeader.toLowerCase());
      },
    );

    test(
      'Motadata tracing headers generate baggage header { $contextInjection, sampled }',
      () {
        // Given
        final motadataContext = MotadataContext(
          sessionId: randomString(),
          accountId: randomString(),
          userId: randomString(),
        );
        when(() => mockPlatform.getContext()).thenReturn(motadataContext);

        when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
        final context = generateTracingContext(mockSdk, mockRum);

        // When
        final headers = <String, String>{};
        injectTracingHeaders(
          context,
          TracingHeaderType.motadata,
          headers,
          contextInjection: TraceContextInjection.sampled,
        );

        // Then
        final baggage = headers['baggage'];
        final baggageValues = baggage!.split(',');
        expect(
            baggageValues, contains('session.id=${motadataContext.sessionId}'));
        expect(baggageValues, contains('user.id=${motadataContext.userId}'));
        expect(
          baggageValues,
          contains('account.id=${motadataContext.accountId}'),
        );
      },
    );

    test(
      'tracecontext tracing headers generate baggage header { $contextInjection, sampled }',
      () {
        // Given
        final motadataContext = MotadataContext(
          sessionId: randomString(),
          accountId: randomString(),
          userId: randomString(),
        );
        when(() => mockPlatform.getContext()).thenReturn(motadataContext);

        when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
        final context = generateTracingContext(mockSdk, mockRum);

        // When
        final headers = <String, String>{};
        injectTracingHeaders(
          context,
          TracingHeaderType.tracecontext,
          headers,
          contextInjection: TraceContextInjection.sampled,
        );

        // Then
        final baggage = headers['baggage'];
        final baggageValues = baggage!.split(',');
        expect(
            baggageValues, contains('session.id=${motadataContext.sessionId}'));
        expect(baggageValues, contains('user.id=${motadataContext.userId}'));
        expect(
          baggageValues,
          contains('account.id=${motadataContext.accountId}'),
        );
      },
    );
  }

  test(
    'Motadata tracing headers are generated correctly { TraceContextInjection.all, unsampled }',
    () {
      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
      final context = generateTracingContext(mockSdk, mockRum);

      final headers = <String, String>{};
      injectTracingHeaders(
        context,
        TracingHeaderType.motadata,
        headers,
        contextInjection: TraceContextInjection.all,
      );

      expect(
        headers['x-datadog-trace-id'],
        context.traceId.asString(TracingIdRepresentation.lowDecimal),
      );
      expect(
        headers['x-datadog-tags'],
        '_dd.p.tid=${context.traceId.asString(TracingIdRepresentation.highHex16Chars)}',
      );
      expect(
        headers['x-datadog-parent-id'],
        context.spanId.asString(TracingIdRepresentation.decimal),
      );
      expect(headers['x-datadog-sampling-priority'], '0');
      expect(headers['x-datadog-origin'], 'rum');
    },
  );

  test(
    'Motadata tracing headers are generated correctly { TraceContextInjection.sampled, unsampled }',
    () {
      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
      final context = generateTracingContext(mockSdk, mockRum);

      final headers = <String, String>{};
      injectTracingHeaders(
        context,
        TracingHeaderType.motadata,
        headers,
        contextInjection: TraceContextInjection.sampled,
      );

      expect(headers['x-datadog-trace-id'], isNull);
      expect(headers['x-datadog-parent-id'], isNull);
      expect(headers['x-datadog-sampling-priority'], isNull);
      expect(headers['x-datadog-origin'], isNull);
    },
  );

  test(
    'Motadata tracing headers generate baggage header { TraceContextInjection.all, unsampled }',
    () {
      // Given
      final motadataContext = MotadataContext(
        sessionId: randomString(),
        accountId: randomString(),
        userId: randomString(),
      );
      when(() => mockPlatform.getContext()).thenReturn(motadataContext);
      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
      final context = generateTracingContext(mockSdk, mockRum);

      // When
      final headers = <String, String>{};
      injectTracingHeaders(
        context,
        TracingHeaderType.motadata,
        headers,
        contextInjection: TraceContextInjection.all,
      );

      // Then
      final baggage = headers['baggage'];
      final baggageValues = baggage!.split(',');
      expect(baggageValues, contains('session.id=${motadataContext.sessionId}'));
      expect(baggageValues, contains('user.id=${motadataContext.userId}'));
      expect(baggageValues, contains('account.id=${motadataContext.accountId}'));
    },
  );

  test(
    'Motadata tracing headers generate baggage header { TraceContextInjection.sampled, unsampled }',
    () {
      // Given
      final motadataContext = MotadataContext(
        sessionId: randomString(),
        accountId: randomString(),
        userId: randomString(),
      );
      when(() => mockPlatform.getContext()).thenReturn(motadataContext);

      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
      final context = generateTracingContext(mockSdk, mockRum);

      // When
      final headers = <String, String>{};
      injectTracingHeaders(
        context,
        TracingHeaderType.motadata,
        headers,
        contextInjection: TraceContextInjection.sampled,
      );

      // Then
      final baggage = headers['baggage'];
      expect(baggage, isNull);
    },
  );

  test(
    'tracecontext tracing headers generate baggage header { TraceContextInjection.all, unsampled }',
    () {
      // Given
      final motadataContext = MotadataContext(
        sessionId: randomString(),
        accountId: randomString(),
        userId: randomString(),
      );
      when(() => mockPlatform.getContext()).thenReturn(motadataContext);

      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
      final context = generateTracingContext(mockSdk, mockRum);

      // When
      final headers = <String, String>{};
      injectTracingHeaders(
        context,
        TracingHeaderType.tracecontext,
        headers,
        contextInjection: TraceContextInjection.all,
      );

      // Then
      final baggage = headers['baggage'];
      final baggageValues = baggage!.split(',');
      expect(baggageValues, contains('session.id=${motadataContext.sessionId}'));
      expect(baggageValues, contains('user.id=${motadataContext.userId}'));
      expect(baggageValues, contains('account.id=${motadataContext.accountId}'));
    },
  );

  test(
    'tracecontext tracing headers generate baggage header { TraceContextInjection.sampled, unsampled }',
    () {
      // Given
      final motadataContext = MotadataContext(
        sessionId: randomString(),
        accountId: randomString(),
        userId: randomString(),
      );
      when(() => mockPlatform.getContext()).thenReturn(motadataContext);

      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
      final context = generateTracingContext(mockSdk, mockRum);

      // When
      final headers = <String, String>{};
      injectTracingHeaders(
        context,
        TracingHeaderType.tracecontext,
        headers,
        contextInjection: TraceContextInjection.sampled,
      );

      // Then
      final baggage = headers['baggage'];
      expect(baggage, isNull);
    },
  );

  test('Default for tracing headers is TraceContextInjection.sampled', () {
    when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
    final context = generateTracingContext(mockSdk, mockRum);

    final headers = <String, String>{};
    injectTracingHeaders(context, TracingHeaderType.motadata, headers);

    expect(headers['x-datadog-trace-id'], isNull);
    expect(headers['x-datadog-parent-id'], isNull);
    expect(headers['x-datadog-sampling-priority'], isNull);
    expect(headers['x-datadog-origin'], isNull);
  });

  test(
    'b3 tracing headers are generated correctly { TraceContextInjection.all, unsampled }',
    () {
      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
      final context = generateTracingContext(mockSdk, mockRum);

      final headers = <String, String>{};
      injectTracingHeaders(
        context,
        TracingHeaderType.b3,
        headers,
        contextInjection: TraceContextInjection.all,
      );

      expect(headers['b3'], '0');
    },
  );

  test(
    'b3 tracing headers are generated correctly { TraceContextInjection.sampled, unsampled }',
    () {
      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
      final context = generateTracingContext(mockSdk, mockRum);

      final headers = <String, String>{};
      injectTracingHeaders(
        context,
        TracingHeaderType.b3,
        headers,
        contextInjection: TraceContextInjection.sampled,
      );

      expect(headers['b3'], isNull);
    },
  );

  test(
    'b3multi tracing headers are generated correctly { TraceContextInjection.all, unsampled }',
    () {
      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
      final context = generateTracingContext(mockSdk, mockRum);

      final headers = <String, String>{};
      injectTracingHeaders(
        context,
        TracingHeaderType.b3multi,
        headers,
        contextInjection: TraceContextInjection.all,
      );

      expect(headers['X-B3-TraceId'], isNull);
      expect(headers['X-B3-SpanId'], isNull);
      expect(headers['X-B3-ParentSpanId'], isNull);
      expect(headers['X-B3-Sampled'], '0');
    },
  );

  test(
    'b3multi tracing headers are generated correctly { TraceContextInjection.sampled, unsampled }',
    () {
      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
      final context = generateTracingContext(mockSdk, mockRum);

      final headers = <String, String>{};
      injectTracingHeaders(
        context,
        TracingHeaderType.b3multi,
        headers,
        contextInjection: TraceContextInjection.sampled,
      );

      expect(headers['X-B3-TraceId'], isNull);
      expect(headers['X-B3-SpanId'], isNull);
      expect(headers['X-B3-ParentSpanId'], isNull);
      expect(headers['X-B3-Sampled'], isNull);
    },
  );

  test(
    'traceparent tracing headers are generated correctly { TraceContextInjection.all, unsampled }',
    () {
      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
      final context = generateTracingContext(mockSdk, mockRum);

      final headers = <String, String>{};
      injectTracingHeaders(
        context,
        TracingHeaderType.tracecontext,
        headers,
        contextInjection: TraceContextInjection.all,
      );

      final traceString = context.traceId.asString(
        TracingIdRepresentation.hex32Chars,
      );
      final spanString = context.spanId.asString(
        TracingIdRepresentation.hex16Chars,
      );
      final expectedParentHeader = '00-$traceString-$spanString-00';
      final expectedStateHeader = 'dd=s:0;o:rum;p:$spanString';

      expect(headers['traceparent'], expectedParentHeader.toLowerCase());
      expect(headers['tracestate'], expectedStateHeader.toLowerCase());
    },
  );

  test(
    'traceparent tracing headers are generated correctly { TraceContextInjection.all, unsampled }',
    () {
      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(false);
      final context = generateTracingContext(mockSdk, mockRum);

      final headers = <String, String>{};
      injectTracingHeaders(
        context,
        TracingHeaderType.tracecontext,
        headers,
        contextInjection: TraceContextInjection.sampled,
      );

      expect(headers['traceparent'], isNull);
      expect(headers['tracestate'], isNull);
    },
  );

  group('baggage header merging', () {
    test('no baggage header creates new header', () {
      // Given
      String? oldBaggage;
      final motadataContext = MotadataContext(
        sessionId: randomString(),
        accountId: randomString(),
        userId: randomString(),
      );
      when(() => mockPlatform.getContext()).thenReturn(motadataContext);

      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
      final context = generateTracingContext(mockSdk, mockRum);

      // When
      String newBaggage = mergeW3CBaggageHeader(context, oldBaggage);

      // Then
      final baggageValues = newBaggage.split(',');
      expect(baggageValues, contains('session.id=${motadataContext.sessionId}'));
      expect(baggageValues, contains('user.id=${motadataContext.userId}'));
      expect(baggageValues, contains('account.id=${motadataContext.accountId}'));
    });

    test('existing baggage header adds new values', () {
      // Given
      String oldBaggage = 'test_value_1=1,test_value_2=string';
      final motadataContext = MotadataContext(
        sessionId: randomString(),
        accountId: randomString(),
        userId: randomString(),
      );
      when(() => mockPlatform.getContext()).thenReturn(motadataContext);

      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
      final context = generateTracingContext(mockSdk, mockRum);

      // When
      String newBaggage = mergeW3CBaggageHeader(context, oldBaggage);

      // Then
      final baggageValues = newBaggage.split(',');
      // Old values are unmodified
      expect(baggageValues, contains('test_value_1=1'));
      expect(baggageValues, contains('test_value_2=string'));

      expect(baggageValues, contains('session.id=${motadataContext.sessionId}'));
      expect(baggageValues, contains('user.id=${motadataContext.userId}'));
      expect(baggageValues, contains('account.id=${motadataContext.accountId}'));
    });

    test('existing baggage header overwrites existing values', () {
      // Given
      String oldBaggage = 'session.id=old_value,test_value_2=string';
      final motadataContext = MotadataContext(
        sessionId: randomString(),
        accountId: randomString(),
        userId: randomString(),
      );
      when(() => mockPlatform.getContext()).thenReturn(motadataContext);

      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
      final context = generateTracingContext(mockSdk, mockRum);

      // When
      String newBaggage = mergeW3CBaggageHeader(context, oldBaggage);

      // Then
      final baggageValues = newBaggage.split(',');
      // Old values are unmodified
      expect(baggageValues, contains('test_value_2=string'));

      // Session.id is overwritten
      expect(baggageValues, contains('session.id=${motadataContext.sessionId}'));
    });

    test('baggage header merge deals with complicated baggage', () {
      // Given
      String oldBaggage =
          ' toto=1,car= Dacia Sandero ,session.id = 2,testProp=1; testProp2=4;prop3 ';
      final motadataContext = MotadataContext(
        sessionId: randomString(),
        accountId: randomString(),
        userId: randomString(),
      );
      when(() => mockPlatform.getContext()).thenReturn(motadataContext);

      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
      final context = generateTracingContext(mockSdk, mockRum);

      // When
      String newBaggage = mergeW3CBaggageHeader(context, oldBaggage);

      // Then
      final baggageValues = newBaggage.split(',');
      // Old values are unmodified
      expect(baggageValues, contains('toto=1'));
      expect(baggageValues, contains('car=Dacia Sandero'));
      expect(baggageValues, contains('testProp=1; testProp2=4;prop3'));

      // New values are appended or overwritten
      expect(baggageValues, contains('session.id=${motadataContext.sessionId}'));
      expect(baggageValues, contains('user.id=${motadataContext.userId}'));
      expect(baggageValues, contains('account.id=${motadataContext.accountId}'));
    });

    test(
      'baggage header merge percent encodes spaces and non-ASCII characters',
      () {
        // Given
        String oldBaggage =
            ' toto=1,session.id = 2,testProp=1; testProp2=4;prop3 ';
        final motadataContext = MotadataContext(
          sessionId: '😅',
          accountId: 'account,2\\3',
          userId: 'Amélie',
        );
        when(() => mockPlatform.getContext()).thenReturn(motadataContext);

        when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
        final context = generateTracingContext(mockSdk, mockRum);

        // When
        String newBaggage = mergeW3CBaggageHeader(context, oldBaggage);

        // Then
        final baggageValues = newBaggage.split(',');
        // Old values are unmodified
        expect(baggageValues, contains('toto=1'));
        expect(baggageValues, contains('testProp=1; testProp2=4;prop3'));

        // New values are appended or overwritten
        expect(baggageValues, contains('account.id=account%2C2%5C3'));
        expect(baggageValues, contains('session.id=%F0%9F%98%85'));
        expect(baggageValues, contains('user.id=Am%C3%A9lie'));
      },
    );

    test('baggage header preserves percent encoding', () {
      // Given
      String oldBaggage =
          ' toto=1,session.id = 2,testProp=1; testProp2=4;prop3 ';
      final motadataContext = MotadataContext(
        sessionId: '😅',
        accountId: 'accountId%id',
        userId: 'Dacia%20Sandero',
      );
      when(() => mockPlatform.getContext()).thenReturn(motadataContext);

      when(() => mockRum.shouldSampleTrace(any(), any())).thenReturn(true);
      final context = generateTracingContext(mockSdk, mockRum);

      // When
      String newBaggage = mergeW3CBaggageHeader(context, oldBaggage);

      // Then
      final baggageValues = newBaggage.split(',');
      // Old values are unmodified
      expect(baggageValues, contains('toto=1'));
      expect(baggageValues, contains('testProp=1; testProp2=4;prop3'));

      // New values are appended or overwritten
      expect(baggageValues, contains('session.id=%F0%9F%98%85'));
      expect(baggageValues, contains('user.id=Dacia%20Sandero'));
      expect(baggageValues, contains('account.id=accountId%25id'));
    });
  });
}
