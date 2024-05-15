import 'bus_service.dart';
import 'bus_stop.dart';
import 'bus_stop_with_distance.dart';

class BusServiceRoute {
  BusServiceRoute({
    required this.service,
    required this.direction,
    required this.busStops,
  });

  List<BusStopWithDistance> busStops;
  BusService service;
  int direction;

  BusStop get origin => busStops.first.busStop;
  BusStop get destination => busStops.last.busStop;
  String get number => service.number;

  @override
  bool operator ==(dynamic other) {
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
