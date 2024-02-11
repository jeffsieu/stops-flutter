import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_route.dart';
import '../routes/add_route_page.dart';
import '../routes/fade_page_route.dart';
import '../utils/database_utils.dart';
import '../widgets/bus_stop_overview_list.dart';
import '../widgets/edit_model.dart';

class RoutePage extends StatefulWidget {
  const RoutePage(this.route, {super.key});
  final StoredUserRoute route;

  @override
  State createState() {
    return RoutePageState();
  }
}

class RoutePageState extends State<RoutePage> {
  // TODO: Let this page be the page to edit a route.
  // ignore: prefer_final_fields
  late StoredUserRoute route = widget.route;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Provider<StoredUserRoute>(
        create: (_) => widget.route,
        child: StreamBuilder<StoredUserRoute>(
          stream: routeStream(widget.route.id),
          builder:
              (BuildContext context, AsyncSnapshot<StoredUserRoute> snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.none:
              case ConnectionState.waiting:
                if (snapshot.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                continue done;
              done:
              case ConnectionState.active:
              case ConnectionState.done:
                if (snapshot.hasData &&
                    widget.route.busStops != snapshot.data!.busStops) {
                  widget.route.busStops
                    ..clear()
                    ..addAll(snapshot.data!.busStops);
                }
                return CustomScrollView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildHeader(),
                    ),
                    if (widget.route.busStops.isEmpty)
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
                          create: (_) => widget.route,
                          child: BusStopOverviewList(
                            routeId: widget.route.id,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
            }
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          IconButton(
            color: widget.route.color.of(context),
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Back to routes page',
          ),
          Container(width: 16.0),
          Expanded(
            child: Text(widget.route.name,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium!
                    .copyWith(color: widget.route.color.of(context))),
          ),
          IconButton(
            color: widget.route.color.of(context),
            icon: const Icon(Icons.edit),
            tooltip: 'Edit route',
            onPressed: () => _pushEditRouteRoute(),
          ),
        ],
      ),
    );
  }

  Future<void> _pushEditRouteRoute() async {
    final route = await Navigator.push(context,
        FadePageRoute<StoredUserRoute>(child: AddRoutePage.edit(widget.route)));
    if (route != null) {
      await updateUserRoute(route);
      setState(() {
        this.route = route;
      });
    }
  }
}
