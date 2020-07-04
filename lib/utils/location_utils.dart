import 'package:location/location.dart';
import 'package:flutter/services.dart';

final Location location = Location();
LocationData _currentLocation;
DateTime _currentLocationTimestamp;
bool hasPermission;

class LocationUtils {
  static LocationData getLatestLocation() {
    return _currentLocation;
  }

  static bool isLocationCurrent() {
    if (_currentLocationTimestamp == null)
      return false;
    return DateTime.now().difference(_currentLocationTimestamp) < const Duration(minutes: 1);
  }

  static bool isLocationAllowed()  {
    if (hasPermission == null) {
      checkLocationPermission();
      return true;
    }
    return hasPermission;
  }

  static Future<void> checkLocationPermission() async {
    hasPermission = (await location.hasPermission()) == PermissionStatus.GRANTED;
  }

  static Future<LocationData> getLocation() async {

    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      _currentLocation = await location.getLocation();
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED' || e.code == 'PERMISSION_DENIED_NEVER_ASK') {
      }
      return null;
    }

    _currentLocationTimestamp = DateTime.now();
    return _currentLocation;
  }
}