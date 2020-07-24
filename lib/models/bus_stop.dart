import 'package:meta/meta.dart';

import '../utils/bus_api.dart';
import 'bus_service.dart';

class BusStop {
  BusStop({
    @required this.displayName,
    @required this.defaultName,
    @required this.code,
    @required this.road,
    @required this.latitude,
    @required this.longitude,
  });

  String displayName;
  String defaultName;
  String code;
  String road;
  double latitude;
  double longitude;
  List<BusService> pinnedServices;

  static BusStop fromJson(dynamic json) {
    return BusStop(
      displayName: json[BusAPI.kBusStopNameKey],
      defaultName: json[BusAPI.kBusStopNameKey],
      code: json[BusAPI.kBusStopCodeKey],
      road: json[BusAPI.kBusStopRoadKey],
      latitude: json[BusAPI.kBusStopLatitudeKey],
      longitude: json[BusAPI.kBusStopLongitudeKey]);
  }

  static BusStop fromMap(Map<String, dynamic> map) {
    return BusStop(
      displayName: map['displayName'],
      defaultName: map['defaultName'],
      code: map['code'],
      road: map['road'],
      latitude: map['latitude'],
      longitude: map['longitude'],
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'displayName': displayName,
      'defaultName': defaultName,
      'code': code,
      'road': road,
      'latitude': latitude,
      'longitude': longitude
    };
  }

  static BusStop withCode(String code) {
    return BusStop(
      displayName: '',
      defaultName: '',
      code: code,
      road: '',
      latitude: -1,
      longitude: -1);
  }

  @override
  String toString() {
    return '$displayName/$code ($latitude, $longitude)';
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType)
      return false;
    final BusStop otherBusStop = other;
    return code == otherBusStop.code;
  }

  @override
  int get hashCode {
    return code.hashCode;
  }
}
