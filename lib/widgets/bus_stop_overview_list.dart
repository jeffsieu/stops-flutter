import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:provider/provider.dart';

import '../models/user_route.dart';
import '../utils/database_utils.dart';
import '../utils/reorder_status_notification.dart';
import '../widgets/bus_stop_overview_item.dart';
import 'edit_model.dart';

class BusStopOverviewList extends ConsumerWidget {
  const BusStopOverviewList({super.key, required this.routeId});

  final int routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = context.watch<EditModel>().isEditing;
    final route = ref.watch(savedUserRouteProvider(id: routeId));

    switch (route) {
      case AsyncData(:final value):
        {
          if (value == null || value.busStops.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text(
                    'Pinned bus stops appear here.\n\nTap the pin next to a bus stop to pin it.\n\n\nAdd a route to organize multiple bus stops together.',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium!
                        .copyWith(color: Theme.of(context).hintColor)),
              ),
            );
          }

          final busStops = value.busStops;

          return Provider<StoredUserRoute>(
            create: (_) => value,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ReorderableListView.builder(
                shrinkWrap: true,
                buildDefaultDragHandles: false,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: busStops.length,
                onReorderStart: (int position) {
                  ReorderStatusNotification(true).dispatch(context);
                },
                onReorder: (
                  int oldIndex,
                  int newIndex,
                ) async {
                  ReorderStatusNotification(false).dispatch(context);

                  await ref
                      .read(savedUserRouteProvider(id: routeId).notifier)
                      .moveBusStop(oldIndex, newIndex);
                },
                itemBuilder: (BuildContext context, int position) {
                  final busStop = busStops[position];
                  final Widget busStopItem = BusStopOverviewItem(
                    busStop,
                    key: Key(busStop.code +
                        Object.hashAll(busStop.pinnedServices).toString()),
                  );

                  return Stack(
                    key: Key(busStop.hashCode.toString()),
                    alignment: Alignment.centerLeft,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: busStopItem,
                      ),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 600),
                        opacity: isEditing ? 1.0 : 0.0,
                        curve: const Interval(0.5, 1),
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 600),
                          offset:
                              isEditing ? Offset.zero : const Offset(0, 0.25),
                          curve: const Interval(0.5, 1,
                              curve: Curves.easeOutCubic),
                          child: isEditing
                              ? ReorderableDragStartListener(
                                  index: position,
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                        start: 32.0),
                                    child: Icon(
                                      Icons.drag_handle_rounded,
                                      color: Theme.of(context).hintColor,
                                    ),
                                  ),
                                )
                              : Container(),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 17.0,
                              vertical:
                                  9.0), // Offset by 1 to account for outline
                          child: Material(
                            type: MaterialType.transparency,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 600),
                                  opacity: isEditing ? 1.0 : 0.0,
                                  curve: isEditing
                                      ? const Interval(0.5, 1)
                                      : const Interval(0, 0.25),
                                  child: AnimatedSlide(
                                    duration: const Duration(milliseconds: 600),
                                    offset: isEditing
                                        ? Offset.zero
                                        : const Offset(0, 0.25),
                                    curve: isEditing
                                        ? const Interval(0.5, 1,
                                            curve: Curves.easeOutCubic)
                                        : const Interval(0, 0.5,
                                            curve: Curves.easeOutCubic),
                                    child: Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                          end: 8.0),
                                      child: IconButton(
                                        onPressed: () async {
                                          await ref
                                              .read(savedUserRouteProvider(
                                                      id: routeId)
                                                  .notifier)
                                              .removeBusStop(busStop);
                                        },
                                        icon: Icon(
                                          Icons.clear_rounded,
                                          color: Theme.of(context).hintColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        }
      case _:
        return const Center(child: CircularProgressIndicator());
    }
  }
}
