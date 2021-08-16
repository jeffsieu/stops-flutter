// @dart=2.9

import 'package:meta/meta.dart';

import '../models/bus_service.dart';
import 'bus_api.dart';

class BusServiceArrivalResult {
  BusServiceArrivalResult._({
    @required this.busService,
    @required this.buses,
  });

  static BusServiceArrivalResult fromJson(dynamic json) {
    final BusService busService = BusService.fromJson(json);
    final List<BusArrival> buses = <BusArrival>[
      BusArrival.fromJson(json['NextBus']),
      BusArrival.fromJson(json['NextBus2']),
      BusArrival.fromJson(json['NextBus3'])
    ];
    buses.removeWhere((BusArrival b) => b == null);
    return BusServiceArrivalResult._(
      busService: busService,
      buses: buses,
    );
  }

  final BusService busService;
  final List<BusArrival> buses;
}

class BusArrival {
  BusArrival._({
    @required this.type,
    @required this.load,
    @required this.latitude,
    @required this.longitude,
    @required this.arrivalTime,
  });

  static BusArrival fromJson(dynamic json) {
    final String typeString = json[BusAPI.kBusServiceTypeKey] as String;
    BusType type;
    if (typeString == BusAPI.kBusServiceTypeSingle) {
      type = BusType.single;
    } else if (typeString == BusAPI.kBusServiceTypeDouble) {
      type = BusType.double;
    } else if (typeString == BusAPI.kBusServiceTypeBendy) type = BusType.bendy;

    final String loadString = json[BusAPI.kBusServiceLoadKey] as String;
    BusLoad load;
    if (loadString == BusAPI.kBusServiceLoadLow) {
      load = BusLoad.low;
    } else if (loadString == BusAPI.kBusServiceLoadMedium) {
      load = BusLoad.medium;
    } else if (loadString == BusAPI.kBusServiceLoadHigh) load = BusLoad.high;

    final double latitude =
        double.tryParse(json[BusAPI.kBusServiceLatitudeKey] as String) ?? 0;
    final double longitude =
        double.tryParse(json[BusAPI.kBusServiceLongitudeKey] as String) ?? 0;
    final DateTime arrivalTime =
        DateTime.tryParse(json[BusAPI.kBusServiceArrivalTimeKey] as String);

    if (arrivalTime == null) return null;
    return BusArrival._(
      type: type,
      load: load,
      latitude: latitude,
      longitude: longitude,
      arrivalTime: arrivalTime,
    );
  }

  final BusType type;
  final BusLoad load;
  final double latitude;
  final double longitude;
  final DateTime arrivalTime;
}

enum BusType { single, double, bendy }
enum BusLoad { low, medium, high }
