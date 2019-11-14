import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../routes/home_page.dart';
import '../utils/bus_api.dart';
import '../utils/bus_stop.dart';
import '../utils/bus_utils.dart';
import '../utils/database_utils.dart';
import '../utils/time_utils.dart';

class BusStopOverviewItem extends StatefulWidget {
  const BusStopOverviewItem(this.busStop, {Key key}) : super(key: key);

  final BusStop busStop;

  @override
  State<StatefulWidget> createState() {
    return BusStopOverviewItemState();
  }
}

class BusStopOverviewItemState extends State<BusStopOverviewItem> {
  String _latestData;
  List<dynamic> _buses = <dynamic>[];

  Stream<String> _busArrivalStream;
  BusStopChangeListener _busStopListener;

  @override
  void initState() {
    super.initState();
    _busArrivalStream = BusAPI().busStopArrivalStream(widget.busStop);
    _busStopListener = (BusStop busStop) {
      setState(() {
        widget.busStop.displayName = busStop.displayName;
      });
    };
    registerBusStopListener(widget.busStop, _busStopListener);
  }

  @override
  void dispose() {
    unregisterBusStopListener(widget.busStop, _busStopListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.busStop.displayName;
    final String code = widget.busStop.code;
    final String road = widget.busStop.road;

    _latestData = BusAPI().busStopArrivalLatest(widget.busStop);

    return InkWell(
      onTap: () {
        _showDetailSheet(context, widget.busStop);
      },
      child: Container(
        padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
              child: RichText(
                text: TextSpan(
                  text: '$name',
                  children: <TextSpan>[
                    TextSpan(
                      text: ' · $code · $road',
                      style: Theme.of(context)
                          .textTheme
                          .title
                          .copyWith(color: Theme.of(context).hintColor),
                    ),
                  ],
                  style: Theme.of(context).textTheme.title,
                ),
              ),
            ),
            StreamBuilder<String>(
              initialData: _latestData,
              stream: _busArrivalStream,
              builder:
                  (BuildContext context, AsyncSnapshot<String> snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.none:
                    return const Center(
                        child: Text(BusAPI.kNoInternetError));
                  case ConnectionState.active:
                  case ConnectionState.waiting:
                    if (snapshot.data == null)
                      return const Center(
                          child: Text(BusAPI.kLoadingMessage));
                    continue done;
                  done:
                  case ConnectionState.done:
                    _latestData = snapshot.data;
                    _buses = jsonDecode(_latestData)['Services'];
                    _buses.sort((dynamic a, dynamic b) =>
                        compareBusNumber(a['ServiceNo'], b['ServiceNo']));
                    return Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                      child: _buses.isNotEmpty ?
                        Wrap(
                          spacing: 16.0,
                          direction: Axis.horizontal,
                          children: <Widget>[
                            for (dynamic bs in _buses)
                              BusTimingChip(
                                serviceNumber: bs['ServiceNo'],
                                nextBus: bs['NextBus']
                              ),
                          ],
                        ) : const Center(
                        child: Text(BusAPI.kNoBusesError),
                      ),
                    );
                }
                throw Exception('Something terribly wrong has happened');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context, BusStop busStop) {
    FocusScope.of(context).requestFocus(FocusNode());
    HomePage.of(context).showBusDetailSheet(busStop);
  }
}

class BusTimingChip extends StatefulWidget {
  const BusTimingChip({@required this.serviceNumber, @required this.nextBus});

  final String serviceNumber;
  final dynamic nextBus;

  @override
  _BusTimingChipState createState() => _BusTimingChipState();
}

class _BusTimingChipState extends State<BusTimingChip> {
  @override
  Widget build(BuildContext context) {
    return Chip(
      elevation: 2.0,
      label: RichText(
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: '${widget.serviceNumber}',
              style: Theme.of(context).textTheme.body1.copyWith(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'B612 Mono', color: getBusLoadColor(widget.nextBus['Load'], MediaQuery.of(context).platformBrightness)),
            ),
            TextSpan(
              text:  ' · ${getBusTimingVerbose(getMinutesFromNow(widget.nextBus['EstimatedArrival']))}',
              style: Theme.of(context).textTheme.body1.copyWith(fontWeight: FontWeight.bold, fontSize: 16, color: getBusLoadColor(widget.nextBus['Load'], MediaQuery.of(context).platformBrightness)),
            ),
          ],
        ),
      ),
      backgroundColor: Theme.of(context).cardColor,
    );
  }
}
