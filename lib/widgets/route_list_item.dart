import 'package:flutter/material.dart';

import '../utils/bus_stop.dart';
import '../utils/user_route.dart';
import 'custom_handle.dart';

class RouteListItem extends StatelessWidget {
  const RouteListItem(this.route);

  final UserRoute route;

  @override
  Widget build(BuildContext context) {
    return CustomHandle(
      delay: const Duration(milliseconds: 500),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16.0, right: 8.0),
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
        title: Text(route.name, style: Theme.of(context).textTheme.title),
        subtitle: Text(route.busStops.map<String>((BusStop busStop) => busStop.displayName).join(' > '), style: Theme.of(context).textTheme.subtitle.copyWith(color: Theme.of(context).hintColor)),
        trailing: PopupMenuButton<RouteAction>(
          tooltip: 'Route options',
          onSelected: (RouteAction action) {
            RouteActionNotification(route, action).dispatch(context);
          },
          itemBuilder: (BuildContext context) {
            return <PopupMenuItem<RouteAction>>[
              const PopupMenuItem<RouteAction>(child: Text('Edit'), value: RouteAction.edit),
              const PopupMenuItem<RouteAction>(child: Text('Delete'), value: RouteAction.delete),
            ];
          },
        ),
      ),
    );
  }
}

class RouteActionNotification extends Notification {
  const RouteActionNotification(this.route, this.action);
  final UserRoute route;
  final RouteAction action;
}

enum RouteAction {
  select, delete, edit
}
