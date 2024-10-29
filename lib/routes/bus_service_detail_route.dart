import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/pages/bus_service_page.dart';

class BusServiceDetailRoute extends GoRouteData {
  const BusServiceDetailRoute({required this.serviceNumber});

  final String serviceNumber;

  @override
  Widget build(
    BuildContext context,
    GoRouterState state,
  ) {
    return BusServicePage(serviceNumber);
  }
}
