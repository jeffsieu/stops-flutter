import 'dart:math';
import 'dart:typed_data';

import 'cepas_card_transaction.dart';
import 'nfc_commands.dart';

class CEPASCard {
  CEPASCard(this.purseId, Uint8List data) {
    int tmp = (data[2] << 16) + (data[3] << 8) + data[4];
    /* Sign-extend the value */
    if (0 != (data[2] & 0x80)) {
      tmp |= 0xff000000;
    }
    final int purseBalance = tmp;
    balance = purseBalance / 100;

    final Uint8List canBytes = Uint8List.sublistView(data, 8, 16);
    can = canBytes.map((int i) => i.toRadixString(16).padLeft(2, '0')).join('');

    final int expiryDaysFromEpoch = ByteData.sublistView(data, 24, 26).getInt16(0);
    expiryDate = DateTime.utc(1995, 01, 01).add(Duration(days: expiryDaysFromEpoch, hours: 8));

    final int creationDaysFromEpoch = ByteData.sublistView(data, 26, 28).getInt16(0);
    creationDate = DateTime.utc(1995, 01, 01).add(Duration(days: creationDaysFromEpoch, hours: 8));

    transactionCount = data[40];
  }

  Future<void> fetchTransactions() async {
    const int recordSize = 16;
    transactions = <CEPASCardTransaction>[];

    Uint8List historyRaw = await sendNfcCommand(<int>[0x90, 0x32, purseId, 0x00, 0x01, 0x00, min(transactionCount, 15) * 16]);
    if (historyRaw == null)
      return;
    if (transactionCount > 15) {
      final Uint8List historyRaw2 = await sendNfcCommand(<int>[0x90, 0x32, purseId, 0x00, 0x01, 0x0F, (transactionCount - 15) * 16]);
      historyRaw = Uint8List.fromList(historyRaw + historyRaw2);
    }

    final int recordCount = historyRaw.length ~/ recordSize;
    for (int i = 0; i < recordCount; i++) {
      transactions.add(CEPASCardTransaction(Uint8List.sublistView(historyRaw, i * recordSize, (i + 1) * recordSize)));
    }
  }

  int purseId;
  double balance;
  String can;
  DateTime expiryDate;
  DateTime creationDate;
  int transactionCount;
  List<CEPASCardTransaction> transactions;
}
