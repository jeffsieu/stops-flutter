import 'package:flutter/material.dart';
import 'package:stops_sg/utils/database_utils.dart';

import '../utils/bus_route.dart';
import '../utils/bus_service.dart';
import '../utils/bus_stop.dart';
import 'bottom_sheet_page.dart';

class BusServicePage extends BottomSheetPage {
  BusServicePage(this.serviceNumber);

  final String serviceNumber;

  @override
  State<StatefulWidget> createState() {
    return _BusServicePageState();
  }
}

class _BusServicePageState extends BottomSheetPageState<BusServicePage> {
  BusService service;
  @override
  void initState() {
    super.initState();
    initService();
  }

  Future<void> initService() async {
    final BusService service = await getCachedBusServiceWithNumber(widget.serviceNumber);
    service.routes ??= await getCachedBusRoutes(service);
    setState(() {
      this.service = service;
    });
  }

  @override
  Widget build(BuildContext context) {
    buildSheet(hasAppBar: false);
    final Widget bottomSheetContainer = bottomSheet(child: _buildBody());

    return Scaffold(
      body: bottomSheetContainer,
    );
  }

  Widget _buildBody() {
    final TabController tabController = TabController(length: 2, vsync: this);
    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return <Widget>[
          SliverAppBar(
            pinned: true,
            title: Text(widget.serviceNumber),
            bottom: (service?.directionCount ?? 0) > 1 ? TabBar(
              controller: tabController,
              tabs: <Widget>[
                Tab(
                  text: 'To ${service.destination[0].defaultName}',
                ),
                Tab(
                  text: 'To ${service.destination[1].defaultName}',
                ),
              ],
            ) : null,
          ),
        ];
      },
      body: service != null ? (
          service.directionCount == 1 ?
            _buildRouteBusStops(service.routes[0])
          :
            _buildPageView(service, tabController)
      ) : (
          const Center(child: CircularProgressIndicator())
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