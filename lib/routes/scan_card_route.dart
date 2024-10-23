import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/pages/scan_card_page.dart';

class ScanCardRoute extends GoRouteData {
  @override
  Widget build(
    BuildContext context,
    GoRouterState state,
  ) {
    return const ScanCardPage();
  }
}
