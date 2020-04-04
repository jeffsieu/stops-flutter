import 'package:meta/meta.dart';

import 'bus_api.dart';
import 'bus_service.dart';

class BusServiceArrivalResult {
  BusServiceArrivalResult._({
    @required this.busService,
    @required this.buses,
  });

  static BusServiceArrivalResult fromJson(dynamic json) {
    final BusService busService = BusService.fromJson(json);
    final List<Bus> buses = <Bus>[
      Bus.fromJson(json['NextBus']),
      Bus.fromJson(json['NextBus2']),
      Bus.fromJson(json['NextBus3'])
    ];
    buses.removeWhere((Bus b) => b == null);
    return BusServiceArrivalResult._(
        busService: busService,
        buses: buses,
    );
  }

  final BusService busService;
  final List<Bus> buses;
}

class Bus {
  Bus._({
    @required this.type,
    @required this.load,
    @required this.latitude,
    @required this.longitude,
    @required this.arrivalTime,
  });

  static Bus fromJson(dynamic json) {
    final String typeString = json[BusAPI.kBusServiceTypeKey];
    BusType type;
    if (typeString == BusAPI.kBusServiceTypeSingle)
      type = BusType.single;
    else if (typeString == BusAPI.kBusServiceTypeDouble)
      type = BusType.double;
    else if (typeString == BusAPI.kBusServiceTypeBendy)
      type = BusType.bendy;

    final String loadString = json[BusAPI.kBusServiceLoadKey];
    BusLoad load;
    if (loadString == BusAPI.kBusServiceLoadLow)
      load = BusLoad.low;
    else if (loadString == BusAPI.kBusServiceLoadMedium)
      load = BusLoad.medium;
    else if (loadString == BusAPI.kBusServiceLoadHigh)
      load = BusLoad.high;

    final double latitude = double.tryParse(json[BusAPI.kBusServiceLatitudeKey]) ?? 0;
    final double longitude = double.tryParse(json[BusAPI.kBusServiceLongitudeKey]) ?? 0;
    final DateTime arrivalTime = DateTime.tryParse(json[BusAPI.kBusServiceArrivalTimeKey]);

    if (arrivalTime == null)
      return null;
    return Bus._(
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