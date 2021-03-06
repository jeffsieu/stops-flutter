import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import '../utils/bus_api.dart';
import 'bus_route.dart';
import 'bus_stop.dart';

class BusService {

  BusService._({
    @required this.number,
    @required this.operator,
  });

  List<BusServiceRoute> _routes;
  final String number;
  final String operator;

  set routes(List<BusServiceRoute> routes) {
    _routes = routes;
    for (final BusServiceRoute route in _routes)
      route.service = this;
  }

  List<BusServiceRoute> get routes => _routes;
  int get directionCount => _routes.length;
  List<BusStop> get origin => _routes.map<BusStop>((BusServiceRoute route) => route.origin).toList(growable: false);
  List<BusStop> get destination => _routes.map<BusStop>((BusServiceRoute route) => route.destination).toList(growable: false);

  static BusService fromJson(dynamic json) {
    return BusService._(
      number: json[BusAPI.kBusServiceNumberKey],
      operator: json[BusAPI.kBusServiceOperatorKey],
    );
  }

  static BusService fromMap(Map<String, dynamic> map) {
    return BusService._(
        number: map['number'],
        operator: map['operator'],
    );
  }
  
  static Color listColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light ? Colors.redAccent : Colors.redAccent[100];
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'number': number,
      'operator': operator,
    };
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType)
      return false;
    final BusService otherBusService = other;
    return number == otherBusService.number && operator == otherBusService.operator;
  }

  @override
  int get hashCode {
    return number.hashCode ^ operator.hashCode;
  }
}