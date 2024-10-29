import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/pages/fetch_data_page.dart';

class InitialFetchDataRoute extends GoRouteData {
  @override
  Widget build(
    BuildContext context,
    GoRouterState state,
  ) {
    return const FetchDataPage(isSetup: true);
  }
}
