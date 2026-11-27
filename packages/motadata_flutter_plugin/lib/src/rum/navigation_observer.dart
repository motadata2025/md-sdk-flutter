// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../motadata_flutter_plugin.dart';
import '../../motadata_internal.dart';

/// Information about a View that will be passed to [MotadataRum.startView]
class RumViewInfo {
  /// The name of the view, reported as `view.name` in the RUM explorer.
  final String name;

  /// An optional path or URL for the view, reported as `view.url`. When this
  /// contains a query string (for example `/products?category=shoes`), Motadata
  /// derives the standard `@view.url_query.*` facets from it server-side. When
  /// `null`, [name] is used as the view key.
  final String? path;

  /// Any attributes to be associated with this view
  final Map<String, Object?> attributes;

  RumViewInfo({
    required this.name,
    this.path,
    this.attributes = const {},
  });

  /// The key that identifies this view to RUM, reported as `view.url`. Prefers
  /// [path] (which may include a query string, so the backend can derive
  /// `@view.url_query.*`) and falls back to [name].
  String get viewKey => path ?? name;

  /// The display name passed to [MotadataRum.startView]. Returns `null` when no
  /// distinct [path] is provided, so the view key is used as the name.
  String? get viewName => path != null ? name : null;
}

/// A function that can be used to supply custom information to
/// [MotadataRum.startView].
///
/// Returning `null` from this function will prevent the call
/// to [MotadataRum.startView].
///
/// See [MotadataNavigationObserver.viewInfoExtractor].
typedef ViewInfoExtractor = RumViewInfo? Function(Route<dynamic> route);

/// The function that provides the default route naming behavior for
/// [MotadataNavigationObserver]. If the supplied route contains a name, it
/// returns a [RumViewInfo] built from that name via [rumViewInfoFromRouteName].
/// Otherwise it returns `null`.
RumViewInfo? defaultViewInfoExtractor(Route<dynamic> route) {
  final name = route.settings.name;
  if (name == null) {
    return null;
  }

  return rumViewInfoFromRouteName(name);
}

/// Builds a [RumViewInfo] from a raw route name, parsing any URL query string
/// it contains.
///
/// When [routeName] includes a query string (for example
/// `/products?category=shoes&id=123`) the `view.url` will carry the full path +
/// query string, which Motadata will add to its standard `@view.url_query.*` facets.
///
/// Routes without a query string use the name as-is and add no extra attributes.
RumViewInfo rumViewInfoFromRouteName(String routeName) {
  if (!routeName.contains('?')) {
    return RumViewInfo(name: routeName);
  }

  final Uri uri;
  try {
    uri = Uri.parse(routeName);
  } on FormatException {
    return RumViewInfo(name: routeName);
  }

  if (uri.queryParameters.isEmpty) {
    return RumViewInfo(name: routeName);
  }

  // The path without the query string, used as the human-readable view name.
  final viewName = uri.path.isNotEmpty ? uri.path : routeName.split('?').first;

  return RumViewInfo(
    name: viewName.isNotEmpty ? viewName : routeName,
    path: routeName,
  );
}

/// This class can be added to a MaterialApp to automatically start and stop RUM
/// views, provided you are using named routes with methods like
/// [Navigator.pushNamed], or supplying route names through [RouteSettings] when
/// using [Navigator.push].
///
/// Alternately, the [MotadataNavigationObserver] can also be used in conjunction
/// with [MotadataNavigationObserverProvider] and [MotadataRouteAwareMixin] to
/// automatically start and stop RUM views on widgets that use the mixin.
///
/// If you want more control over the names and attributes that are sent to RUM,
/// you can supply a [ViewInfoExtractor] function to [viewInfoExtractor]. This
/// function is called with the current Route, and can be used to supply a
/// different name, path, or extra attributes to any route.
class MotadataNavigationObserver extends RouteObserver<ModalRoute<dynamic>>
    with WidgetsBindingObserver {
  /// A callback to supply view information to the observer. See [ViewInfoExtractor].
  final ViewInfoExtractor viewInfoExtractor;
  final MotadataSdk motadataSdk;

  RumViewInfo? _currentView;
  RumViewInfo? _pendingView;

  MotadataNavigationObserver({
    required this.motadataSdk,
    this.viewInfoExtractor = defaultViewInfoExtractor,
  }) {
    ambiguate(WidgetsBinding.instance)?.addObserver(this);
    motadataSdk.updateConfigurationInfo(
        LateConfigurationProperty.trackViewsManually, false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        final pendingView = _pendingView;
        _pendingView = null;
        _startView(pendingView);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      default:
        if (_currentView != null) {
          _pendingView = _currentView;
          _stopView(_currentView);
        }
        break;
    }
  }

  void _startView(RumViewInfo? viewInfo) {
    // For platforms that don't support app lifecycle state (lifecycleState is null)
    // assume that the application is foregrounded.
    final lifecycleState = ambiguate(WidgetsBinding.instance)?.lifecycleState ??
        AppLifecycleState.resumed;
    if (lifecycleState != AppLifecycleState.resumed) {
      _pendingView = viewInfo;
    } else {
      _currentView = viewInfo;
      if (viewInfo != null) {
        if (kIsWeb) {
          // On web, Flutter is informing us of the change in Route before the
          // browser has had a chance to update the `location`. Wait a frame so
          // the Browser SDK can properly capture the location. Because of this wait,
          // we don't track "First Build Complete" on web, as it would be skewed
          // by this wait.
          Future.delayed(const Duration(milliseconds: 1)).then((_) {
            // Make sure the view wasn't overwritten in the last ~1ms
            if (_currentView == viewInfo) {
              motadataSdk.rum
                  ?.startView(viewInfo.name, null, viewInfo.attributes);
            }
          });
        } else {
          motadataSdk.rum?.startView(
              viewInfo.viewKey, viewInfo.viewName, viewInfo.attributes);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            motadataSdk.rum?.markViewFirstBuildComplete(viewInfo.viewKey);
          });
        }
      } else {
        _pendingView = viewInfo;
      }
    }
  }

  void _stopView(RumViewInfo? viewInfo) {
    if (viewInfo != null) {
      motadataSdk.rum?.stopView(viewInfo.viewKey);
    }
    _currentView = null;
  }

  void _sendScreenView(Route<dynamic>? newRoute, Route<dynamic>? oldRoute) {
    final oldViewInfo = oldRoute != null ? viewInfoExtractor(oldRoute) : null;
    final newViewInfo = newRoute != null ? viewInfoExtractor(newRoute) : null;

    _stopView(oldViewInfo);
    _startView(newViewInfo);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _sendScreenView(route, previousRoute);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _sendScreenView(newRoute, oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    // On pop, the "previous" route is now the new route.
    _sendScreenView(previousRoute, route);
  }
}

