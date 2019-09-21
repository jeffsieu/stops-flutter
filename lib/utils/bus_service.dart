import 'package:meta/meta.dart';

import 'bus_api.dart';
import 'bus_stop.dart';

class BusService {
  BusService({
    @required this.routes
  }) : assert(routes != null),
      assert(routes.isNotEmpty),
      assert(routes.length <= 2),
      assert(routes.every((BusServiceRoute route) => route.number == routes[0].number));

  final List<BusServiceRoute> routes;

  String get number => routes[0].number;
  int get directionCount => routes.length;
  List<BusStop> get origin => routes.map<BusStop>((BusServiceRoute route) => route.origin).toList();
  List<BusStop> get destination => routes.map<BusStop>((BusServiceRoute route) => route.destination).toList();
}

class BusServiceRoute {
  BusServiceRoute({
    @required this.direction,
    @required this.number,
    @required this.operator,
    @required this.origin,
    @required this.destination,
    this.busStops,
  });

  List<BusStop> busStops;
  List<double> distances;
  BusStop origin;
  BusStop destination;
  int direction;
  String number;
  String operator;

  static BusServiceRoute fromJson(dynamic json) {
      return BusServiceRoute(
        direction: json[BusAPI.kBusServiceDirectionKey],
        number: json[BusAPI.kBusServiceNumberKey],
        operator: json[BusAPI.kBusServiceOperatorKey],
        origin: BusStop.withCode(json[BusAPI.kBusServiceOriginKey]),
        destination: BusStop.withCode(json[BusAPI.kBusServiceDestinationKey]),
      );
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType)
      return false;
    final BusServiceRoute otherBusServiceRoute = other;
    return otherBusServiceRoute.number == number && otherBusServiceRoute.direction == direction;
  }

  @override
  int get hashCode {
    return number.hashCode^direction.hashCode;
  }


}