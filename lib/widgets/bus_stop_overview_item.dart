import 'package:flutter/material.dart';

import '../models/bus_service.dart';
import '../models/bus_stop.dart';
import '../routes/home_page.dart';
import '../utils/bus_api.dart';
import '../utils/bus_service_arrival_result.dart';
import '../utils/bus_utils.dart';
import '../utils/database_utils.dart';
import '../widgets/bus_timing_row.dart';
import '../widgets/route_model.dart';

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
        padding: const EdgeInsets.only(top: 32.0, bottom: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0),
              child: Center(
                child: Column(
                  children: <Widget>[
                    Text(name, style: Theme.of(context).textTheme.headline6),
                    Text('$code · $road', style: Theme.of(context).textTheme.subtitle2.copyWith(color: Theme.of(context).hintColor)),
                  ],
                )
              ),
            ),
            _buildPinnedServices(widget.busStop.pinnedServices),
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedServices(List<BusService> pinnedServices) {
    if (pinnedServices == null || pinnedServices.isEmpty)
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
                ) : Center(
                  child: Text(BusAPI.kNoPinnedBusesError, style: Theme.of(context).textTheme.subtitle1.copyWith(color: Theme.of(context).hintColor)),
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
    HomePage.of(context).showBusDetailSheet(widget.busStop, RouteModel.of(context).route);
  }
}
