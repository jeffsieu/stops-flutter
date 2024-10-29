import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'nfc_availability.g.dart';

@riverpod
Future<NFCAvailability> nfcAvailability(NfcAvailabilityRef ref) async {
  return await FlutterNfcKit.nfcAvailability;
}
