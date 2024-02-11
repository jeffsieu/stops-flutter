import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/database_utils.dart';
import 'bus_stop_with_pinned_services.dart';

class StoredUserRoute extends UserRoute {
  const StoredUserRoute({
    required this.id,
    required super.name,
    required super.color,
    required super.busStops,
  });

  // static const StoredUserRoute home = StoredUserRoute(
  //     id: defaultRouteId,
  //     name: defaultRouteName,
  //     color: Colors.transparent,
  //     busStops: []);

  final int id;

  bool get isHome => id == kDefaultRouteId;

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final otherRoute = other as StoredUserRoute;
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
