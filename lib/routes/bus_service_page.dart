import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:stops_sg/bus_api/models/bus_service_route.dart';
import 'package:stops_sg/bus_api/models/bus_service_with_routes.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/bus_api/models/bus_stop_with_distance.dart';
import 'package:stops_sg/bus_stop_sheet/bloc/bus_stop_sheet_bloc.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/routes/bottom_sheet_page.dart';
import 'package:stops_sg/widgets/highlighted_icon.dart';

class BusServicePage extends BottomSheetPage {
  const BusServicePage(this.serviceNumber, {super.key}) : focusedBusStop = null;
  const BusServicePage.withBusStop(this.serviceNumber, this.focusedBusStop,
      {super.key});

  final String serviceNumber;
  final BusStop? focusedBusStop;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() {
    return _BusServicePageState();
  }
}

class _BusServicePageState extends BottomSheetPageState<BusServicePage> {
  _BusServicePageState() : super(hasAppBar: false);

  BusServiceWithRoutes? service;
  int focusedDirection = 0;
//  ScrollController controller;

  @override
  void initState() {
    super.initState();
    initService();
  }

  Future<void> initService() async {
    final service = await getCachedBusServiceWithRoutes(widget.serviceNumber);
    if (widget.focusedBusStop != null) {
      final focusedRoute = service.routes[0].busStops
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
    final tabController = TabController(length: 2, vsync: this);
    final bottomSheetContainer = bottomSheet(child: _buildBody(tabController));

    tabController.index = focusedDirection;

    return Scaffold(
      body: bottomSheetContainer,
    );
  }

  Widget _buildBody(TabController tabController) {
    return NestedScrollView(
//      controller: controller,
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        final hasTabBar = (service?.directionCount ?? 0) > 1;
        return [
          SliverOverlapAbsorber(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            sliver: SliverAppBar(
              elevation: 4.0,
              forceElevated: true,
              expandedHeight: 128.0 + kTextTabBarHeight,
              collapsedHeight: kToolbarHeight,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(
                    left: 72, bottom: hasTabBar ? kTextTabBarHeight : 0),
                title: SizedBox(
                  height: kToolbarHeight,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(widget.serviceNumber,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                ),
                collapseMode: CollapseMode.pin,
              ),
              bottom: hasTabBar
                  ? TabBar(
                      controller: tabController,
                      tabs: [
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
    final focusedColor = Theme.of(context).highlightColor;

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: Builder(
        builder: (BuildContext context) {
          return CustomScrollView(
            slivers: [
              SliverOverlapInjector(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int position) {
                    final busStopWithDistance = route.busStops[position];
                    final busStop = busStopWithDistance.busStop;
                    final distance = busStopWithDistance.distance;
                    final previousRoad = position > 0
                        ? route.busStops[position - 1].busStop.road
                        : '';
                    final newRoad = busStop.road != previousRoad;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Row(
                            children: [
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
                          children: [
                            if (newRoad)
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 88.0, top: 24.0, bottom: 8.0),
                                child: Text(busStop.road,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                              ),
                            Material(
                              color: busStop == widget.focusedBusStop
                                  ? focusedColor
                                  : Colors.transparent,
                              child: InkWell(
                                onTap: () => context
                                    .read<BusStopSheetBloc>()
                                    .add(SheetRequested(
                                        busStop, kDefaultRouteId)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  title: Text(busStop.defaultName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  subtitle: Text(busStop.code,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall!
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
                                      children: [
                                        HighlightedIcon(
                                          iconColor: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          child: SvgPicture.asset(
                                            'assets/images/bus-stop.svg',
                                            width: 24.0,
                                            height: 24.0,
                                            colorFilter: ColorFilter.mode(
                                                Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                BlendMode.srcIn),
                                          ),
                                        ),
                                        Flexible(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '$distance km',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall!
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
      children: [
        _buildRouteBusStops(service.routes[0]),
        _buildRouteBusStops(service.routes[1]),
      ],
    );
  }
}
