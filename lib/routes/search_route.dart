import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/pages/fade_page.dart';
import 'package:stops_sg/pages/search_page/search_page.dart';

class SearchRoute extends GoRouteData {
  @override
  Page<void> buildPage(
    BuildContext context,
    GoRouterState state,
  ) {
    return FadePage(
      child: SearchPage(),
    );
  }
}