/// The MotadataRouteAwareMixin can be used to supply names and additional
/// attributes to RUM views as an alternative to supplying a [ViewInfoExtractor]
/// to [MotadataNavigationObserver], supplying a name when creating the route, or
/// using named routes.
///
/// Usage:
///
/// ```
/// class ViewWidget extends StatefulWidget {
///   const ViewWidget({Key? key}) : super(key: key);
///
///   @override
///   _ViewWidgetState createState() => _ViewWidgetState();
/// }
///
/// class _ViewWidgetState extends State<ViewWidget>
///     with RouteAware, MotadataRouteAwareMixin {
///   // ...
/// }
/// ```
///
/// By default, MotadataRouteAwareMixin will use the name of its parent Widget as
/// the name of the route, **but only when the code is not obfuscated**.
///
/// If you are obfuscating your final code, or if you want to provide a
/// different name or additional view attributes, you should override the
/// [rumViewInfo] getter.
///
/// [MotadataNavigationObserver] uses the [didChangeDependencies] lifecycle
/// method to start the RUM view. For this reason, you should avoid calling RUM
/// methods during [initState], and override [didPush] from [RouteAware] to do
/// any initial setup instead.
///
/// Note: this should not be used with named routes. By design, the Mixin checks
/// if a name was already assigned to its route and will not send any tracking
/// events in that case
mixin MotadataRouteAwareMixin<T extends StatefulWidget> on State<T>, RouteAware {
  MotadataNavigationObserver? _routeObserver;

  /// Override this method to supply extra view info for this view through the
  /// [RumViewInfo] class. By default, it returns the name of the parent Widget
  /// as the name of the view.
  RumViewInfo get rumViewInfo {
    return RumViewInfo(name: (T).toString());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _routeObserver = MotadataNavigationObserverProvider.of(context)?.navObserver;
    if (_routeObserver != null) {
      final route = ModalRoute.of(context);
      if (route != null) {
        if (route.settings.name == null) {
          _routeObserver?.subscribe(this, route);
        } else {
          MotadataSdk.instance.internalLogger.debug(
              '$MotadataRouteAwareMixin for ${rumViewInfo.name} (on widget $T) '
              'will be ignored because it is part of a named route ${route.settings.name}');
        }
      }
    } else {
      MotadataSdk.instance.internalLogger.warn(
          'Invalid use of $MotadataRouteAwareMixin without a $MotadataNavigationObserverProvider. '
          'Make sure to add the provider at the root of your widget tree (above your MaterialApp)');
    }
  }

  @override
  void dispose() {
    _routeObserver?.unsubscribe(this);
    super.dispose();
  }

  @override
  @mustCallSuper
  void didPush() {
    _startView();
    super.didPush();
  }

  @override
  @mustCallSuper
  void didPop() {
    super.didPop();
    _stopView();
  }

  @override
  @mustCallSuper
  void didPushNext() {
    super.didPushNext();
    _stopView();
  }

  @override
  @mustCallSuper
  void didPopNext() {
    _startView();
    super.didPopNext();
  }

  void _startView() {
    if (_routeObserver != null) {
      final info = rumViewInfo;
      final rum = _routeObserver?.motadataSdk.rum;
      if (rum != null) {
        rum.startView(info.viewKey, info.viewName, info.attributes);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          rum.markViewFirstBuildComplete(info.viewKey);
        });
      }
    }
  }

  void _stopView() {
    if (_routeObserver != null) {
      final info = rumViewInfo;
      _routeObserver?.motadataSdk.rum?.stopView(info.viewKey);
    }
  }
}

/// Provides the [MotadataNavigationObserver] to other classes that need it.
/// Specifically, if you want to use the [MotadataRouteAwareMixin], you must use
/// this provider.
///
/// The provider should be placed in the widget tree above your MaterialApp or
/// application router.
/// ```
/// void main() {
///   // Other setup code
///   final observer = MotadataNavigationObserver(motadataSdk: MotadataSdk.instance);
///   runApp(MotadataNavigationObserverProvider(
///     navObserver: observer,
///     child: MaterialApp(
///       navigatorObservers: [observer],
///       // other initialization
///     ),
///   );
/// }
/// ```
///
/// See also [MotadataRouteAwareMixin]
class MotadataNavigationObserverProvider extends InheritedWidget {
  final MotadataNavigationObserver navObserver;

  const MotadataNavigationObserverProvider({
    super.key,
    required this.navObserver,
    required super.child,
  });

  @override
  bool updateShouldNotify(
          covariant MotadataNavigationObserverProvider oldWidget) =>
      navObserver != oldWidget.navObserver;

  static MotadataNavigationObserverProvider? of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<
        MotadataNavigationObserverProvider>();
    return result;
  }
}
