// ignore_for_file: invalid_use_of_internal_member

import 'dart:async';
import 'dart:io';

import 'package:motadata_flutter_plugin/motadata_flutter_plugin.dart';
import 'package:motadata_flutter_plugin/motadata_internal.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// A callback function that allows you to provide attributes that should be
/// attached to a Motadata RUM resource created from [MotadataClient]. This
/// callback is called when the resource is finished loading, so the provided
/// [request] and [response] streams are already closed.
///
/// If there was an error performing the request, this callback provides the
/// [error] and, depending on the timing of the error, may send null in the
/// [response].
///
/// If this function throws, it will prevent proper tracking of this resource.
typedef MotadataClientAttributesProvider = Map<String, Object?> Function(
    http.BaseRequest request, http.StreamedResponse? response, Object? error);

/// A composable client for use with the `http` package that supports tracking
/// network requests and sending them to Motadata.
///
/// If the RUM feature is enabled, the SDK will send information about RUM
/// Resources (calling [MotadataRum.startResource], [MotadataRum.stopResource], and
/// [MotadataRum.stopResourceWithErrorInfo]) for all intercepted requests.
///
/// This can additionally set tracing headers on your requests, which allows for
/// distributed tracing. You can set which format of tracing header using the
/// [tracingHeaderTypes] parameter. Multiple tracing formats are allowed. The
/// percentage of resources traced in this way is determined by
/// [MotadataRumConfiguration.traceSampleRate].
///
/// To specify which hosts are 1st party (and therefore should have tracing
/// Spans sent), see [MotadataConfiguration.firstPartyHosts]. You can also set
/// first party hosts after initialization by setting [MotadataSdk.firstPartyHosts]
///
/// If you need to ignore specific endpoints, for example if you are using
/// another tracking library like `motadata_gql_link`, you can ignore specific
/// url patterns with the [ignoreUrlPatterns] parameter. Any URLs that are match
/// any of the provided regular expressions will not be tracked by this client.
///
/// MotadataClient only modifies calls made through itself, unlike
/// [MotadataTrackingHttpClient], which overrides all calls made by [HttpClient]
/// and includes network calls made by the Flutter SDK. However, MotadataClient
/// allows you to compose with other [http.BaseClient] based libraries like
/// `cupertino_http` and `cronet_http`, which [MotadataTrackingHttpClient] would
/// miss.
///
/// MotadataClient and [MotadataTrackingHttpClient] can be used together if
/// needed, and will not interfere with each other.
///
/// See also [MotadataTrackingHttpClient]
class MotadataClient extends http.BaseClient {
  final MotadataSdk motadataSdk;
  final Uuid _uuid = const Uuid();
  final MotadataClientAttributesProvider? attributesProvider;
  final List<RegExp> ignoreUrlPatterns;
  final http.Client _innerClient;

  MotadataClient({
    required this.motadataSdk,
    this.attributesProvider,
    this.ignoreUrlPatterns = const [],
    http.Client? innerClient,
  }) : _innerClient = innerClient ?? http.Client() {
    motadataSdk.updateConfigurationInfo(
        LateConfigurationProperty.trackNetworkRequests, true);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final rum = motadataSdk.rum;
    // Never track on web
    if (kIsWeb || rum == null) {
      return _innerClient.send(request);
    }

    return _trackingSend(request, motadataSdk, rum);
  }

