import '../api/bus_api.dart';
import '../api/models/bus_service.dart';

class BusServiceArrivalResult {
  BusServiceArrivalResult._({
    required this.busService,
    required this.buses,
  });

  static BusServiceArrivalResult fromJson(dynamic json) {
    final busService = BusService.fromJson(json);
    final buses = <BusArrival?>[
      BusArrival.fromJson(json['NextBus']),
      BusArrival.fromJson(json['NextBus2']),
      BusArrival.fromJson(json['NextBus3'])
    ];
    buses.removeWhere((BusArrival? b) => b == null);
    return BusServiceArrivalResult._(
      busService: busService,
      buses: buses,
    );
  }

  final BusService busService;
  final List<BusArrival?> buses;
}

class BusArrival {
  BusArrival._({
    required this.type,
    required this.load,
    required this.latitude,
    required this.longitude,
    required this.arrivalTime,
  });

  static BusArrival? fromJson(dynamic json) {
    final typeString = json[kBusServiceTypeKey] as String?;
    BusType? type;
    if (typeString == kBusServiceTypeSingle) {
      type = BusType.single;
    } else if (typeString == kBusServiceTypeDouble) {
      type = BusType.double;
    } else if (typeString == kBusServiceTypeBendy) {
      type = BusType.bendy;
    } else if (typeString?.isEmpty ?? true) {
      type = null;
    } else {
      throw Exception('Unknown bus type: $typeString');
    }

    final loadString = json[kBusServiceLoadKey] as String?;
    BusLoad? load;
    if (loadString == kBusServiceLoadLow) {
      load = BusLoad.low;
    } else if (loadString == kBusServiceLoadMedium) {
      load = BusLoad.medium;
    } else if (loadString == kBusServiceLoadHigh) {
      load = BusLoad.high;
    } else if (loadString?.isEmpty ?? true) {
      load = null;
    } else {
      throw Exception('Unknown bus load: $loadString');
    }

    final latitude =
        double.tryParse(json[kBusServiceLatitudeKey] as String) ?? 0;
    final longitude =
        double.tryParse(json[kBusServiceLongitudeKey] as String) ?? 0;
    final arrivalTime =
        DateTime.tryParse(json[kBusServiceArrivalTimeKey] as String);

    if (arrivalTime == null) return null;
    return BusArrival._(
      type: type,
      load: load,
      latitude: latitude,
      longitude: longitude,
      arrivalTime: arrivalTime,
    );
  }

  final BusType? type;
  final BusLoad? load;
  final double latitude;
  final double longitude;
  final DateTime arrivalTime;
}

enum BusType { single, double, bendy }

enum BusLoad { low, medium, high }
