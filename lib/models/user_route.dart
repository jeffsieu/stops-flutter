import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/database_utils.dart';
import 'bus_stop_with_pinned_services.dart';

class StoredUserRoute extends UserRoute {
  const StoredUserRoute({
    required this.id,
    required String name,
    required Color color,
    required List<BusStopWithPinnedServices> busStops,
  }) : super(name: name, color: color, busStops: busStops);

  static const StoredUserRoute home = StoredUserRoute(
      id: defaultRouteId,
      name: defaultRouteName,
      color: Colors.transparent,
      busStops: []);

  final int id;

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final StoredUserRoute otherRoute = other as StoredUserRoute;
    return id == otherRoute.id &&
        color == otherRoute.color &&
        listEquals(busStops, otherRoute.busStops);
  }

  @override
  int get hashCode {
    return id.hashCode;
  }
}

class UserRoute {
  const UserRoute({
    required this.name,
    required this.color,
    required this.busStops,
  });

  final String name;
  final Color color;
  final List<BusStopWithPinnedServices> busStops;

  StoredUserRoute storeWithId(int id) {
    return StoredUserRoute(
      id: id,
      name: name,
      color: color,
      busStops: busStops,
    );
  }

  // void update(UserRoute from) {
  //   name = from.name;
  //   color = from.color;
  //   busStops = List<BusStopWithPinnedServices>.from(from.busStops);
  // }

  // @override
  // bool operator ==(dynamic other) {
  //   if (other.runtimeType != runtimeType) return false;
  //   final UserRoute otherRoute = other as UserRoute;
  //   return id == otherRoute.id &&
  //       color == otherRoute.color &&
  //       listEquals(busStops, otherRoute.busStops);
  // }

  // @override
  // int get hashCode {
  //   return id.hashCode;
  // }

  @override
  String toString() {
    return '$name (color: $color) (bus stops: $busStops)';
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
