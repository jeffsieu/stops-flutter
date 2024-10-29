import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'package:stops_sg/bus_api/models/bus_service_arrival_result.dart';

Color getBusOperatorColor(String operator) {
  switch (operator) {
    case 'SBST':
      return Colors.deepPurpleAccent;
    case 'SMRT':
      return Colors.deepOrange;
    case 'TTS':
      return Colors.green;
    case 'GAS':
      return Colors.red;
    default:
      return Colors.white;
  }
}

Color getBusLoadColor(BusLoad? load, ThemeData themeData) {
  MaterialColor color;
  switch (load) {
    case BusLoad.low:
      color = Colors.green;
      break;
    case BusLoad.medium:
      color = Colors.orange;
      break;
    case BusLoad.high:
      color = Colors.red;
      break;
    default:
      return Colors.transparent;
  }
  if (themeData.brightness == Brightness.light) {
    return color.harmonizeWith(themeData.colorScheme.primary);
  } else {
    return color.shade300.harmonizeWith(themeData.colorScheme.primary);
  }
}

String getBusTypeVerbose(BusType? type) {
  switch (type) {
    case BusType.single:
      return '';
    case BusType.double:
      return 'x2';
    case BusType.bendy:
      return 'x2';
    default:
      return '';
  }
}

String getBusTimingVerbose(int timeMinutes) {
  if (timeMinutes <= 1) {
    return 'Arriving';
  }
  return '$timeMinutes min';
}

String getBusTimingShortened(int timeMinutes) {
  if (timeMinutes <= 1) {
    return 'Arr';
  }
  return timeMinutes.toString();
}

String getDistanceVerboseFromMeters(double distanceMeters) {
  final distanceKilometers = distanceMeters / 1000;
  return distanceMeters < 1000
      ? '${distanceMeters.round()} m'
      : '${distanceKilometers.toStringAsFixed(1)} km';
}

int compareBusNumber(String a, String b) {
  final aNumber = int.parse(a.replaceAll(RegExp(r'\D'), ''));
  final bNumber = int.parse(b.replaceAll(RegExp(r'\D'), ''));

  var diff = (aNumber - bNumber) * 2;

  if (diff == 0) {
    final aLetter = a.replaceAll(RegExp(r'\d'), '');
    final bLetter = b.replaceAll(RegExp(r'\d'), '');
    diff = aLetter.compareTo(bLetter).sign;
  }
  return diff;
}

extension BusNumberFormat on String {
  String padAsServiceNumber() {
    // Service number contains letter
    final serviceNumber = this;
    if (serviceNumber.contains(RegExp(r'\D'))) {
      final number = serviceNumber.substring(0, serviceNumber.length - 1);
      final letter = serviceNumber[serviceNumber.length - 1];
      return number.padLeft(3) + letter;
    } else {
      return serviceNumber.padLeft(3).padRight(1);
    }
  }
}
