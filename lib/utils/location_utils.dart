import 'package:location/location.dart';
import 'package:flutter/services.dart';

LocationData _currentLocation;
DateTime _currentLocationTimestamp;

class LocationUtils {
  static LocationData getLatestLocation() {
    return _currentLocation;
  }

  static bool isLocationCurrent() {
    if (_currentLocationTimestamp == null)
      return false;
    return DateTime.now().difference(_currentLocationTimestamp) < const Duration(minutes: 1);
  }

  static Future<LocationData> getLocation() async {
    final Location location = Location();

    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      _currentLocation = await location.getLocation();
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        // TODO(jeffsieu): Add prompt requesting user to give permissions.
      }
      return null;
    }

    _currentLocationTimestamp = DateTime.now();
    return _currentLocation;
  }
}