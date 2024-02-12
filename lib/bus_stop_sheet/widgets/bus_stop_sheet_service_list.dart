import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bus_stop.dart';
import '../../utils/bus_api.dart';
import '../../utils/bus_service_arrival_result.dart';
import '../../utils/bus_utils.dart';
import '../../utils/database_utils.dart';
import '../../widgets/bus_timing_row.dart';
import '../../widgets/info_card.dart';
import '../bloc/bus_stop_sheet_bloc.dart';
import 'bus_stop_sheet.dart';

class BusStopSheetServiceList extends ConsumerWidget {
  const BusStopSheetServiceList({super.key, required this.timingListAnimation});

  final Animation<double> timingListAnimation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing =
        context.select((BusStopSheetBloc bloc) => bloc.state.isEditing);
    final busStop =
        context.select((BusStopSheetBloc bloc) => bloc.state.busStop)!;
    final routeId =
        context.select((BusStopSheetBloc bloc) => bloc.state.routeId)!;
    return Column(
      children: [
        AnimatedSize(
          duration: kSheetEditDuration * 2,
          curve: Curves.easeInOutCirc,
          child: isEditing
              ? Container(
                  padding: const EdgeInsets.only(
                      left: 32.0, right: 32.0, bottom: 8.0),
                  child: Column(
                    children: [
                      Text(
                        'Pinned bus services',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        'Arrival times of pinned buses are displayed on the ${routeId == kDefaultRouteId ? 'homepage' : 'route page'}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .copyWith(color: Theme.of(context).hintColor),
                      )
                    ],
                  ))
              : Container(),
        ),
        _buildTimingList(context, ref, busStop, isEditing),
      ],
    );
  }

  Widget _buildTimingList(
      BuildContext context, WidgetRef ref, BusStop busStop, bool isEditing) {
    final busStopServices = ref.watch(busStopServicesProvider(busStop));
    final busStopArrivals = ref.watch(busStopArrivalsProvider(busStop));

    switch (busStopArrivals) {
      case AsyncData(:final value):
        {
          final buses = value;
          final fallbackServices = buses
              .map((e) => e.busService)
              .toSet()
              .sortedBy((element) => element.number);
          final allServices = busStopServices.value ?? fallbackServices;
          buses.sort((BusServiceArrivalResult a, BusServiceArrivalResult b) =>
              compareBusNumber(a.busService.number, b.busService.number));

          // Calculate the positions that the bus services will be displayed at
          // If the bus service has no arrival timings, it will not show and
          // will have a position of -1
          final displayedPositions =
              List<int>.generate(allServices.length, (int i) => -1);
          for (var i = 0, j = 0;
              i < allServices.length && j < buses.length;
              i++) {
            if (allServices[i] == buses[j].busService) {
              displayedPositions[i] = j;
              j++;
            }
          }

          return Stack(
            children: [
              if (buses.isEmpty)
                AnimatedOpacity(
                  duration: kSheetEditDuration,
                  opacity: isEditing ? 0 : 1,
                  child: _buildStaggeredFadeInTransition(
                    position: 0,
                    child: Center(
                      child: InfoCard(
                        icon: Icon(Icons.bus_alert_rounded,
                            color: Theme.of(context).hintColor),
                        title: Text(
                          BusApiError.noBusesInService.message,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium!
                              .copyWith(color: Theme.of(context).hintColor),
                        ),
                      ),
                    ),
                  ),
                ),
              MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (BuildContext context, int position) {
                    final displayedPosition = displayedPositions[position];
                    final isDisplayed = displayedPosition != -1;

                    BusServiceArrivalResult? arrivalResult;
                    if (isDisplayed) arrivalResult = buses[displayedPosition];

                    final Widget item = BusTimingRow(
                      busStop,
                      allServices[position],
                      arrivalResult,
                      isEditing,
                      key: Key(busStop.code + allServices[position].number),
                    );

                    // Animate if displayed
                    if (isDisplayed) {
                      return _buildStaggeredFadeInTransition(
                        child: item,
                        position: displayedPosition,
                      );
                    } else {
                      return item;
                    }
                  },
                  separatorBuilder: (BuildContext context, int position) {
                    // Checks if the item below the divider is shown, and not the first item
                    // If it is, then show the divider
                    final displayedPositionBottom =
                        displayedPositions[position + 1];
                    final isBottomDisplayed = displayedPositionBottom > 0;
                    final isDisplayed = isEditing || isBottomDisplayed;
                    return isDisplayed
                        ? const Divider(height: 4.0)
                        : Container();
                  },
                  itemCount: allServices.length,
                ),
              ),
            ],
          );
        }
      case AsyncError(:final error):
        {
          return Center(
            child: InfoCard(
              icon: Icon(Icons.signal_wifi_connected_no_internet_4_rounded,
                  color: Theme.of(context).hintColor),
              title: Text(
                error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(color: Theme.of(context).hintColor),
              ),
            ),
          );
        }
      default:
        {
          return const Center(child: CircularProgressIndicator());
        }
    }
  }

  Widget _messageBox(BuildContext context, String text) {
    return Center(
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .titleMedium!
              .copyWith(color: Theme.of(context).hintColor)),
    );
  }

  // The transition for a row in the timing list
  Widget _buildStaggeredFadeInTransition(
      {Widget? child, required int position}) {
    final startOffset = (position * kSheetRowAnimationOffset).clamp(0.0, 1.0);
    final endOffset =
        (position * kSheetRowAnimationOffset + kSheetRowAnimDuration)
            .clamp(0.0, 1.0);
    final animation = timingListAnimation
        .drive(CurveTween(
            curve: const Interval(
                kTitleFadeInDurationFactor - kSheetRowAnimationOffset,
                1))) // animate after previous code disappears
        .drive(CurveTween(
            curve: Interval(
                startOffset, endOffset))); // delay animation based on position

    return SlideTransition(
      position: animation
          .drive(CurveTween(curve: Curves.easeOutQuint))
          .drive(Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}
