import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/pages/add_route_page.dart';
import 'package:stops_sg/pages/fade_page.dart';

class AddRouteRoute extends GoRouteData {
  @override
  Page<void> buildPage(
    BuildContext context,
    GoRouterState state,
  ) {
    return const FadePage(
      child: AddRoutePage(),
    );
  }
}
