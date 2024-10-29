import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/pages/add_route_page.dart';

class EditRouteRoute extends GoRouteData {
  const EditRouteRoute({
    required this.routeId,
  });
  final int routeId;

  @override
  Widget build(
    BuildContext context,
    GoRouterState state,
  ) {
    return AddRoutePage.edit(
      routeId: routeId,
    );
  }
}
