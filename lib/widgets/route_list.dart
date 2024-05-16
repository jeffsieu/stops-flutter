import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models/user_route.dart';
import '../utils/database_utils.dart';
import '../utils/reorder_status_notification.dart';
import 'route_list_item.dart';

class RouteList extends ConsumerWidget {
  const RouteList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRoutes = ref.watch(customUserRoutesProvider);

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: userRoutes.when(data: (routes) {
        if (routes.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Text(
                  'No routes created.\n\nCreate a route to organize bus stops you go to frequently.',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium!
                      .copyWith(color: Theme.of(context).hintColor)),
            ),
          );
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.only(
              top: 8.0, bottom: kFloatingActionButtonMargin + 48),
          buildDefaultDragHandles: false,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: routes.length,
          onReorderStart: (int position) {
            ReorderStatusNotification(true).dispatch(context);
          },
          onReorder: (int oldIndex, int newIndex) async {
            await ref
                .read(savedUserRoutesProvider.notifier)
                .moveUserRoutePosition(oldIndex, newIndex);

            if (oldIndex < newIndex) {
              newIndex -= 1;
            }

            final newUserRoutes = List<StoredUserRoute>.from(routes);
            final route = newUserRoutes.removeAt(oldIndex);
            newUserRoutes.insert(newIndex, route);

            ReorderStatusNotification(false).dispatch(context);
          },
          itemBuilder: (BuildContext context, int position) {
            final userRoute = routes[position];

            return RouteListItem(
              key: ValueKey<StoredUserRoute>(userRoute),
              route: userRoute,
              index: position,
            );
          },
        );
      }, loading: () {
        return const Center(child: CircularProgressIndicator());
      }, error: (error, trace) {
        return Center(
          child: Text(
            'Error loading routes: $error',
            style: Theme.of(context)
                .textTheme
                .headlineMedium!
                .copyWith(color: Theme.of(context).hintColor),
          ),
        );
      }),
    );
  }
}
