import 'package:flutter/material.dart';

import '../models/user_route.dart';
import '../utils/database_utils.dart';
import '../utils/reorder_status_notification.dart';
import 'route_list_item.dart';

class RouteList extends StatefulWidget {
  const RouteList({super.key});

  @override
  State createState() {
    return RouteListState();
  }
}

class RouteListState extends State<RouteList> {
  final List<StoredUserRoute> _routes = <StoredUserRoute>[];

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: FutureBuilder<List<StoredUserRoute>>(
        future: getUserRoutes(),
        initialData: _routes,
        builder: (BuildContext context,
            AsyncSnapshot<List<StoredUserRoute>> snapshot) {
          if (!snapshot.hasData ||
              (snapshot.data == _routes && snapshot.data!.isEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }

          // Only update list when database is updated, otherwise the list is updated with old positions
          if (snapshot.connectionState == ConnectionState.done) {
            _routes
              ..clear()
              ..addAll(snapshot.data!);
          }

          if (_routes.isEmpty) {
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

          return NotificationListener<RouteActionNotification>(
            onNotification: (RouteActionNotification notification) {
              if (notification.action == RouteAction.delete) {
                deleteUserRoute(notification.route).then((_) {
                  setState(() {
                    _routes.remove(notification.route);
                  });
                });
                return true;
              }
              return false;
            },
            child: ReorderableListView.builder(
              padding: const EdgeInsets.only(
                  top: 8.0, bottom: kFloatingActionButtonMargin + 48),
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _routes.length,
              onReorderStart: (int position) {
                ReorderStatusNotification(true).dispatch(context);
              },
              onReorder: (int oldIndex, int newIndex) async {
                await moveUserRoutePosition(oldIndex, newIndex);

                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }

                final newUserRoutes = List<StoredUserRoute>.from(_routes);
                final route = newUserRoutes.removeAt(oldIndex);
                newUserRoutes.insert(newIndex, route);

                ReorderStatusNotification(false).dispatch(context);
                setState(() {
                  _routes
                    ..clear()
                    ..addAll(newUserRoutes);
                });
              },
              itemBuilder: (BuildContext context, int position) {
                final userRoute = _routes[position];

                return RouteListItem(
                  key: ValueKey<StoredUserRoute>(userRoute),
                  route: userRoute,
                  index: position,
                );
              },
            ),
          );
        },
      ),
    );
  }
}
