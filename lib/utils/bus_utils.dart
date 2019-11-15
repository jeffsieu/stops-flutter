import 'package:flutter/material.dart';

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

Color getBusLoadColor(String loadRaw, Brightness brightness) {
  switch(loadRaw) {
    case 'SEA':
      if (brightness == Brightness.light)
        return Colors.green;
      else
        return Colors.green.shade300;
      break;
    case 'SDA':
      return Colors.orange;
      break;
    case 'LSD':
      return Colors.red;
    default:
      return Colors.transparent;
  }
}

String getBusTypeVerbose(String busTypeRaw) {
  switch(busTypeRaw) {
    case 'SD':
      return '';
    case 'DD':
      return 'x2';
    case 'BD':
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