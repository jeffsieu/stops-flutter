// @dart=2.9

import 'package:flutter/material.dart';

import 'package:implicitly_animated_reorderable_list/implicitly_animated_reorderable_list.dart';
import 'package:implicitly_animated_reorderable_list/transitions.dart';

import '../models/user_route.dart';
import '../utils/database_utils.dart';
import '../utils/reorder_status_notification.dart';
import 'route_list_item.dart';

class RouteList extends StatefulWidget {
  @override
  State createState() {
    return RouteListState();
  }
}

class RouteListState extends State<RouteList> {
  List<UserRoute> _routes;

  @override
  void initState() {
    super.initState();
    _routes = <UserRoute>[];
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: FutureBuilder<List<UserRoute>>(
        future: getUserRoutes(),
        initialData: _routes,
        builder: (BuildContext context, AsyncSnapshot<List<UserRoute>> snapshot) {
          if (!snapshot.hasData || (snapshot.data == _routes && snapshot.data.isEmpty))
            return const Center(child: CircularProgressIndicator());

          // Only update list when database is updated, otherwise the list is updated with old positions
          if (snapshot.connectionState == ConnectionState.done) {
            _routes..clear()..addAll(snapshot.data);
          }

          if (_routes.isEmpty)
            return Container(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Text('No routes created.\n\nCreate a route to organize bus stops you go to frequently.', style: Theme.of(context).textTheme.headline4.copyWith(color: Theme.of(context).hintColor)),
              ),
            );

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
            child: ImplicitlyAnimatedReorderableList<UserRoute>(
              padding: const EdgeInsets.only(top: 8.0, bottom: kFloatingActionButtonMargin + 48),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              items: _routes,
              areItemsTheSame: (UserRoute oldUserRoute, UserRoute newUserRoute) => oldUserRoute == newUserRoute,
              onReorderStarted: (UserRoute item, int position) {
                ReorderStatusNotification(true).dispatch(context);
              },
              onReorderFinished: (UserRoute item, int from, int to, List<UserRoute> newUserRoutes) async {
                await moveUserRoutePosition(from, to);
                ReorderStatusNotification(false).dispatch(context);
                setState(() {
                  _routes..clear()..addAll(newUserRoutes);
                });
              },
              itemBuilder: (BuildContext context, Animation<double> itemAnimation, UserRoute userRoute, int position) {
                return Reorderable(
                  key: ValueKey<UserRoute>(userRoute),
                  builder: (BuildContext context, Animation<double> dragAnimation, bool inDrag) {
                    const double initialElevation = 0.0;
                    final Color materialColor = Color.lerp(Theme.of(context).scaffoldBackgroundColor, Colors.white, dragAnimation.value / 10);
                    final double elevation = Tween<double>(begin: initialElevation, end: 10.0).animate(CurvedAnimation(parent: dragAnimation, curve: Curves.easeOutCubic)).value;

                    final Widget child = Material(
                      color: materialColor,
                      elevation: elevation,
                      child: RouteListItem(userRoute),
                    );

                    if (dragAnimation.value > 0.0)
                      return child;

                    return SizeFadeTransition(
                      sizeFraction: 0.75,
                      curve: Curves.easeInOut,
                      animation: itemAnimation,
                      child: child,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
