import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' hide Consumer;
import 'package:stops_sg/bus_api/bus_api.dart';
import 'package:stops_sg/bus_api/models/bus_service.dart';
import 'package:stops_sg/bus_api/models/bus_service_arrival_result.dart';
import 'package:stops_sg/bus_api/models/bus_stop_with_pinned_services.dart';
import 'package:stops_sg/bus_stop_sheet/bloc/bus_stop_sheet_bloc.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/utils/bus_utils.dart';
import 'package:stops_sg/widgets/bus_timing_row.dart';
import 'package:stops_sg/widgets/edit_model.dart';
import 'package:stops_sg/widgets/outline_titled_container.dart';

class BusStopOverviewItem extends ConsumerWidget {
  const BusStopOverviewItem(this.busStop, {super.key});

  final BusStopWithPinnedServices busStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = busStop.displayName;
    final code = busStop.code;
    final road = busStop.road;

    const titleHorizontalPadding = 12.0;
    final Widget child = InkWell(
      borderRadius: const BorderRadius.all(
        Radius.circular(8.0),
      ),
      onTap: () => _showDetailSheet(context),
      child: Container(
        padding: const EdgeInsets.only(top: 40.0, bottom: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPinnedServices(context, ref, busStop.pinnedServices),
          ],
        ),
      ),
    );

    final isEditing = context.watch<EditModel>().isEditing;

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

  Widget _buildPinnedServices(
      BuildContext context, WidgetRef ref, List<BusService> pinnedServices) {
    if (pinnedServices.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: Text(BusApiError.noPinnedBuses.message,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(color: Theme.of(context).hintColor)),
            onPressed: () async {
              context.read<BusStopSheetBloc>().add(SheetRequested.withEdit(
                  busStop, context.read<StoredUserRoute>().id));
            },
          ),
        ],
      );
    }

    final busStopArrivals = ref.watch(busStopArrivalsProvider(busStop));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Builder(
        builder: (context) {
          switch (busStopArrivals) {
            case AsyncData(:final value):
              {
                final busArrivals = value
                    .where((BusServiceArrivalResult result) =>
                        pinnedServices.contains(result.busService))
                    .toList(growable: false);
                busArrivals.sort((BusServiceArrivalResult a,
                        BusServiceArrivalResult b) =>
                    compareBusNumber(a.busService.number, b.busService.number));

                return busArrivals.isNotEmpty
                    ? AbsorbPointer(
                        absorbing: false,
                        child: Wrap(
                          spacing: 16.0,
                          direction: Axis.horizontal,
                          children: [
                            for (BusServiceArrivalResult arrivalResult
                                in busArrivals)
                              BusTimingRow.unfocusable(busStop,
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
                            Text(BusApiError.noPinnedBusesInService.message,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium!
                                    .copyWith(
                                        color: Theme.of(context).hintColor)),
                          ],
                        ),
                      );
              }

            case AsyncError(:final error):
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.signal_wifi_connected_no_internet_4_rounded,
                      color: Theme.of(context).hintColor),
                  const SizedBox(width: 16.0),
                  Text(error.toString(),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(color: Theme.of(context).hintColor)),
                ],
              );
            case _:
              return Center(child: Text(BusApiError.loading.message));
          }
        },
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    FocusScope.of(context).unfocus();
    context
        .read<BusStopSheetBloc>()
        .add(SheetRequested(busStop, context.read<StoredUserRoute>().id));
  }
}
