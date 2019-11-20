import 'package:flutter/material.dart';

import 'bus_service_arrival_result.dart';

Color getBusOperatorColor(String operator) {
  switch(operator) {
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

Color getBusLoadColor(BusLoad load, Brightness brightness) {
  MaterialColor color;
  switch(load) {
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
  if (brightness == Brightness.light)
    return color;
  else
    return color.shade300;
}

String getBusTypeVerbose(BusType type) {
  switch(type) {
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
  final double distanceKilometers = distanceMeters / 1000;
  return distanceMeters < 1000 ? '${distanceMeters.round()} m' : '${distanceKilometers.toStringAsFixed(1)} km';
}

int compareBusNumber(String a, String b) {
  final int aNumber = int.parse(a
      .replaceAll(RegExp(r'\D'), ''));
  final int bNumber = int.parse(b
      .replaceAll(RegExp(r'\D'), ''));

  int diff = (aNumber - bNumber) * 2;

  if (diff == 0) {
    final String aLetter = a
        .replaceAll(RegExp(r'\d'), '');
    final String bLetter = b
        .replaceAll(RegExp(r'\d'), '');
    diff = aLetter
        .compareTo(bLetter)
        .sign;
  }
  return diff;
}