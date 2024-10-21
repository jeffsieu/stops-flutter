import 'package:latlong2/latlong.dart' as latlong;

double metersBetween(
    double latitude1, double longitude1, double latitude2, double longitude2) {
  return const latlong.Distance().as(
      latlong.LengthUnit.Meter,
      latlong.LatLng(latitude1, longitude1),
      latlong.LatLng(latitude2, longitude2));
}

String formatDistance(double distanceMeters) {
  if (distanceMeters < 1000) {
    return '${distanceMeters.toStringAsFixed(0)}m';
  } else {
    return '${(distanceMeters / 1000).toStringAsFixed(1)}km';
  }
}
