import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stops_sg/bus_api/bus_api.dart';

part 'location.g.dart';

const kLocationValidDuration = Duration(minutes: 1);
final Location location = Location();

class UserLocationSnapshot {
  const UserLocationSnapshot.noPermission({required this.timestamp})
      : data = null,
        hasPermission = false;
  const UserLocationSnapshot.noService({required this.timestamp})
      : data = null,
        hasPermission = true;
  const UserLocationSnapshot.location(
      {required this.data, required this.timestamp})
      : hasPermission = true;

  final LocationData? data;
  final DateTime timestamp;
  final bool hasPermission;

  bool get isCurrent {
    return DateTime.now().difference(timestamp) < const Duration(minutes: 1);
  }
}

@riverpod
class UserLocation extends _$UserLocation {
  @override
  Future<UserLocationSnapshot> build() async {
    final value = await _getValue();

    ref.cacheFor(kLocationValidDuration);

    if (value.data != null) {
      ref.refreshIn(kLocationValidDuration);
    }

    return value;
  }

  Future<UserLocationSnapshot> _getValue() async {
    var serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        // User denied the request
        return UserLocationSnapshot.noService(timestamp: DateTime.now());
      }
    }

    // Location service is enabled, check for permission
    var permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
    }

    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.grantedLimited) {
      // User denied the request
      return UserLocationSnapshot.noPermission(timestamp: DateTime.now());
    }

    try {
      final locationData = await location.getLocation();
      return UserLocationSnapshot.location(
          data: locationData, timestamp: DateTime.now());
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED' ||
          e.code == 'PERMISSION_DENIED_NEVER_ASK') {
        return UserLocationSnapshot.noPermission(timestamp: DateTime.now());
      }
    }
    return UserLocationSnapshot.noService(timestamp: DateTime.now());
  }
}
