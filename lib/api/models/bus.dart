
import 'bus_service.dart';
import 'bus_stop.dart';

class Bus {
  Bus({
    required this.busStop,
    required this.busService,
  });

  final BusStop busStop;
  final BusService busService;
}