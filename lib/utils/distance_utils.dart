import 'package:latlong2/latlong.dart' as latlong;

double metersBetween(
    double latitude1, double longitude1, double latitude2, double longitude2) {
  return const latlong.Distance().as(
      latlong.LengthUnit.Meter,
      latlong.LatLng(latitude1, longitude1),
      latlong.LatLng(latitude2, longitude2));
}
