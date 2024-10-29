import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:location/location.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';

extension BusStopDistance on BusStop {
  double getMetersFromLocation(LatLng coordinates) {
    return const latlong.Distance().as(
        latlong.LengthUnit.Meter,
        latlong.LatLng(latitude, longitude),
        latlong.LatLng(coordinates.latitude, coordinates.longitude));
  }

  double getMetersFromBusStop(BusStop busStop) {
    return const latlong.Distance().as(
        latlong.LengthUnit.Meter,
        latlong.LatLng(latitude, longitude),
        latlong.LatLng(busStop.latitude, busStop.longitude));
  }
}

extension LocationDataToLatLng on LocationData {
  LatLng? toLatLng() {
    if (latitude == null || longitude == null) {
      return null;
    }

    return LatLng(latitude!, longitude!);
  }
}
