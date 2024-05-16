import 'dart:math';
import 'dart:typed_data';

import 'package:stops_sg/utils/cepas/cepas_card_transaction.dart';
import 'package:stops_sg/utils/cepas/nfc_commands.dart';

class CEPASCard {
  CEPASCard(this.purseId, Uint8List data) {
    var tmp = (data[2] << 16) + (data[3] << 8) + data[4];
    /* Sign-extend the value */
    if (0 != (data[2] & 0x80)) {
      tmp |= 0xff000000;
    }
    final purseBalance = tmp;
    balance = purseBalance / 100;

    final canBytes = Uint8List.sublistView(data, 8, 16);
    can = canBytes.map((int i) => i.toRadixString(16).padLeft(2, '0')).join('');

    final expiryDaysFromEpoch =
        ByteData.sublistView(data, 24, 26).getInt16(0);
    expiryDate = DateTime.utc(1995, 01, 01)
        .add(Duration(days: expiryDaysFromEpoch, hours: 8));

    final creationDaysFromEpoch =
        ByteData.sublistView(data, 26, 28).getInt16(0);
    creationDate = DateTime.utc(1995, 01, 01)
        .add(Duration(days: creationDaysFromEpoch, hours: 8));

    transactionCount = data[40];
  }

  Future<void> fetchTransactions() async {
    const recordSize = 16;
    transactions = <CEPASCardTransaction>[];

    var historyRaw = await sendNfcCommand(<int>[
      0x90,
      0x32,
      purseId,
      0x00,
      0x01,
      0x00,
      min(transactionCount, 15) * 16
    ]);
    if (transactionCount > 15) {
      final historyRaw2 = await sendNfcCommand(<int>[
        0x90,
        0x32,
        purseId,
        0x00,
        0x01,
        0x0F,
        (transactionCount - 15) * 16
      ]);
      historyRaw = Uint8List.fromList(historyRaw + historyRaw2);
    }

    final recordCount = historyRaw.length ~/ recordSize;
    for (var i = 0; i < recordCount; i++) {
      transactions.add(CEPASCardTransaction(Uint8List.sublistView(
          historyRaw, i * recordSize, (i + 1) * recordSize)));
    }
  }

  final int purseId;
  late final double balance;
  late final String can;
  late final DateTime expiryDate;
  late final DateTime creationDate;
  late final int transactionCount;
  late final List<CEPASCardTransaction> transactions;
}
