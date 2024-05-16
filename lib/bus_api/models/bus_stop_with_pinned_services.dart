import 'package:stops_sg/bus_api/models/bus_service.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';

class BusStopWithPinnedServices extends BusStop {
  BusStopWithPinnedServices._({
    required super.displayName,
    required super.defaultName,
    required super.code,
    required super.road,
    required super.latitude,
    required super.longitude,
    required this.pinnedServices,
  });

  List<BusService> pinnedServices;

  static BusStopWithPinnedServices fromBusStop(
      BusStop busStop, List<BusService> pinnedServices) {
    return BusStopWithPinnedServices._(
      displayName: busStop.displayName,
      defaultName: busStop.defaultName,
      code: busStop.code,
      road: busStop.road,
      latitude: busStop.latitude,
      longitude: busStop.longitude,
      pinnedServices: pinnedServices,
    );
  }

  @override
  String toString() {
    return '$displayName/$code ($latitude, $longitude) $pinnedServices';
  }

  @override
  bool operator ==(Object other) {
    // If other is instance of BusStop
    if (other is BusStopWithPinnedServices) {
      return other.code == code && pinnedServices == other.pinnedServices;
    } else if (other is BusStop) {
      return other.code == code;
    } else {
      return false;
    }
  }

  @override
  int get hashCode {
    return code.hashCode;
  }
}
