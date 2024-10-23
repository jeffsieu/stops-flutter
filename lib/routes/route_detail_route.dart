import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/pages/fade_page.dart';
import 'package:stops_sg/pages/route_page.dart';

class RouteDetailRoute extends GoRouteData {
  const RouteDetailRoute({required this.routeId});

  final int routeId;

  @override
  Page<void> buildPage(
    BuildContext context,
    GoRouterState state,
  ) {
    return FadePage(
      child: RoutePage(routeId: routeId),
    );
  }
}
