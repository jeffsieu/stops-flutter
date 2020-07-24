import 'dart:math';

import 'package:flutter/material.dart';

import '../models/bus_stop.dart';
import '../models/user_route.dart';
import '../routes/add_route_page.dart';
import '../routes/fade_page_route.dart';
import '../utils/database_utils.dart';
import '../widgets/bus_stop_overview_item.dart';
import '../widgets/route_model.dart';

class RoutePage extends StatefulWidget {
  const RoutePage(this.route);
  final UserRoute route;

  @override
  State createState() {
    return RoutePageState();
  }
}

class RoutePageState extends State<RoutePage> {
  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: RouteModel(
        route: widget.route,
        child: StreamBuilder<List<BusStop>>(
          initialData: widget.route.busStops,
          stream: routeBusStopsStream(widget.route),
          builder: (BuildContext context, AsyncSnapshot<List<BusStop>> snapshot) {
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
                if (snapshot.hasData && widget.route.busStops != snapshot.data) {
                  widget.route.busStops..clear()..addAll(snapshot.data);
                }
                return CustomScrollView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: _buildHeader(),
                    ),
                    if (widget.route.busStops == null || widget.route.busStops.isEmpty)
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: Text('This route has no stops.\n\nTap the edit icon to add stops to this route.', style: Theme.of(context).textTheme.headline4.copyWith(color: Theme.of(context).hintColor)),
                          ),
                        ),
                      ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int position) {
                          final bool isDivider = position % 2 == 1;
                          if (isDivider)
                            return const Divider(height: 1);
                          final int itemPosition = position ~/ 2;
                          final BusStop busStop = widget.route.busStops[itemPosition];
                          return BusStopOverviewItem(busStop, key: Key(busStop.code));
                        },
                        childCount: widget.route.busStops.length + max(0, widget.route.busStops.length - 1),
                      ),
                    ),
                  ],
                );
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: <Widget>[
          IconButton(
            color: widget.route.color.of(context),
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Back to routes page',
          ),
          Container(width: 16.0),
          Expanded(
            child: Text(widget.route.name,
                style: Theme.of(context).textTheme.headline4
                    .copyWith(color: widget.route.color.of(context))
            ),
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
    final UserRoute route = await Navigator.push(context, FadePageRoute<UserRoute>(child: AddRoutePage.edit(widget.route)));
    if (route != null) {
      widget.route.update(route);
      await updateUserRoute(route);
      setState(() {});
    }
  }
}