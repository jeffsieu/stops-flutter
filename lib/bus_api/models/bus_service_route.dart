import 'package:stops_sg/bus_api/models/bus_service.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';

class BusServiceRoute {
  BusServiceRoute({
    required this.service,
    required this.direction,
    required this.busStops,
  });

  List<({BusStop busStop, double distance})> busStops;
  BusService service;
  int direction;

  BusStop get origin => busStops.first.busStop;
  BusStop get destination => busStops.last.busStop;
  String get number => service.number;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    final otherBusServiceRoute = other as BusServiceRoute;
    return otherBusServiceRoute.number == number &&
        otherBusServiceRoute.direction == direction;
  }

  @override
  int get hashCode {
    return number.hashCode ^ direction.hashCode;
  }
}
