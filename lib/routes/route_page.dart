import 'package:flutter/material.dart';

import '../routes/add_route_page.dart';
import '../routes/fade_page_route.dart';
import '../utils/bus_stop.dart';
import '../utils/database_utils.dart';
import '../utils/user_route.dart';
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
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (BuildContext context, int position) {
            if (position == 0)
              return _buildHeader();
            final BusStop busStop = widget.route.busStops[position - 1];
            return BusStopOverviewItem(busStop, key: Key(busStop.code));
          },
          itemCount: widget.route.busStops.length + 1,
          separatorBuilder: (BuildContext context, int position) => position > 0 ? const Divider(height: 1) : Container(),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(8.0),
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
      updateUserRoute(route);
      setState(() {
        widget.route.update(route);
      });
    }
  }
}