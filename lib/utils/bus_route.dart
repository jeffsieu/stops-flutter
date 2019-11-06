import 'package:meta/meta.dart';

import 'bus_api.dart';
import 'bus_service.dart';
import 'bus_stop.dart';

class BusServiceRoute {
  BusServiceRoute({
    @required this.direction,
    this.busStops,
  }) {
    busStops = <BusStop>[];
    distances = <double>[];
  }

  List<BusStop> busStops;
  List<double> distances;
  BusService service;
  int direction;

  BusStop get origin => busStops.first;
  BusStop get destination => busStops.last;
  String get number => service.number;

  static BusServiceRoute fromJson(dynamic json) {
    return BusServiceRoute(
      direction: json[BusAPI.kBusServiceDirectionKey],
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
    return number.hashCode ^ direction.hashCode;
  }
}