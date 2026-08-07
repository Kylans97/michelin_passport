import 'package:flutter/material.dart';

/// Shared across the app so a screen that stays permanently mounted inside
/// the bottom-tab IndexedStack (see `_MainNavigation` in app.dart) can still
/// detect "a screen pushed on top of me was just popped" via RouteAware.
/// Switching tabs alone never triggers this — IndexedStack keeps every tab
/// mounted and simply toggles which one is painted, so it's Navigator
/// push/pop, not tab selection, that this observer reacts to.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
