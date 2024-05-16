
import 'package:stops_sg/bus_api/models/bus_service.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';

class Bus {
  Bus({
    required this.busStop,
    required this.busService,
  });

  final BusStop busStop;
  final BusService busService;
}