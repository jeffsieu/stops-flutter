import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stops_sg/models/bus_service.dart';

import '../models/bus_service_route.dart';
import '../models/bus_service_with_routes.dart';
import '../models/bus_stop.dart';
import '../models/bus_stop_with_distance.dart';
import '../models/user_route.dart';
import '../utils/database_utils.dart';
import '../widgets/highlighted_icon.dart';
import 'bottom_sheet_page.dart';

class BusServicePage extends BottomSheetPage {
  BusServicePage(this.serviceNumber, {Key? key})
      : focusedBusStop = null,
        super(key: key);
  BusServicePage.withBusStop(this.serviceNumber, this.focusedBusStop,
      {Key? key})
      : super(key: key);

  final String serviceNumber;
  final BusStop? focusedBusStop;

  @override
  State<StatefulWidget> createState() {
    return _BusServicePageState();
  }
}

class _BusServicePageState extends BottomSheetPageState<BusServicePage> {
  BusServiceWithRoutes? service;
  int focusedDirection = 0;
//  ScrollController controller;

  @override
  void initState() {
    super.initState();
    initService();
  }

  Future<void> initService() async {
    final BusServiceWithRoutes service =
        await getCachedBusServiceWithRoutes(widget.serviceNumber);
    if (widget.focusedBusStop != null) {
      final BusServiceRoute focusedRoute = service.routes[0].busStops
              .map((BusStopWithDistance b) => b.busStop)
              .contains(widget.focusedBusStop)
          ? service.routes[0]
          : service.routes[1];
      focusedDirection = service.routes.indexOf(focusedRoute);

//      final double index = focusedRoute.busStops.indexOf(widget.focusedBusStop)
//          .toDouble();
//      controller = ScrollController(initialScrollOffset: 56 * index);
    }
    if (mounted) {
      setState(() {
        this.service = service;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    buildSheet(hasAppBar: false);
    final TabController tabController = TabController(length: 2, vsync: this);
    final Widget bottomSheetContainer =
        bottomSheet(child: _buildBody(tabController));

    tabController.index = focusedDirection;

    return Scaffold(
      body: bottomSheetContainer,
    );
  }

  Widget _buildBody(TabController tabController) {
    return NestedScrollView(
//      controller: controller,
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return <Widget>[
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: SliverAppBar(
              elevation: 4.0,
              forceElevated: true,
              expandedHeight: 128.0 + kTextTabBarHeight,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(
                    left: 72,
                    bottom: (service?.directionCount ?? 0) > 1
                        ? kTextTabBarHeight
                        : 16.0),
                title: Text(widget.serviceNumber),
                collapseMode: CollapseMode.pin,
              ),
              bottom: (service?.directionCount ?? 0) > 1
                  ? TabBar(
                      controller: tabController,
                      tabs: <Widget>[
                        Tab(
                          text: 'To ${service!.destinations[0].defaultName}',
                        ),
                        Tab(
                          text: 'To ${service!.destinations[1].defaultName}',
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        ];
      },
      body: service != null
          ? (service!.directionCount == 1
              ? _buildRouteBusStops(service!.routes[0])
              : _buildPageView(service!, tabController))
          : (const Center(child: CircularProgressIndicator())),
    );
  }

  Widget _buildRouteBusStops(BusServiceRoute route) {
    final Color focusedColor = Theme.of(context).highlightColor;

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Builder(
        builder: (BuildContext context) {
          return CustomScrollView(
            slivers: <Widget>[
              SliverOverlapInjector(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int position) {
                    final BusStopWithDistance busStopWithDistance =
                        route.busStops[position];
                    final BusStop busStop = busStopWithDistance.busStop;
                    final double distance = busStopWithDistance.distance;
                    final String previousRoad = position > 0
                        ? route.busStops[position - 1].busStop.road
                        : '';
                    final bool newRoad = busStop.road != previousRoad;
                    return Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: Row(
                            children: <Widget>[
                              Container(
                                margin: position == 0
                                    ? const EdgeInsets.only(
                                        left: 36.0, top: 72.0)
                                    : position < route.busStops.length - 1
                                        ? const EdgeInsets.only(left: 36.0)
                                        : const EdgeInsets.only(
                                            left: 36.0, bottom: 8.0),
                                child: Container(
                                  color: Theme.of(context).hintColor,
                                  width: 8.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (newRoad)
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 88.0, top: 24.0, bottom: 8.0),
                                child: Text(busStop.road,
                                    style:
                                        Theme.of(context).textTheme.headline4),
                              ),
                            Material(
                              color: busStop == widget.focusedBusStop
                                  ? focusedColor
                                  : Colors.transparent,
                              child: InkWell(
                                onTap: () =>
                                    showBusDetailSheet(busStop, UserRoute.home),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  title: Text(busStop.defaultName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headline6),
                                  subtitle: Text(busStop.code,
                                      style: Theme.of(context)
                                          .textTheme
                                          .subtitle2!
                                          .copyWith(
                                              color:
                                                  Theme.of(context).hintColor)),
                                  leading: Ink(
                                    color: Color.alphaBlend(
                                        busStop == widget.focusedBusStop
                                            ? focusedColor
                                            : Colors.transparent,
                                        Theme.of(context)
                                            .scaffoldBackgroundColor),
                                    width: 64.0,
                                    height: 72.0,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: <Widget>[
                                        HighlightedIcon(
                                          iconColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          child: SvgPicture.asset(
                                            'assets/images/bus-stop.svg',
                                            width: 24.0,
                                            height: 24.0,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '$distance km',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .subtitle2!
                                                  .copyWith(
                                                      color: Theme.of(context)
                                                          .hintColor),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                  childCount: route.busStops.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPageView(
      BusServiceWithRoutes service, TabController tabController) {
    return TabBarView(
      controller: tabController,
      children: <Widget>[
        _buildRouteBusStops(service.routes[0]),
        _buildRouteBusStops(service.routes[1]),
      ],
    );
  }
}
