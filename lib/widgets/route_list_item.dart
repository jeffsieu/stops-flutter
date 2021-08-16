// @dart=2.9

import 'package:flutter/material.dart';

import '../models/bus_stop.dart';
import '../models/user_route.dart';
import 'custom_handle.dart';

class RouteListItem extends StatelessWidget {
  const RouteListItem(this.route);

  final UserRoute route;

  @override
  Widget build(BuildContext context) {
    return CustomHandle(
      delay: const Duration(milliseconds: 500),
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
        title: Text(route.name, style: Theme.of(context).textTheme.headline6),
        subtitle: Text(route.busStops.map<String>((BusStop busStop) => busStop.displayName).join(' > '), style: Theme.of(context).textTheme.subtitle2.copyWith(color: Theme.of(context).hintColor)),
        trailing: PopupMenuButton<RouteAction>(
          icon: Icon(Icons.more_vert, color: Theme.of(context).hintColor),
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
