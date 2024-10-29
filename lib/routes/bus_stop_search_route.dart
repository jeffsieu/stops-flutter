import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/pages/search_page/search_page.dart';

class BusStopSearchRoute extends GoRouteData {
  @override
  Widget build(
    BuildContext context,
    GoRouterState state,
  ) {
    return const SearchPage.onlyBusStops();
  }
}
