import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:provider/provider.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/routes/add_route_page.dart';
import 'package:stops_sg/routes/fade_page_route.dart';
import 'package:stops_sg/widgets/bus_stop_overview_list.dart';
import 'package:stops_sg/widgets/edit_model.dart';

class RoutePage extends ConsumerWidget {
  const RoutePage({super.key, required this.route});
  final StoredUserRoute route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latestRoute = ref.watch(savedUserRouteProvider(id: route.id));

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: switch (latestRoute) {
        AsyncData(:final value) => value != null
            ? CustomScrollView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(context, ref),
                  ),
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

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          IconButton(
            color: route.color.of(context),
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Back to routes page',
          ),
          Container(width: 16.0),
          Expanded(
            child: Text(route.name,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium!
                    .copyWith(color: route.color.of(context))),
          ),
          IconButton(
            color: route.color.of(context),
            icon: const Icon(Icons.edit),
            tooltip: 'Edit route',
            onPressed: () => _pushEditRouteRoute(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _pushEditRouteRoute(BuildContext context, WidgetRef ref) async {
    final newRoute = await Navigator.push(context,
        FadePageRoute<StoredUserRoute>(child: AddRoutePage.edit(route)));
    if (newRoute != null) {
      await ref.read(savedUserRoutesProvider.notifier).updateRoute(newRoute);
    }
  }
}
