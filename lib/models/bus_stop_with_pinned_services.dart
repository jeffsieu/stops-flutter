import 'bus_service.dart';
import 'bus_stop.dart';

class BusStopWithPinnedServices extends BusStop {
  BusStopWithPinnedServices._({
    required String displayName,
    required String defaultName,
    required String code,
    required String road,
    required double latitude,
    required double longitude,
    required this.pinnedServices,
  }) : super(
          displayName: displayName,
          defaultName: defaultName,
          code: code,
          road: road,
          latitude: latitude,
          longitude: longitude,
        );

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
  bool operator ==(dynamic other) {
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
