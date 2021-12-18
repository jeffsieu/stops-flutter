import 'bus_service.dart';
import 'bus_service_route.dart';
import 'bus_stop.dart';

class BusServiceWithRoutes extends BusService {
  final List<BusServiceRoute> routes;

  BusServiceWithRoutes._({
    required String number,
    required String operator,
    required this.routes,
  }) : super(number: number, operator: operator);

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
