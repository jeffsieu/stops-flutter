import 'package:latlong2/latlong.dart' as latlong;
import 'package:stops_sg/utils/bus_utils.dart';

double metersBetween(
    double latitude1, double longitude1, double latitude2, double longitude2) {
  return const latlong.Distance().as(
      latlong.LengthUnit.Meter,
      latlong.LatLng(latitude1, longitude1),
      latlong.LatLng(latitude2, longitude2));
}

String formatDistance(double distanceMeters) {
  return getDistanceVerboseFromMeters(distanceMeters);
}
