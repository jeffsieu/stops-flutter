import 'package:location/location.dart';
import 'package:flutter/services.dart';

LocationData _currentLocation;

class LocationUtils {
  static LocationData getLatestLocation() {
    return _currentLocation;
  }

  static Future<LocationData> getLocation() async {
    LocationData currentLocation;

    final Location location = Location();

    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      currentLocation = await location.getLocation();
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        // TODO(jeffsieu): Add prompt requesting user to give permissions.
      }
      currentLocation = null;
    }
    _currentLocation = currentLocation;

    return currentLocation;
  }
}