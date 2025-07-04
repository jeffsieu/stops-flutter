import 'package:auto_size_text/auto_size_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:provider/provider.dart' hide Consumer;
import 'package:shimmer/shimmer.dart';
import 'package:stops_sg/bus_api/bus_api.dart';
import 'package:stops_sg/bus_api/models/bus_service_arrival_result.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/location/location.dart';
import 'package:stops_sg/routes/routes.dart';
import 'package:stops_sg/routes/saved_route.dart';
import 'package:stops_sg/routes/settings_route.dart';
import 'package:stops_sg/utils/bus_stop_distance_utils.dart';
import 'package:stops_sg/utils/bus_utils.dart';
import 'package:stops_sg/utils/distance_utils.dart';
import 'package:stops_sg/widgets/bus_stop_legend_card.dart';
import 'package:stops_sg/widgets/bus_timing_row.dart';
import 'package:stops_sg/widgets/edit_model.dart';
import 'package:stops_sg/widgets/highlighted_icon.dart';
import 'package:stops_sg/widgets/outline_titled_container.dart';

class BusStopItem extends StatefulHookConsumerWidget {
  const BusStopItem(
    this.busStop, {
    super.key,
    this.onTap,
    this.defaultExpanded,
    this.isLoading = false,
    this.hideSavedIcon = false,
  });

  final BusStop busStop;
  final void Function()? onTap;
  final bool? defaultExpanded;
  final bool hideSavedIcon;
  final bool isLoading;

  @override
  ConsumerState<BusStopItem> createState() => _BusStopItemState();
}

class _BusStopItemState extends ConsumerState<BusStopItem> {
  BusStop get busStop => widget.busStop;

  bool isExpanded = false;
  bool _showLegend = false;

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(userLocationProvider).value?.data?.toLatLng();
    final name = busStop.displayName;
    final code = busStop.code;
    final road = busStop.road;
    final route = context.watch<StoredUserRoute?>();

    useEffect(() {
      setState(() {
        isExpanded = widget.defaultExpanded ?? false;
      });
      return null;
    }, [widget.defaultExpanded]);

    final isSaved = (() {
      if (route == null) {
        return false;
      }

      return ref
              .watch(
                isBusStopInRouteProvider(busStop: busStop, routeId: route.id),
              )
              .value ??
          false;
    })();

