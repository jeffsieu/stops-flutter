import 'package:flutter/material.dart';
import 'package:stops_sg/models/bus_stop_with_pinned_services.dart';

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
  const BusStopOverviewItem(this.busStop, {Key? key}) : super(key: key);

  final BusStopWithPinnedServices busStop;

  @override
  State<StatefulWidget> createState() {
    return BusStopOverviewItemState();
  }
}

class BusStopOverviewItemState extends State<BusStopOverviewItem> {
  List<BusServiceArrivalResult>? _latestData;

  late final Stream<List<BusServiceArrivalResult>> _busArrivalStream =
      BusAPI().busStopArrivalStream(widget.busStop);
  // ignore: prefer_function_declarations_over_variables
  late final BusStopChangeListener _busStopListener = (BusStop busStop) {
    setState(() {
      widget.busStop.displayName = busStop.displayName;
    });
  };

  @override
  void initState() {
    super.initState();
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Ink(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                ),
                borderRadius: const BorderRadius.all(
                  Radius.circular(8.0),
                ),
              ),
              child: InkWell(
                borderRadius: const BorderRadius.all(
                  Radius.circular(8.0),
                ),
                onTap: _showDetailSheet,
                child: Container(
                  padding: const EdgeInsets.only(top: 48.0, bottom: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildPinnedServices(widget.busStop.pinnedServices),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 28.0, right: 28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Ink(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Text(name,
                          style: Theme.of(context).textTheme.headline6),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text('$code · $road',
                        style: Theme.of(context)
                            .textTheme
                            .subtitle2!
                            .copyWith(color: Theme.of(context).hintColor)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedServices(List<BusService> pinnedServices) {
    if (pinnedServices.isEmpty) {
      return Center(
        child: ListTile(
          title: Text(
            'No pinned services',
            style: TextStyle(
              color: Theme.of(context).hintColor,
            ),
          ),
          leading: Stack(
            children: [
              Icon(Icons.push_pin, color: Theme.of(context).hintColor),
              // Close icon scaled down and placed at the bottom right
              Positioned(
                right: 0.0,
                bottom: 0.0,
                child: Icon(
                  Icons.close,
                  size: 16.0,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
      child: StreamBuilder<List<BusServiceArrivalResult>>(
        initialData: _latestData,
        stream: _busArrivalStream,
        builder: (BuildContext context,
            AsyncSnapshot<List<BusServiceArrivalResult>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
              return const Center(child: Text(BusAPI.kNoInternetError));
            case ConnectionState.active:
            case ConnectionState.waiting:
              if (snapshot.data == null) {
                return const Center(child: Text(BusAPI.kLoadingMessage));
              }
              continue done;
            done:
            case ConnectionState.done:
              final List<BusServiceArrivalResult> busArrivals = snapshot.data!
                  .where((BusServiceArrivalResult result) =>
                      pinnedServices.contains(result.busService))
                  .toList(growable: false);
              busArrivals.sort((BusServiceArrivalResult a,
                      BusServiceArrivalResult b) =>
                  compareBusNumber(a.busService.number, b.busService.number));
              _latestData = snapshot.data;
              return busArrivals.isNotEmpty
                  ? AbsorbPointer(
                      absorbing: false,
                      child: Wrap(
                        spacing: 16.0,
                        direction: Axis.horizontal,
                        children: <Widget>[
                          for (BusServiceArrivalResult arrivalResult
                              in busArrivals)
                            BusTimingRow.unfocusable(widget.busStop,
                                arrivalResult.busService, arrivalResult)
                        ],
                      ),
                    )
                  : Center(
                      child: Text(BusAPI.kNoPinnedBusesError,
                          style: Theme.of(context)
                              .textTheme
                              .subtitle1!
                              .copyWith(color: Theme.of(context).hintColor)),
                    );
          }
        },
      ),
    );
  }

  void _showDetailSheet() {
    FocusScope.of(context).requestFocus(FocusNode());
    HomePage.of(context)!
        .showBusDetailSheet(widget.busStop, RouteModel.of(context)!.route);
  }
}
