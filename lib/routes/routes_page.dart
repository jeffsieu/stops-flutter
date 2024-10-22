import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/routes/add_route_page.dart';
import 'package:stops_sg/routes/fade_page_route.dart';
import 'package:stops_sg/routes/route_page.dart';
import 'package:stops_sg/widgets/route_list.dart';
import 'package:stops_sg/widgets/route_list_item.dart';

class RoutesPage extends ConsumerStatefulWidget {
  const RoutesPage({super.key});

  @override
  ConsumerState<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends ConsumerState<RoutesPage> {
  StoredUserRoute? selectedRoute;

  @override
  Widget build(BuildContext context) {
    if (selectedRoute != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }
          setState(() {
            selectedRoute = null;
          });
        },
        child: RoutePage(route: selectedRoute!),
      );
    }

    return NotificationListener<RouteActionNotification>(
        onNotification: (RouteActionNotification notification) {
          if (notification.action == RouteAction.select) {
            _pushRoutePageRoute(context, notification.route);
            return true;
          }
          if (notification.action == RouteAction.edit) {
            _pushEditRouteRoute(context, ref, notification.route);
          }

          return false;
        },
        child: Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            heroTag: null,
            onPressed: () => _pushAddRouteRoute(context, ref),
            label: const Text('Add route'),
            icon: const Icon(Icons.add_rounded),
          ),
          body: const RouteList(),
        ));
  }

  Future<void> _pushAddRouteRoute(BuildContext context, WidgetRef ref) async {
    final Route<UserRoute> route =
        FadePageRoute<UserRoute>(child: const AddRoutePage());
    final userRoute = await Navigator.push(context, route);

    if (userRoute != null) {
      await ref.read(savedUserRoutesProvider.notifier).addRoute(userRoute);
    }
  }

  void _pushRoutePageRoute(BuildContext context, StoredUserRoute route) {
    setState(() {
      selectedRoute = route;
    });
  }

  Future<void> _pushEditRouteRoute(
      BuildContext context, WidgetRef ref, StoredUserRoute route) async {
    final editedRoute = await Navigator.push(context,
        FadePageRoute<StoredUserRoute>(child: AddRoutePage.edit(route)));
    if (editedRoute != null) {
      await ref.read(savedUserRoutesProvider.notifier).updateRoute(editedRoute);
    }
  }
}
