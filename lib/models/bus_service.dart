import 'package:flutter/material.dart';

import '../utils/bus_api.dart';

class BusService {
  @protected
  BusService({
    required this.number,
    required this.operator,
  });

  final String number;
  final String operator;

  static BusService fromJson(dynamic json) {
    return BusService(
      number: json[BusAPI.kBusServiceNumberKey] as String,
      operator: json[BusAPI.kBusServiceOperatorKey] as String,
    );
  }

  static BusService fromMap(Map<String, dynamic> map) {
    return BusService(
      number: map['number'] as String,
      operator: map['operator'] as String,
    );
  }

  static Color listColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.redAccent
        : Colors.redAccent[100]!;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'number': number,
      'operator': operator,
    };
  }

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final BusService otherBusService = other as BusService;
    return number == otherBusService.number &&
        operator == otherBusService.operator;
  }

  @override
  int get hashCode {
    return number.hashCode ^ operator.hashCode;
  }
}
