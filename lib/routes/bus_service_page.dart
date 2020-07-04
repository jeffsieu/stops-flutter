import 'package:flutter/material.dart';

import '../utils/bus_route.dart';
import '../utils/bus_service.dart';
import '../utils/bus_stop.dart';
import '../utils/database_utils.dart';
import '../utils/user_route.dart';
import 'bottom_sheet_page.dart';

class BusServicePage extends BottomSheetPage {
  BusServicePage(this.serviceNumber) : focusedBusStop = null;
  BusServicePage.withBusStop(this.serviceNumber, this.focusedBusStop);

  final String serviceNumber;
  final BusStop focusedBusStop;

  @override
  State<StatefulWidget> createState() {
    return _BusServicePageState();
  }
}

class _BusServicePageState extends BottomSheetPageState<BusServicePage> {
  BusService service;
  int focusedDirection = 0;

  @override
  void initState() {
    super.initState();
    initService();
  }

  Future<void> initService() async {
    final BusService service = await getCachedBusServiceWithNumber(widget.serviceNumber);
    service.routes ??= await getCachedBusRoutes(service);
    if (widget.focusedBusStop != null) {
      if (service.directionCount > 1)
        if (service.routes[1].busStops.contains(widget.focusedBusStop))
          focusedDirection = 1;
    }
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
    tabController.index = focusedDirection;
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
    ScrollController controller;
    if (widget.focusedBusStop != null) {
      final double index = route.busStops.indexOf(widget.focusedBusStop).toDouble();
      controller = ScrollController(initialScrollOffset: 56 * index);
    }
    else
      controller = ScrollController();
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ListView.builder(
        controller: controller,
        itemBuilder: (BuildContext context, int position) {
          final BusStop busStop = route.busStops[position];
          if (busStop == widget.focusedBusStop)
            return ListTile(
              title: Text('${busStop.defaultName}', style: Theme.of(context).textTheme.headline6.copyWith(color: Theme.of(context).accentColor)),
              subtitle: Text('${busStop.code}', style: Theme.of(context).textTheme.subtitle2.copyWith(color: Theme.of(context).accentColor)),
              leading: Text('${route.distances[position]}\nKM'),
              onTap: () => showBusDetailSheet(busStop, UserRoute.home),
            );
          return ListTile(
            title: Text('${busStop.defaultName}'),
            subtitle: Text('${busStop.code}'),
            leading: Text('${route.distances[position]}\nKM'),
            onTap: () => showBusDetailSheet(busStop, UserRoute.home),
          );
        },
        itemCount: route.busStops.length,
      ),
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