import 'dart:typed_data';

import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

Future<Uint8List> sendNfcCommand(List<int> command) async {
  final Uint8List result = await FlutterNfcKit.transceive(Uint8List.fromList(command));
  return Uint8List.sublistView(result, 0, result.length - 2);
}
