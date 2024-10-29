import 'package:flutter/material.dart';

import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/database/models/user_route.dart';

class RouteListItem extends StatelessWidget {
  const RouteListItem({super.key, required this.route, required this.index});

  final StoredUserRoute route;
  final int index;

  @override
  Widget build(BuildContext context) {
    return ReorderableDelayedDragStartListener(
      index: index,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 24.0, right: 16.0),
        onTap: () {
          RouteActionNotification(route, RouteAction.select).dispatch(context);
        },
        leading: Container(
          width: 36.0,
          height: 36.0,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
            color: route.color.of(context),
          ),
        ),
        title: Text(route.name, style: Theme.of(context).textTheme.titleLarge),
        subtitle: route.busStops.isNotEmpty
            ? Text(
                route.busStops
                    .map<String>((BusStop busStop) => busStop.displayName)
                    .join(' > '),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall!
                    .copyWith(color: Theme.of(context).hintColor))
            : null,
        trailing: PopupMenuButton<RouteAction>(
          icon:
              Icon(Icons.more_vert_rounded, color: Theme.of(context).hintColor),
          tooltip: 'Route options',
          onSelected: (RouteAction action) {
            RouteActionNotification(route, action).dispatch(context);
          },
          itemBuilder: (BuildContext context) {
            return <PopupMenuItem<RouteAction>>[
              const PopupMenuItem<RouteAction>(
                  value: RouteAction.edit, child: Text('Edit')),
              const PopupMenuItem<RouteAction>(
                  value: RouteAction.delete, child: Text('Delete')),
            ];
          },
        ),
      ),
    );
  }
}

class RouteActionNotification extends Notification {
  const RouteActionNotification(this.route, this.action);
  final StoredUserRoute route;
  final RouteAction action;
}

enum RouteAction { select, delete, edit }
