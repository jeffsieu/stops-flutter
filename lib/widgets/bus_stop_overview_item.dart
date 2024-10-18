import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart' hide Consumer;
import 'package:shimmer/shimmer.dart';
import 'package:stops_sg/bus_api/bus_api.dart';
import 'package:stops_sg/bus_api/models/bus_service.dart';
import 'package:stops_sg/bus_api/models/bus_service_arrival_result.dart';
import 'package:stops_sg/bus_api/models/bus_stop_with_pinned_services.dart';
import 'package:stops_sg/bus_stop_sheet/bloc/bus_stop_sheet_bloc.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/utils/bus_utils.dart';
import 'package:stops_sg/widgets/bus_timing_row.dart';
import 'package:stops_sg/widgets/edit_model.dart';
import 'package:stops_sg/widgets/highlighted_icon.dart';
import 'package:stops_sg/widgets/outline_titled_container.dart';

class BusStopOverviewItem extends ConsumerStatefulWidget {
  const BusStopOverviewItem(this.busStop, {super.key});

  final BusStopWithPinnedServices busStop;

  @override
  ConsumerState<BusStopOverviewItem> createState() =>
      _BusStopOverviewItemState();
}

class _BusStopOverviewItemState extends ConsumerState<BusStopOverviewItem> {
  BusStopWithPinnedServices get busStop => widget.busStop;

  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final name = busStop.displayName;
    final code = busStop.code;
    final road = busStop.road;

    final Widget child = InkWell(
      borderRadius: const BorderRadius.all(
        Radius.circular(8.0),
      ),
      onTap: () {
        setState(() {
          isExpanded = !isExpanded;
        });
      },
      child: isExpanded
          ? Container(
              padding: const EdgeInsets.only(top: 40.0, bottom: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPinnedServices(context, ref, busStop.pinnedServices),
                ],
              ),
            )
          : Container(height: 60.0),
    );

    final isEditing = context.watch<EditModel>().isEditing;

    final showBusIcon = !isEditing && !isExpanded;
    final isTitleLarge = isExpanded && !isEditing;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: isEditing
          ? const EdgeInsets.symmetric(horizontal: 0, vertical: 8.0)
          : const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
      child: OutlineTitledContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        buildBody: !isEditing,
        showGap: false,
        title: AnimatedPadding(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: isEditing
              ? const EdgeInsetsDirectional.only(
                  top: 8.0, bottom: 8.0, start: 40)
              : isExpanded
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                widthFactor: showBusIcon ? 1 : 0,
                alignment: Alignment.center,
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: showBusIcon ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: Row(
                    children: [
                      HighlightedIcon(
                        opacity: showBusIcon ? 1 : 0,
                        iconColor: Theme.of(context).colorScheme.primary,
                        child: SvgPicture.asset(
                          'assets/images/bus-stop.svg',
                          width: 24.0,
                          height: 24.0,
                          colorFilter: ColorFilter.mode(
                              Theme.of(context).colorScheme.primary,
                              BlendMode.srcIn),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                    ],
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Ink(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      padding: isExpanded
                          ? const EdgeInsets.symmetric(horizontal: 4)
                          : EdgeInsets.zero,
                      child: AnimatedDefaultTextStyle(
                        style: isTitleLarge
                            ? Theme.of(context).textTheme.titleLarge!
                            : Theme.of(context).textTheme.titleMedium!,
                        curve: Curves.easeOutCubic,
                        duration: const Duration(milliseconds: 300),
                        child: Text(name),
                      ),
                    ),
                  ),
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: isExpanded
                        ? const EdgeInsets.symmetric(horizontal: 4)
                        : EdgeInsets.zero,
                    child: Text('$code · $road',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall!
                            .copyWith(color: Theme.of(context).hintColor)),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: child,
        titlePadding: 12,
        titleBorderGap: 0,
        topOffset: isExpanded ? 16.0 : 0.0,
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
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    for (var i = 0; i < 3; i++) ...{
                      Shimmer.fromColors(
                        baseColor: Color.lerp(Theme.of(context).hintColor,
                            Theme.of(context).canvasColor, 0.9)!,
                        highlightColor: Theme.of(context).canvasColor,
                        child: Container(
                          height: 36.0,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                      if (i < 2) const SizedBox(height: 8.0),
                    }
                  ],
                ),
              );
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
