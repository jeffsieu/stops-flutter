import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:provider/provider.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/routes/edit_route_route.dart';
import 'package:stops_sg/routes/routes.dart';
import 'package:stops_sg/widgets/edit_model.dart';
import 'package:stops_sg/widgets/route_bus_stop_list.dart';

class RoutePage extends ConsumerWidget {
  const RoutePage({super.key, required this.routeId});
  final int routeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestRoute = ref.watch(savedUserRouteProvider(id: routeId));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.transparent,
        title: Text(latestRoute.value?.name ?? 'Route'),
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
                  SliverToBoxAdapter(
                    child: Provider<EditModel>(
                      create: (_) => const EditModel(isEditing: false),
                      child: Provider<StoredUserRoute>(
                        create: (_) => value,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: RouteBusStopList(
                            routeId: value.id,
                            defaultExpanded: true,
                            emptyView: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 32.0),
                              child: Text(
                                  'This route has no bus stops.\n\nTap the edit icon to add bus stops to this route.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium!
                                      .copyWith(
                                          color: Theme.of(context).hintColor)),
                            ),
                          ),
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
        await EditRouteRoute(routeId: routeId).push<StoredUserRoute>(context);
    if (newRoute != null) {
      await ref.read(savedUserRoutesProvider.notifier).updateRoute(newRoute);
    }
  }
}
