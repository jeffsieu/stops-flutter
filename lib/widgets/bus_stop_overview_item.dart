import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../bus_stop_sheet/bloc/bus_stop_sheet_bloc.dart';
import '../models/bus_service.dart';
import '../models/bus_stop.dart';
import '../models/bus_stop_with_pinned_services.dart';
import '../models/user_route.dart';
import '../routes/bottom_sheet_page.dart';
import '../routes/home_page.dart';
import '../utils/bus_api.dart';
import '../utils/bus_service_arrival_result.dart';
import '../utils/bus_utils.dart';
import '../utils/database_utils.dart';
import '../widgets/bus_timing_row.dart';
import 'edit_model.dart';
import 'outline_titled_container.dart';

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

  @override
  void initState() {
    super.initState();
    _latestData = BusAPI().getLatestArrival(widget.busStop);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.busStop.displayName;
    final String code = widget.busStop.code;
    final String road = widget.busStop.road;

    const double titleHorizontalPadding = 12.0;
    final Widget child = InkWell(
      borderRadius: const BorderRadius.all(
        Radius.circular(8.0),
      ),
      onTap: _showDetailSheet,
      child: Container(
        padding: const EdgeInsets.only(top: 40.0, bottom: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPinnedServices(widget.busStop.pinnedServices),
          ],
        ),
      ),
    );

    final bool isEditing = context.watch<EditModel>().isEditing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: isEditing
          ? const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0)
          : const EdgeInsets.symmetric(vertical: 16.0, horizontal: 0),
      child: OutlineTitledContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        buildBody: !isEditing,
        collapsedTitlePadding: const EdgeInsetsDirectional.only(
            start: 48.0, end: 16.0, top: 8.0, bottom: 8.0),
        title: Text(name, style: Theme.of(context).textTheme.titleLarge),
        childrenBelowTitle: [
          Text('$code · $road',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(color: Theme.of(context).hintColor)),
        ],
        body: child,
        titlePadding: titleHorizontalPadding,
        topOffset: 16.0,
      ),
    );
  }

  Widget _buildPinnedServices(List<BusService> pinnedServices) {
    if (pinnedServices.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: Text(BusAPI.kNoPinnedBusesError,
                style: Theme.of(context)
                    .textTheme
                    .subtitle1!
                    .copyWith(color: Theme.of(context).hintColor)),
            onPressed: () async {
              context.read<BusStopSheetBloc>().add(SheetRequested.withEdit(
                  widget.busStop, context.read<StoredUserRoute>().id));
            },
          ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: StreamBuilder<List<BusServiceArrivalResult>>(
        initialData: _latestData,
        stream: _busArrivalStream,
        builder: (BuildContext context,
            AsyncSnapshot<List<BusServiceArrivalResult>> snapshot) {
          if (snapshot.hasError) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.signal_wifi_connected_no_internet_4_rounded,
                    color: Theme.of(context).hintColor),
                const SizedBox(width: 16.0),
                Text(snapshot.error.toString(),
                    style: Theme.of(context)
                        .textTheme
                        .subtitle1!
                        .copyWith(color: Theme.of(context).hintColor)),
              ],
            );
          }
          switch (snapshot.connectionState) {
            case ConnectionState.none:
            // Should not happen.
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
                        children: [
                          for (BusServiceArrivalResult arrivalResult
                              in busArrivals)
                            BusTimingRow.unfocusable(widget.busStop,
                                arrivalResult.busService, arrivalResult)
                        ],
                      ),
                    )
                  : Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bus_alert_rounded,
                              color: Theme.of(context).hintColor),
                          const SizedBox(width: 16.0),
                          Text(BusAPI.kNoPinnedBusesInServiceError,
                              style: Theme.of(context)
                                  .textTheme
                                  .subtitle1!
                                  .copyWith(
                                      color: Theme.of(context).hintColor)),
                        ],
                      ),
                    );
          }
        },
      ),
    );
  }

  void _showDetailSheet() {
    FocusScope.of(context).unfocus();
    context.read<BusStopSheetBloc>().add(
        SheetRequested(widget.busStop, context.read<StoredUserRoute>().id));
  }
}
