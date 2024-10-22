import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/pages/fade_page.dart';
import 'package:stops_sg/pages/route_page.dart';

class RoutePageWrapper extends ConsumerWidget {
  const RoutePageWrapper({super.key, required this.routeId});

  final int routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(savedUserRouteProvider(id: routeId)).valueOrNull;

    if (route == null) {
      return const CircularProgressIndicator();
    }

    return RoutePage(route: route);
  }
}

class RouteDetailRoute extends GoRouteData {
  const RouteDetailRoute({required this.routeId});

  final int routeId;

  @override
  Page<void> buildPage(
    BuildContext context,
    GoRouterState state,
  ) {
    return FadePage(
      child: RoutePageWrapper(routeId: routeId),
    );
  }
}
