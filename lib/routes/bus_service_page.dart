import 'package:flutter/material.dart';

import '../utils/bus_route.dart';
import '../utils/bus_service.dart';
import '../utils/bus_stop.dart';
import 'bottom_sheet_page.dart';

class BusServicePage extends BottomSheetPage {
  BusServicePage(this.service);

  final BusService service;

  @override
  State<StatefulWidget> createState() {
    return _BusServicePageState();
  }
}

class _BusServicePageState extends BottomSheetPageState<BusServicePage> {
  @override
  Widget build(BuildContext context) {
    final TabController tabController = TabController(length: 2, vsync: this);

    final Widget child = widget.service.routes[0].busStops != null ? NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return <Widget>[
          SliverAppBar(
            pinned: true,
            title: Text('${widget.service.number}'),
            bottom: widget.service.directionCount > 1 ? TabBar(
              controller: tabController,
              tabs: <Widget>[
                Tab(
                  text: 'To ${widget.service.destination[0].defaultName}',
                ),
                Tab(
                  text: 'To ${widget.service.destination[1].defaultName}',
                ),
              ],
            ) : null,
          ),
        ];
      },
      body: widget.service.directionCount == 1 ?
      _buildRouteBusStops(widget.service.routes[0]) :
      _buildPageView(widget.service, tabController),
    ) : const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: Container(
        child: child,
      ),
    );
  }

  Widget _buildRouteBusStops(BusServiceRoute route) {
    return ListView.builder(
      itemBuilder: (BuildContext context, int position) {
        final BusStop busStop = route.busStops[position];
        return ListTile(
          title: Text('${busStop.defaultName}'),
          subtitle: Text('${busStop.code}'),
          leading: Text('${route.distances[position]}\nKM'),
          onTap: () => showBusDetailSheet(busStop),
        );
      },
      itemCount: route.busStops.length,
    );
  }

  Widget _buildPageView(BusService service, TabController tabController) {
    return TabBarView(
      controller: tabController,
      children: <Widget>[
        _buildRouteBusStops(service.routes[0]),
        _buildRouteBusStops(service.routes[1]),
      ],
    );
  }
}