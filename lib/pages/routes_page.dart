import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/pages/route_page.dart';
import 'package:stops_sg/routes/add_route_route.dart';
import 'package:stops_sg/routes/edit_route_route.dart';
import 'package:stops_sg/routes/route_detail_route.dart';
import 'package:stops_sg/routes/routes.dart';
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
        child: RoutePage(routeId: selectedRoute!.id),
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
          if (notification.action == RouteAction.delete) {
            ref
                .read(savedUserRoutesProvider.notifier)
                .deleteRoute(notification.route);
          }

          return false;
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Routes'),
          ),
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
    final userRoute = await AddRouteRoute().push<UserRoute>(context);

    if (userRoute != null) {
      await ref.read(savedUserRoutesProvider.notifier).addRoute(userRoute);
    }
  }

  void _pushRoutePageRoute(BuildContext context, StoredUserRoute route) {
    RouteDetailRoute(routeId: route.id).push(context);
  }

  Future<void> _pushEditRouteRoute(
      BuildContext context, WidgetRef ref, StoredUserRoute route) async {
    final editedRoute =
        await EditRouteRoute(routeId: route.id).push<StoredUserRoute>(context);
    if (editedRoute != null) {
      await ref.read(savedUserRoutesProvider.notifier).updateRoute(editedRoute);
    }
  }
}
