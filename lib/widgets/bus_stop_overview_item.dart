import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:stops_sg/widgets/bus_timing_row.dart';

import '../routes/home_page.dart';
import '../utils/bus_api.dart';
import '../utils/bus_service.dart';
import '../utils/bus_service_arrival_result.dart';
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
  List<BusServiceArrivalResult> _latestData;

  Stream<List<BusServiceArrivalResult>> _busArrivalStream;
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

    _latestData = BusAPI().getLatestArrival(widget.busStop);

    return InkWell(
      onTap: _showDetailSheet,
      child: Container(
        padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0),
              child: Center(
//                child: RichText(
//                  text: TextSpan(
//                    text: '$name',
//                    children: <TextSpan>[
//                      TextSpan(
//                        text: ' · $code · $road',
//                        style: Theme.of(context)
//                            .textTheme
//                            .title
//                            .copyWith(color: Theme.of(context).hintColor),
//                      ),
//                    ],
//                    style: Theme.of(context).textTheme.title,
//                  ),
//                ),
                child: Column(
                  children: <Widget>[
                    Text(name, style: Theme.of(context).textTheme.title),
                    Text('$code · $road', style: Theme.of(context).textTheme.subtitle.copyWith(color: Theme.of(context).hintColor)),
                  ],
                )
              ),
            ),
            FutureBuilder<List<BusService>>(
              future: getPinnedServicesIn(widget.busStop),
              builder: (BuildContext context, AsyncSnapshot<List<BusService>> snapshot) {
                if (snapshot.data == null)
                  return Container();
                return _buildPinnedServices(snapshot.data);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedServices(List<BusService> pinnedServices) {
    if (pinnedServices.isEmpty)
      return Container();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: StreamBuilder<List<BusServiceArrivalResult>>(
        initialData: _latestData,
        stream: _busArrivalStream,
        builder: (BuildContext context, AsyncSnapshot<List<BusServiceArrivalResult>> snapshot) {
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
              final List<BusServiceArrivalResult> busArrivals = snapshot.data
                .where((BusServiceArrivalResult result) => pinnedServices.contains(result.busService))
                .toList(growable: false);
              busArrivals.sort((BusServiceArrivalResult a, BusServiceArrivalResult b) =>
                compareBusNumber(a.busService.number, b.busService.number));
              _latestData = snapshot.data;
              return Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0),
                child: busArrivals.isNotEmpty ?
                AbsorbPointer(
                  absorbing: true,
                  child: Wrap(
                    spacing: 16.0,
                    direction: Axis.horizontal,
                    children: <Widget>[
                      for (BusServiceArrivalResult arrivalResult in busArrivals)
                        BusTimingRow.unfocusable(widget.busStop, arrivalResult.busService, arrivalResult)
                    ],
                  ),
                ) : const Center(
                  child: Text(BusAPI.kNoPinnedBusesError),
                ),
              );
          }
          throw Exception('Something terribly wrong has happened');
        },
      ),
    );
  }

  void _showDetailSheet() {
    FocusScope.of(context).requestFocus(FocusNode());
    HomePage.of(context).showBusDetailSheet(widget.busStop);
  }
}

class BusTimingChip extends StatefulWidget {
  const BusTimingChip({@required this.serviceNumber, @required this.bus});

  final String serviceNumber;
  final Bus bus;

  @override
  _BusTimingChipState createState() => _BusTimingChipState();
}

class _BusTimingChipState extends State<BusTimingChip> {
  @override
  Widget build(BuildContext context) {
    return Chip(
      elevation: 2.0,
      backgroundColor: Theme.of(context).cardColor,
      label: RichText(
        text: TextSpan(
          children: <TextSpan>[
            TextSpan(
              text: '${widget.serviceNumber}',
              style: Theme.of(context).textTheme.body1.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  fontFamily: 'B612 Mono',
                  color: getBusLoadColor(widget.bus.load, MediaQuery.of(context).platformBrightness),
              ),
            ),
            TextSpan(
              text:  ' · ${getBusTimingVerbose(getMinutesFromNow(widget.bus.arrivalTime))}',
              style: Theme.of(context).textTheme.body1.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: getBusLoadColor(widget.bus.load, MediaQuery.of(context).platformBrightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
