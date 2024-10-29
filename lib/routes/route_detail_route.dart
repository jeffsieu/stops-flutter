import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/pages/route_page.dart';

class RouteDetailRoute extends GoRouteData {
  const RouteDetailRoute({required this.routeId});

  final int routeId;

  @override
  Widget build(
    BuildContext context,
    GoRouterState state,
  ) {
    return RoutePage(routeId: routeId);
  }
}
