import 'package:flutter/material.dart';

import '../models/user_route.dart';

class RouteModel extends InheritedWidget {
  const RouteModel({
    Key? key,
    required this.route,
    required Widget child,
  }) : super(key: key, child: child);

  final UserRoute route;

  static RouteModel? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<RouteModel>();
  }

  @override
  bool updateShouldNotify(RouteModel oldWidget) {
    return route != oldWidget.route;
  }
}
