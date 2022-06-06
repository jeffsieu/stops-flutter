import 'dart:typed_data';

class CEPASCardTransaction {
  CEPASCardTransaction(Uint8List data) {
    _typeRaw = data[0];

    /* Sign-extend */
    List<int> amountRaw = Uint8List.sublistView(data, 1, 4);
    if (0 != (data[1] & 0x80)) {
      amountRaw = <int>[255] + amountRaw;
    } else {
      amountRaw = <int>[0] + amountRaw;
    }
    amountCents =
        ByteData.sublistView(Uint8List.fromList(amountRaw), 0, 4).getInt32(0);

    /* Date is expressed in seconds, but the epoch is January 1 1995, SGT */
    final seconds = ByteData.sublistView(data, 4, 8).getInt32(0);
    time = DateTime.utc(1995, 01, 01).add(Duration(seconds: seconds, hours: 8));
    additionalData = String.fromCharCodes(Uint8List.sublistView(data, 8, 16));
  }

  late final DateTime time;
  late final int amountCents;
  late final int _typeRaw;
  late final String additionalData;

  String get type {
    switch (_typeRaw) {
      case 48:
        return 'MRT';
      case 117:
      case 3:
        return 'TOP_UP';
      case 49:
        return 'Bus';
      case 118:
        return 'Bus refund';
      case -16:
      case 5:
        return 'Creation';
      case 4:
        return 'Service';
      case 1:
        return 'Retail';
      default:
        return 'Unknown';
    }
  }
}
