import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:provider/provider.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/utils/reorder_status_notification.dart';
import 'package:stops_sg/widgets/edit_model.dart';
import 'package:stops_sg/widgets/reorderable_bus_stop_list.dart';

class BusStopOverviewList extends ConsumerWidget {
  const BusStopOverviewList(
      {super.key, required this.routeId, required this.emptyView});

  final int routeId;
  final Widget emptyView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = context.watch<EditModel>().isEditing;
    final route = ref.watch(savedUserRouteProvider(id: routeId)).value;

    if (route == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final busStops = route.busStops;

    if (busStops.isEmpty) {
      return emptyView;
    }

    return Provider<StoredUserRoute>(
      create: (_) => route,
      child: ReorderableBusStopList(
          busStops: busStops,
          isEditing: isEditing,
          onReorderStart: (int position) {
            ReorderStatusNotification(true).dispatch(context);
          },
          onReorderEnd: (position) =>
              ReorderStatusNotification(false).dispatch(context),
          onReorder: (int oldIndex, int newIndex) async {
            ReorderStatusNotification(false).dispatch(context);

            await ref
                .read(savedUserRouteProvider(id: routeId).notifier)
                .moveBusStop(oldIndex, newIndex);
          },
          onBusStopRemoved: (BusStop busStop) async {
            await ref
                .read(savedUserRouteProvider(id: routeId).notifier)
                .removeBusStop(busStop);
          }),
    );
  }
}
