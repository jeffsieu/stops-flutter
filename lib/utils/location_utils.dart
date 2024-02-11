import 'package:flutter/services.dart';
import 'package:location/location.dart';

final Location location = Location();
LocationData? _currentLocation;
DateTime? _currentLocationTimestamp;
bool? hasPermission;

// TODO: Refactor using Riverpod
class LocationUtils {
  static DateTime? get currentLocationTimestamp {
    return _currentLocationTimestamp;
  }

  static LocationData? getLatestLocation() {
    return _currentLocation;
  }

  static bool isLocationCurrent() {
    if (!(hasPermission ?? true)) return true;
    if (_currentLocationTimestamp == null) return false;
    return DateTime.now().difference(_currentLocationTimestamp!) <
        const Duration(minutes: 1);
  }

  static bool isLocationAllowed() {
    if (hasPermission == null) {
      checkLocationPermission();
      return true;
    }
    return hasPermission!;
  }

  static Future<void> checkLocationPermission() async {
    hasPermission =
        (await location.hasPermission()) == PermissionStatus.granted;
  }

  static void invalidateLocation() {
    _currentLocationTimestamp = null;
  }

  static Future<LocationData?> getLocation() async {
    var serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        // User denied the request
        _currentLocation = null;
        return _currentLocation;
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
      _currentLocation = null;
      return _currentLocation;
    }

    if (isLocationCurrent()) return _currentLocation;
    try {
      _currentLocation = await location.getLocation();
      _currentLocationTimestamp = DateTime.now();
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED' ||
          e.code == 'PERMISSION_DENIED_NEVER_ASK') {
        hasPermission = false;
      }
      _currentLocation = null;
    }
    return _currentLocation;
  }
}
