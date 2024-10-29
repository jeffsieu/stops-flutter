import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/pages/home_page_scaffold.dart';
import 'package:stops_sg/routes/add_route_route.dart';
import 'package:stops_sg/routes/bus_service_detail_route.dart';
import 'package:stops_sg/routes/bus_service_detail_with_focused_bus_stop_route.dart';
import 'package:stops_sg/routes/bus_stop_search_route.dart';
import 'package:stops_sg/routes/edit_route_route.dart';
import 'package:stops_sg/routes/initial_fetch_data_route.dart';
import 'package:stops_sg/routes/refetch_data_route.dart';
import 'package:stops_sg/routes/route_detail_route.dart';
import 'package:stops_sg/routes/routes_route.dart';
import 'package:stops_sg/routes/saved_route.dart';
import 'package:stops_sg/routes/scan_card_route.dart';
import 'package:stops_sg/routes/search_route.dart';
import 'package:stops_sg/routes/settings_route.dart';

part 'routes.g.dart';

@TypedShellRoute<AppShellRoute>(routes: [
  TypedShellRoute<HomeShellRoute>(
    routes: [
      TypedGoRoute<SavedRoute>(path: '/saved'),
      TypedGoRoute<SearchRoute>(path: '/search'),
      TypedGoRoute<RoutesRoute>(path: '/routes'),
      TypedGoRoute<SettingsRoute>(path: '/settings'),
    ],
  ),
  TypedGoRoute<BusStopSearchRoute>(path: '/search/busStops'),
  TypedGoRoute<AddRouteRoute>(path: '/routes/add'),
  TypedGoRoute<RouteDetailRoute>(path: '/routes/:routeId'),
  TypedGoRoute<EditRouteRoute>(path: '/routes/:routeId/edit'),
  TypedGoRoute<BusServiceDetailRoute>(path: '/bus-services/:serviceNumber'),
  TypedGoRoute<BusServiceDetailWithFocusedBusStopRoute>(
      path: '/bus-services/:serviceNumber/busStop/:busStopCode'),
  TypedGoRoute<ScanCardRoute>(path: '/scan-card'),
  TypedGoRoute<InitialFetchDataRoute>(path: '/init-data'),
  TypedGoRoute<RefetchDataRoute>(path: '/refetch-data'),
])
class AppShellRoute extends ShellRouteData {
  const AppShellRoute();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    Widget navigator,
  ) {
    return navigator;
  }
}

class HomeShellRoute extends ShellRouteData {
  const HomeShellRoute();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    Widget navigator,
  ) {
    return HomePageScaffold(child: navigator);
  }
}
