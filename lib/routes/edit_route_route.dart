import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/pages/add_route_page.dart';
import 'package:stops_sg/pages/fade_page.dart';

class EditRouteRoute extends GoRouteData {
  const EditRouteRoute({
    required this.routeId,
  });
  final int routeId;

  @override
  Page<UserRoute> buildPage(
    BuildContext context,
    GoRouterState state,
  ) {
    return FadePage(
      child: AddRoutePage.edit(
        routeId: routeId,
      ),
    );
  }
}