  Future<http.StreamedResponse> _trackingSend(
      http.BaseRequest request, MotadataSdk sdk, MotadataRum rum) async {
    String? rumKey;

    if (_shouldTrackRequest(request)) {
      try {
        final tracingHeaders = motadataSdk.headerTypesForHost(request.url);
        final rumHttpMethod = rumMethodFromMethodString(request.method);
        var attributes = <String, Object?>{};
        // Is first party?
        if (tracingHeaders.isNotEmpty) {
          var context = generateTracingContext(sdk, rum);

          attributes = _appendRequestHeaders(
            request,
            context,
            tracingHeaders,
            rum.contextInjectionSetting,
          );
        }

        rumKey = _uuid.v1();
        rum.startResource(
            rumKey, rumHttpMethod, request.url.toString(), attributes);
      } catch (e, st) {
        motadataSdk.internalLogger.sendToMotadata(
          '$MotadataClient encountered an error while attempting'
          ' to track a send call: $e',
          st,
          e.runtimeType.toString(),
        );
        // Since there was an error, don't attempt any more tracking
        rumKey = null;
      }
    }

    http.StreamedResponse response;
    try {
      response = await _innerClient.send(request);
    } catch (e) {
      if (rumKey != null) {
        try {
          final attributes = attributesProvider?.call(request, null, e) ?? {};
          rum.stopResourceWithErrorInfo(
              rumKey, e.toString(), e.runtimeType.toString(), attributes);
        } catch (innerE, st) {
          motadataSdk.internalLogger.sendToMotadata(
            '$MotadataClient encountered an error while attempting '
            ' to track a send - error: $e',
            st,
            e.runtimeType.toString(),
          );
          rumKey = null;
        }
      }

      rethrow;
    }

    if (rumKey != null) {
      try {
        // Copy the response so we can spy on the stream.
        final spyStream = StreamController<List<int>>();
        Object? firstError;
        int? bytesReceived;

        response.stream.listen(
          (List<int> data) {
            bytesReceived ??= 0;
            bytesReceived = bytesReceived! + data.length;
            spyStream.sink.add(data);
          },
          onError: (Object e, StackTrace? st) {
            if (firstError == null) {
              firstError = e;
              final attributes =
                  attributesProvider?.call(request, response, e) ?? {};
              rum.stopResourceWithErrorInfo(
                rumKey!,
                firstError.toString(),
                firstError.runtimeType.toString(),
                attributes,
              );
            }
            spyStream.addError(e, st);
          },
          onDone: () {
            if (rumKey != null) {
              final attributes =
                  attributesProvider?.call(request, response, null) ?? {};
              final size = response.contentLength ?? bytesReceived;
              _onFinish(
                  rum, rumKey, request, response, attributes, firstError, size);
            }
            spyStream.close();
          },
        );

        response = http.StreamedResponse(
          spyStream.stream,
          response.statusCode,
          contentLength: response.contentLength,
          request: response.request,
          headers: response.headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase,
        );
      } catch (e, st) {
        motadataSdk.internalLogger.sendToMotadata(
          '$MotadataClient encountered an error while attempting '
          ' to spy on a response stream: $e',
          st,
          e.runtimeType.toString(),
        );
      }
    }

    return response;
  }

  bool _shouldTrackRequest(http.BaseRequest request) {
    for (final pattern in ignoreUrlPatterns) {
      if (pattern.hasMatch(request.url.toString())) {
        return false;
      }
    }
    return true;
  }

  void _onFinish(
      MotadataRum rum,
      String rumKey,
      http.BaseRequest request,
      http.StreamedResponse response,
      Map<String, Object?> attributes,
      Object? error,
      int? size) {
    try {
      // If we saw an error, this resource has already been stopped
      if (error == null) {
        final contentTypeHeader =
            response.headers[HttpHeaders.contentTypeHeader];
        final contentType = contentTypeHeader != null
            ? ContentType.parse(contentTypeHeader)
            : ContentType.text;
        var resourceType = resourceTypeFromContentType(contentType);
        final extractor = rum.resourceHeadersExtractor;
        if (extractor != null) {
          final headerAttrs = extractor.toResourceAttributes(
            request.headers.map((k, v) => MapEntry(k, [v])),
            response.headers.map((k, v) => MapEntry(k, [v])),
          );
          attributes = {...attributes, ...headerAttrs};
        }
        motadataSdk.rum?.stopResource(
          rumKey,
          response.statusCode,
          resourceType,
          size,
          attributes,
        );
      }
    } catch (e, st) {
      motadataSdk.internalLogger.sendToMotadata(
        '$MotadataClient encountered an error while attempting '
        ' to finish a resource: $e',
        st,
        e.runtimeType.toString(),
      );
    }
  }

  Map<String, Object?> _appendRequestHeaders(
    http.BaseRequest request,
    TracingContext context,
    Set<TracingHeaderType> tracingHeaderTypes,
    TraceContextInjection contextInjection,
  ) {
    var attributes = <String, Object?>{};

    if (tracingHeaderTypes.isNotEmpty) {
      attributes = generateMotadataAttributes(
          context, motadataSdk.rum?.traceSampleRate ?? 0);

      for (final headerType in tracingHeaderTypes) {
        injectTracingHeaders(context, headerType, request.headers,
            contextInjection: contextInjection);
      }
    }

    return attributes;
  }
}
