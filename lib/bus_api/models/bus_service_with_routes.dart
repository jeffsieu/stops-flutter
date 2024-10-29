import 'package:stops_sg/bus_api/models/bus_service.dart';
import 'package:stops_sg/bus_api/models/bus_service_route.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';

class BusServiceWithRoutes extends BusService {
  final List<BusServiceRoute> routes;

  BusServiceWithRoutes._({
    required super.number,
    required super.operator,
    required this.routes,
  });

  static BusServiceWithRoutes fromBusService(
      BusService busService, List<BusServiceRoute> routes) {
    return BusServiceWithRoutes._(
      number: busService.number,
      operator: busService.operator,
      routes: routes,
    );
  }

  int get directionCount => routes.length;
  List<BusStop> get origins => routes
      .map<BusStop>((BusServiceRoute route) => route.origin)
      .toList(growable: false);
  List<BusStop> get destinations => routes
      .map<BusStop>((BusServiceRoute route) => route.destination)
      .toList(growable: false);
}
