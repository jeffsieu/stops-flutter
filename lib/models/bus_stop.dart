import '../utils/bus_api.dart';

class BusStop {
  const BusStop({
    required this.displayName,
    required this.defaultName,
    required this.code,
    required this.road,
    required this.latitude,
    required this.longitude,
  });

  const BusStop.withCode(this.code)
      : displayName = '',
        defaultName = '',
        road = '',
        latitude = -1,
        longitude = -1;

  final String displayName;
  final String defaultName;
  final String code;
  final String road;
  final double latitude;
  final double longitude;

  static BusStop fromJson(dynamic json) {
    return BusStop(
        displayName: json[BusAPI.kBusStopNameKey] as String,
        defaultName: json[BusAPI.kBusStopNameKey] as String,
        code: json[BusAPI.kBusStopCodeKey] as String,
        road: json[BusAPI.kBusStopRoadKey] as String,
        latitude: json[BusAPI.kBusStopLatitudeKey] as double,
        longitude: json[BusAPI.kBusStopLongitudeKey] as double);
  }

  static BusStop fromMap(Map<String, dynamic> map) {
    return BusStop(
      displayName: map['displayName'] as String,
      defaultName: map['defaultName'] as String,
      code: map['code'] as String,
      road: map['road'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
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

  BusStop copyWith({
    String? displayName,
    String? defaultName,
    String? code,
    String? road,
    double? latitude,
    double? longitude,
  }) {
    return BusStop(
      displayName: displayName ?? this.displayName,
      defaultName: defaultName ?? this.defaultName,
      code: code ?? this.code,
      road: road ?? this.road,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  String toString() {
    return '$displayName/$code ($latitude, $longitude)';
  }

  @override
  bool operator ==(dynamic other) {
    if (other is BusStop) {
      return other.code == code;
    }
    return false;
  }

  @override
  int get hashCode {
    return code.hashCode;
  }
}
