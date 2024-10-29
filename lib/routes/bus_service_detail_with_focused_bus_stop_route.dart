import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/pages/bus_service_page.dart';

class BusServiceDetailWithFocusedBusStopRoute extends GoRouteData {
  const BusServiceDetailWithFocusedBusStopRoute(
      {required this.serviceNumber, required this.busStopCode});

  final String serviceNumber;
  final String busStopCode;

  @override
  Widget build(
    BuildContext context,
    GoRouterState state,
  ) {
    return BusServicePage.withBusStop(serviceNumber,
        focusedBusStopCode: busStopCode);
  }
}
