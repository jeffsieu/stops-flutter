import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:provider/provider.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/routes/edit_route_route.dart';
import 'package:stops_sg/routes/routes.dart';
import 'package:stops_sg/widgets/bus_stop_overview_list.dart';
import 'package:stops_sg/widgets/edit_model.dart';

class RoutePage extends ConsumerWidget {
  const RoutePage({super.key, required this.route});
  final StoredUserRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestRoute = ref.watch(savedUserRouteProvider(id: route.id));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.transparent,
        title: Text(latestRoute.valueOrNull?.name ?? 'Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit route',
            onPressed: () => _pushEditRouteRoute(context, ref),
          ),
        ],
      ),
      body: switch (latestRoute) {
        AsyncData(:final value) => value != null
            ? CustomScrollView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                slivers: [
                  if (value.busStops.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Text(
                              'This route has no stops.\n\nTap the edit icon to add stops to this route.',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium!
                                  .copyWith(
                                      color: Theme.of(context).hintColor)),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Provider<EditModel>(
                      create: (_) => const EditModel(isEditing: false),
                      child: Provider<StoredUserRoute>(
                        create: (_) => value,
                        child: BusStopOverviewList(
                          routeId: value.id,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : const Center(child: Text('Error: route missing')),
        AsyncError(:final error) => Center(
            child: Text('Error in fetching route: $error'),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _pushEditRouteRoute(BuildContext context, WidgetRef ref) async {
    final newRoute =
        await EditRouteRoute(routeId: route.id).push<StoredUserRoute>(context);
    if (newRoute != null) {
      await ref.read(savedUserRoutesProvider.notifier).updateRoute(newRoute);
    }
  }
}
