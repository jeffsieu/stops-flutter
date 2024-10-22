import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/pages/home_page_scaffold.dart';
import 'package:stops_sg/routes/add_route_route.dart';
import 'package:stops_sg/routes/bus_stop_search_route.dart';
import 'package:stops_sg/routes/edit_route_route.dart';
import 'package:stops_sg/routes/route_detail_route.dart';
import 'package:stops_sg/routes/routes_route.dart';
import 'package:stops_sg/routes/saved_route.dart';
import 'package:stops_sg/routes/search_route.dart';
import 'package:stops_sg/routes/settings_route.dart';

part 'routes.g.dart';

final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

@TypedShellRoute<HomeShellRoute>(routes: [
  TypedGoRoute<SavedRoute>(path: '/saved'),
  TypedGoRoute<SearchRoute>(path: '/search'),
  TypedGoRoute<BusStopSearchRoute>(path: '/search/busStops'),
  TypedGoRoute<RoutesRoute>(path: '/routes'),
  TypedGoRoute<RouteDetailRoute>(path: '/routes/:routeId'),
  TypedGoRoute<EditRouteRoute>(path: '/routes/:routeId/edit'),
  TypedGoRoute<AddRouteRoute>(path: '/routes/add'),
  TypedGoRoute<SettingsRoute>(path: '/settings'),
])
class HomeShellRoute extends ShellRouteData {
  const HomeShellRoute();

  static final GlobalKey<NavigatorState> $navigatorKey = shellNavigatorKey;

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    Widget navigator,
  ) {
    return HomePageScaffold(child: navigator);
  }
}