    final Widget child = InkWell(
      borderRadius: const BorderRadius.all(
        Radius.circular(8.0),
      ),
      onTap: () {
        widget.onTap?.call();
        setState(() {
          isExpanded = !isExpanded;
        });
      },
      child: AnimatedCrossFade(
        firstChild: Container(
          padding: const EdgeInsets.only(top: 40.0, bottom: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPinnedServices(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Wrap(
                  spacing: 8.0,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      onPressed: () {
                        setState(() {
                          _showLegend = !_showLegend;
                        });
                      },
                      child: Text('Legend',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall!
                              .copyWith(color: Theme.of(context).hintColor)),
                    ),
                    OutlinedButton(
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      onPressed: () {
                        SettingsRoute().push(context);
                      },
                      child: Text('Missing bus services?',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall!
                              .copyWith(color: Theme.of(context).hintColor)),
                    ),
                  ],
                ),
              ),
              if (_showLegend)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: BusStopLegendCard(),
                ),
            ],
          ),
        ),
        secondChild: Container(height: 60.0),
        crossFadeState:
            isExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        duration: const Duration(milliseconds: 300),
        sizeCurve: Curves.easeOutCubic,
      ),
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
        backgroundColor: (widget.isLoading)
            ? Colors.transparent
            : Theme.of(context).scaffoldBackgroundColor,
        buildBody: !isEditing,
        showGap: false,
        title: AnimatedPadding(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: isEditing
              ? const EdgeInsetsDirectional.only(
                  top: 8.0, bottom: 8.0, start: 56)
              : isExpanded
                  ? const EdgeInsets.symmetric(horizontal: 8.0)
                  : const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IgnorePointer(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  widthFactor: showBusIcon ? 1 : 0,
                  alignment: Alignment.center,
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: showBusIcon ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: HighlightedIcon(
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
                        ),
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.center,
                          heightFactor: location != null ? 1 : 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            opacity: location != null ? 1 : 0,
                            child: widget.isLoading
                                ? Text(
                                    '100m',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall!
                                        .copyWith(
                                            color: Theme.of(context).hintColor),
                                  )
                                : (location != null)
                                    ? SizedBox(
                                        child: AutoSizeText(
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          formatDistance(
                                            busStop.getMetersFromLocation(
                                                location),
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall!
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .hintColor),
                                        ),
                                      )
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Ink(
                        color: widget.isLoading
                            ? Colors.transparent
                            : Theme.of(context).scaffoldBackgroundColor,
                        child: AnimatedPadding(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          padding: isExpanded
                              ? const EdgeInsets.symmetric(horizontal: 8)
                              : EdgeInsets.zero,
                          child: AnimatedDefaultTextStyle(
                            style: isTitleLarge
                                ? Theme.of(context).textTheme.titleLarge!
                                : Theme.of(context).textTheme.titleMedium!,
                            curve: Curves.easeOutCubic,
                            duration: const Duration(milliseconds: 300),
                            child: AutoSizeText(
                              name,
                              maxLines: 1,
                              stepGranularity: 0.1,
                            ),
                          ),
                        ),
                      ),
                      AnimatedPadding(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        padding: isExpanded
                            ? const EdgeInsets.symmetric(horizontal: 8)
                            : EdgeInsets.zero,
                        child: Text('$code · $road',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(color: Theme.of(context).hintColor)),
                      ),
                    ],
                  ),
                ),
              ),
              if (!widget.hideSavedIcon) ...{
                IgnorePointer(
                  ignoring: !isExpanded,
                  child: AnimatedOpacity(
                    opacity: isExpanded ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: IconButton.outlined(
                      style: IconButton.styleFrom(
                        backgroundColor: isSaved
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).scaffoldBackgroundColor,
                        foregroundColor: isSaved
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).hintColor,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        if (!isSaved) {
                          ref
                              .read(savedUserRouteProvider(id: kDefaultRouteId)
                                  .notifier)
                              .addBusStop(busStop);

                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Saved ${busStop.displayName}'),
                            action: SnackBarAction(
                              label: 'View',
                              onPressed: () {
                                SavedRoute().go(context);
                              },
                            ),
                          ));
                          return;
                        }

                        showModalBottomSheet(
                          isScrollControlled: true,
                          useRootNavigator: true,
                          useSafeArea: true,
                          context: context,
                          builder: (context) => DraggableScrollableSheet(
                            expand: false,
                            builder: (context, scrollController) =>
                                Consumer(builder: (context, ref, child) {
                              final routes = ref.watch(savedUserRoutesProvider);

                              return switch (routes) {
                                AsyncData(:final value) => Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                                start: 16.0,
                                                end: 16.0,
                                                top: 24.0),
                                        child: Text('Save to',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge),
                                      ),
                                      ListView.builder(
                                        shrinkWrap: true,
                                        controller: scrollController,
                                        itemBuilder: (context, index) {
                                          final route = value[index];
                                          final isBusStopInRoute = ref
                                                  .watch(
                                                      isBusStopInRouteProvider(
                                                          busStop: busStop,
                                                          routeId: route.id))
                                                  .value ??
                                              false;

                                          return CheckboxListTile(
                                            value: isBusStopInRoute,
                                            title: Text(route.name),
                                            onChanged: (checked) async {
                                              if (checked ?? false) {
                                                await ref
                                                    .read(
                                                        savedUserRouteProvider(
                                                                id: route.id)
                                                            .notifier)
                                                    .addBusStop(busStop);
                                              } else {
                                                await ref
                                                    .read(
                                                        savedUserRouteProvider(
                                                                id: route.id)
                                                            .notifier)
                                                    .removeBusStop(busStop);
                                              }
                                            },
                                          );
                                        },
                                        itemCount: value.length,
                                      ),
                                    ],
                                  ),
                                _ => const SizedBox(),
                              };
                            }),
                          ),
                        );
                      },
                      selectedIcon: const Icon(Icons.bookmark_added_rounded),
                      isSelected: isSaved,
                      icon: const Icon(Icons.bookmark_add_outlined),
                    ),
                  ),
                )
              },
            ],
          ),
        ),
        body: child,
        titlePadding: 0,
        titleBorderGap: 0,
        topOffset: isExpanded ? 16.0 : 0.0,
      ),
    );
  }

  Widget _buildPinnedServices(BuildContext context) {
    final routeId = context.watch<StoredUserRoute?>()?.id;
    final pinnedServices = routeId != null
        ? ref.watch(pinnedServicesProvider(busStop, routeId)).value
        : null;

    if (pinnedServices == null) {
      return Shimmer.fromColors(
        baseColor: Color.lerp(
            Theme.of(context).hintColor, Theme.of(context).canvasColor, 0.9)!,
        highlightColor: Theme.of(context).canvasColor,
        child: Container(
          height: 36.0,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      );
    }

    final busStopArrivals = ref.watch(busStopArrivalsProvider(busStop));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Builder(
        builder: (context) {
          switch (busStopArrivals) {
            case AsyncValue<List<BusServiceArrivalResult>>(:final value?):
              {
                final busArrivals = value
                    .where((BusServiceArrivalResult result) =>
                        pinnedServices.isEmpty ||
                        pinnedServices.contains(result.busService))
                    .sorted((BusServiceArrivalResult a,
                            BusServiceArrivalResult b) =>
                        compareBusNumber(
                            a.busService.number, b.busService.number))
                    .toList(growable: false);

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

            case AsyncValue(:final error?):
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
}
