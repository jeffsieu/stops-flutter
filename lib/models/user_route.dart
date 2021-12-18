import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/database_utils.dart';
import 'bus_stop_with_pinned_services.dart';

class UserRoute {
  // UserRoute({
  //   required this.name,
  //   required this.color,
  //   required this.busStops,
  // }) : id = null;
  UserRoute.withId({
    required this.id,
    required this.name,
    required this.color,
    required this.busStops,
  });
  UserRoute._({
    required this.id,
    required this.name,
    required this.color,
  }) : busStops = <BusStopWithPinnedServices>[];
  static UserRoute home = UserRoute._(
      id: defaultRouteId, name: defaultRouteName, color: Colors.transparent);

  final int? id;
  String name;
  Color color;
  List<BusStopWithPinnedServices> busStops;

  static UserRoute fromMap(Map<String, dynamic> map) {
    return UserRoute._(
      id: map['id'] as int,
      name: map['name'] as String,
      color: Color(map['color'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'color': color.value,
    };
  }

  void update(UserRoute from) {
    name = from.name;
    color = from.color;
    busStops = List<BusStopWithPinnedServices>.from(from.busStops);
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final UserRoute otherRoute = other as UserRoute;
    return id == otherRoute.id &&
        color == otherRoute.color &&
        listEquals(busStops, otherRoute.busStops);
  }

  @override
  int get hashCode {
    return id.hashCode;
  }

  @override
  String toString() {
    return '$name (id: $id, color: $color) (bus stops: $busStops)';
  }
}

extension ContextColor on Color {
  Color of(BuildContext context) {
    return HSLColor.fromColor(this)
        .withLightness(
            Theme.of(context).brightness == Brightness.light ? 0.45 : 0.75)
        .toColor();
  }
}
