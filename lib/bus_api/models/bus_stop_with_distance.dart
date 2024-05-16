import 'package:stops_sg/bus_api/models/bus_stop.dart';

class BusStopWithDistance {
  const BusStopWithDistance(this.busStop, this.distance);

  final BusStop busStop;
  final double distance;
}
