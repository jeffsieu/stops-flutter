import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../routes/bus_service_page.dart';
import '../utils/cepas/cepas_card_transaction.dart';
import '../utils/cepas/cepas_card.dart';
import '../utils/cepas/nfc_commands.dart';

class ScanCardPage extends StatefulWidget {
  static DateFormat dateFormat = DateFormat('dd MMMM yyyy');

  @override
  State createState() {
    return ScanCardPageState();
  }
}

class ScanCardPageState extends State<ScanCardPage> with TickerProviderStateMixin {
  bool _tagLost = false;
  CEPASCard card;
  String get _prompt {
    return _tagLost ? 'Try again' : 'Scanning for cards';
  }
  String get _subPrompt {
    return _tagLost ? 'Your card moved too fast' : 'Hold card near device';
  }

  AnimationController _highlightController;
  AnimationStatusListener listener;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    listener = (AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _highlightController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _highlightController.forward();
      }
    };
    _scanForCards();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0.0,
        title: Text('Check card value', style: Theme.of(context).textTheme.headline6),
        brightness: Theme.of(context).brightness,
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white,
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AnimatedBuilder(
              animation: _highlightController,
              builder: (BuildContext context, Widget child) {
                return Container(
                  margin: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Color.lerp(Theme.of(context).scaffoldBackgroundColor, Theme.of(context).accentColor, _highlightController.value),
                      width: 4.0,
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                  ),
                  child: child,
                );
              },
              child: AspectRatio(
                aspectRatio: 85.60 / 53.98,
                child: Card(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16.0)),
                  ),
                  color: card != null ? Theme.of(context).cardColor : Theme.of(context).scaffoldBackgroundColor,
                  elevation: card != null ? 2.0 : 0,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: <Widget>[
                      if (card != null) ... <Widget>{
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: Icon(Icons.refresh, color: Theme.of(context).hintColor),
                            onPressed: () {
                              setState(() {
                                _scanForCards();
                              });
                            },
                          ),
                        ),
                        Center(child: Text('\$${card.balance}', style: Theme.of(context).textTheme.headline3.copyWith(color: Theme.of(context).colorScheme.onSurface))),
                        FittedBox(
                          child: Container(
                            padding: const EdgeInsets.all(32.0),
                            child: Text('CAN: ${_formatCan(card.can)}',
                              style: GoogleFonts.getFont(
                                StopsApp.monospacedFont,
                                textStyle: Theme.of(context).textTheme.headline5.copyWith(
                                  color: Theme.of(context).hintColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      }
                      else ... <Widget>{
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(_prompt, style: Theme.of(context).textTheme.headline5),
                            Text(_subPrompt, style: Theme.of(context).textTheme.headline6.copyWith(color: Theme.of(context).hintColor)),
                          ],
                        ),
                      },
                    ],
                  ),
                ),
              ),
            ),
            if (card != null)
              Padding(
                padding: const EdgeInsets.only(left: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Created: ${ScanCardPage.dateFormat.format(card.creationDate)}', style: Theme.of(context).textTheme.subtitle1.copyWith(color: Theme.of(context).hintColor)),
                    Text('Expiring: ${ScanCardPage.dateFormat.format(card.expiryDate)}', style: Theme.of(context).textTheme.subtitle1.copyWith(color: Theme.of(context).hintColor)),
                  ],
                ),
              ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: card?.transactions?.length ?? 0,
              itemBuilder: (BuildContext context, int position) {
                final CEPASCardTransaction transaction = card.transactions[position];
                String busServiceNumber = '';
                if (transaction.additionalData.toLowerCase().startsWith('bus')) {
                  busServiceNumber = RegExp(r'\d+').firstMatch(transaction.additionalData).group(0);
                }
                final String timeString = ScanCardPage.dateFormat.format(transaction.time);

                final DateTime currentDate = transaction.time;
                final DateTime previousDate = position > 0 ? card.transactions[position - 1].time : null;
                final bool sameDate = currentDate.day == previousDate?.day && currentDate.difference(previousDate).inDays == 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (!sameDate)
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, top: 32.0, right: 16.0, bottom: 16.0),
                        child: Text(timeString, style: Theme.of(context).textTheme.headline4),
                      ),
                    ListTile(
                      title: Text(_formatAmount(transaction.amountCents), style: Theme.of(context).textTheme.headline6),
                      subtitle: Text(
                        '${transaction.type}' + (busServiceNumber.isNotEmpty ? ' · $busServiceNumber' : ''),
                        style: Theme.of(context).textTheme.subtitle2.copyWith(color: Theme.of(context).hintColor),
                      ),
                      trailing: busServiceNumber.isNotEmpty ? PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Theme.of(context).hintColor),
                        onSelected: (String value) {
                          if (value == 'see bus') {
                            final Widget page = BusServicePage(busServiceNumber);
                            final Route<void> route = MaterialPageRoute<void>(builder: (BuildContext context) => page);
                            Navigator.push(context, route);
                          }
                        },
                        itemBuilder: (BuildContext context) {
                          return <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'see bus',
                              child: Text('See $busServiceNumber'),
                            ),
                          ];
                        },
                      ) : null,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    FlutterNfcKit.finish();
    _highlightController.dispose();
    super.dispose();
  }

  Future<void> _scanForCards() async {
    try {
      card = null;
      _highlightController.forward();
      _highlightController.addStatusListener(listener);
      final NFCTag tag = await FlutterNfcKit.poll();
      setState(() {
        _highlightController.removeStatusListener(listener);
        _highlightController.animateTo(1);
      });
      if (tag.type == NFCTagType.iso7816) {
        for (int purseId = 0; purseId < 16; purseId++) {
          final Uint8List result = await sendNfcCommand(<int>[0x90, 0x32, purseId, 0x00, 0x00]);
          if (result.isNotEmpty) {
            card = CEPASCard(purseId, result);
            await card.fetchTransactions();
            setState(() {
              _tagLost = false;
              _highlightController.removeStatusListener(listener);
              _highlightController.animateTo(0);
            });
          }
        }
      }
    } on PlatformException catch (e) {
      if (e.details == 'Tag was lost.') {
        _scanForCards();
        setState(() {
          _tagLost = true;
        });
      } else if (e.message == 'Polling tag timeout') {
        _scanForCards();
      }
    }
  }

  String _formatAmount(int amountCents) {
    return NumberFormat.simpleCurrency().format(amountCents / 100);
  }

  String _formatCan(String can) {
    assert(can.length == 16);
    return '${can.substring(0, 4)} ${can.substring(4, 8)} ${can.substring(8, 12)} ${can.substring(12, 16)}';
  }
}