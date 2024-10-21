import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/location/location.dart';
import 'package:stops_sg/utils/bus_stop_distance_utils.dart';
import 'package:stops_sg/widgets/crossed_icon.dart';
import 'package:stops_sg/widgets/outline_titled_container.dart';

const _minimumRefreshDuration = Duration(milliseconds: 300);

class NearbyStopsSection extends ConsumerStatefulWidget {
  const NearbyStopsSection({super.key});

  @override
  ConsumerState<NearbyStopsSection> createState() => _NearbyStopsSectionState();
}

class _NearbyStopsSectionState extends ConsumerState<NearbyStopsSection> {
  final TextEditingController _busServiceTextController =
      TextEditingController();
  String get _busServiceFilterText => _busServiceTextController.text;
  int _suggestionsCount = 1;
  AsyncValue<List<BusStop>?> get _nearestBusStops =>
      ref.watch(nearestBusStopsProvider(
          busServiceFilter: _busServiceFilterText,
          minimumRefreshDuration: _minimumRefreshDuration));

  @override
  Widget build(BuildContext context) {
    final hasLocationPermissions = ref.watch(userLocationProvider
        .select((value) => value.valueOrNull?.hasPermission ?? false));

    final homeRoute =
        ref.watch(savedUserRouteProvider(id: kDefaultRouteId)).valueOrNull;

    if (homeRoute == null) {
      return Container();
    }

    return Provider<StoredUserRoute>(
      create: (context) => homeRoute,
      child: Builder(
        builder: (BuildContext context) {
          if (!hasLocationPermissions) {
            return Container();
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16.0),
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                      'Nearby stops${_busServiceFilterText.isEmpty ? '' : ' (with bus $_busServiceFilterText)'}',
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Filter by bus service',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _busServiceTextController.clear();
                        });
                      },
                    ),
                  ),
                  controller: _busServiceTextController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16.0),
                AnimatedSize(
                  alignment: Alignment.topCenter,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: (_nearestBusStops.valueOrNull?.isNotEmpty ?? true)
                      ? ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          scrollDirection: Axis.vertical,
                          shrinkWrap: true,
                          itemCount: min(
                              _suggestionsCount,
                              _nearestBusStops.valueOrNull?.length ??
                                  _suggestionsCount),
                          separatorBuilder:
                              (BuildContext context, int position) =>
                                  const SizedBox(height: 8.0),
                          itemBuilder: (BuildContext context, int position) {
                            return switch (_nearestBusStops) {
                              AsyncData(:final value) =>
                                _buildSuggestionItem(value?[position]),
                              _ => _buildSuggestionItem(null),
                            };
                          },
                        )
                      : OutlineTitledContainer(
                          topOffset: 0,
                          body: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CrossedIcon(
                                  icon: Icon(
                                    Icons.directions_bus_rounded,
                                    color: Theme.of(context).hintColor,
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Text(
                                  'Nothing found',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(
                                          color: Theme.of(context).hintColor),
                                )
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8.0),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: TextButton.icon(
                          icon: _suggestionsCount <= 4
                              ? const Icon(Icons.keyboard_arrow_down_rounded)
                              : const Icon(Icons.keyboard_arrow_up_rounded),
                          label: _suggestionsCount <= 4
                              ? const Text('Show more')
                              : const Text('Collapse'),
                          onPressed: () {
                            setState(() {
                              if (_suggestionsCount <= 4) {
                                _suggestionsCount += 2;
                              } else {
                                _suggestionsCount = 1;
                              }
                            });
                          },
                        ),
                      ),
                      const VerticalDivider(),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                        onPressed: refreshLocation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void refreshLocation() {
    ref.invalidate(userLocationProvider);
    ref.invalidate(nearestBusStopsProvider);
  }

  Widget _buildSuggestionItem(BusStop? busStop) {
    final location = ref.watch(userLocationProvider);
    final latLng = location.valueOrNull?.data?.toLatLng();
    final distance =
        latLng != null ? busStop?.getMetersFromLocation(latLng) : null;

    final distanceText =
        '${distance?.floor() ?? Random().nextInt(500) + 100} m away';
    final busStopNameText = busStop?.displayName ?? 'Bus stop';
    final busStopCodeText = busStop != null
        ? '${busStop.code} · ${busStop.road}'
        : '${Random().nextInt(90000) + 10000} · ${Random().nextInt(99) + 1} Street';

    final showShimmer = _nearestBusStops.isRefreshing ||
        _nearestBusStops.isReloading ||
        _nearestBusStops.isLoading;

    Widget buildChild(bool showShimmer) => Builder(builder: (context) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: OutlineTitledContainer(
              showGap: !showShimmer,
              topOffset: 8.0,
              titlePadding: 16.0,
              title: Text(distanceText,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: Theme.of(context).hintColor)),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8.0),
                    // onTap: BusStopWithMetadata != null
                    //     ? () => context.read<BusStopSheetBloc>().add(
                    //         SheetRequested(
                    //             BusStopWithMetadata.busStop, kDefaultRouteId))
                    //     : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(busStopNameText,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(busStopCodeText,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall!
                                  .copyWith(
                                      color: Theme.of(context).hintColor)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      firstChild: Shimmer.fromColors(
        baseColor: Color.lerp(
            Theme.of(context).hintColor, Theme.of(context).canvasColor, 0.9)!,
        highlightColor: Theme.of(context).canvasColor,
        child: buildChild(true),
      ),
      secondChild: buildChild(false),
      crossFadeState:
          showShimmer ? CrossFadeState.showFirst : CrossFadeState.showSecond,
    );
  }
}
