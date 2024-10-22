import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:stops_sg/bus_api/models/bus_service_route.dart';
import 'package:stops_sg/bus_api/models/bus_service_with_routes.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/widgets/bus_stop_overview_item.dart';
import 'package:stops_sg/widgets/edit_model.dart';

class BusServicePage extends HookConsumerWidget {
  const BusServicePage(this.serviceNumber, {super.key}) : focusedBusStop = null;
  const BusServicePage.withBusStop(this.serviceNumber, this.focusedBusStop,
      {super.key});

  final String serviceNumber;
  final BusStop? focusedBusStop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabController = useTabController(initialLength: 2);

    final homeRoute =
        ref.watch(savedUserRouteProvider(id: kDefaultRouteId)).valueOrNull;

    return Scaffold(
      body: provider.MultiProvider(
        providers: [
          provider.Provider(
            create: (_) => const EditModel(isEditing: false),
          ),
          provider.Provider<StoredUserRoute?>(
            create: (_) => homeRoute,
          ),
        ],
        child: _buildBody(context, ref, tabController),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, TabController tabController) {
    final service =
        ref.watch(cachedBusServiceWithRoutesProvider(serviceNumber));

    final focusedRoute = useMemoized(() {
      final serviceValue = service.valueOrNull;

      if (focusedBusStop == null || serviceValue == null) {
        return null;
      }

      return serviceValue.routes[0].busStops.reversed
              .skip(1)
              .map((b) => b.busStop)
              .contains(focusedBusStop)
          ? serviceValue.routes[0]
          : serviceValue.routes[1];
    }, [service, focusedBusStop]);

    useEffect(() {
      if (service.value == null || focusedRoute == null) {
        return;
      }

      final focusedDirection = service.value!.routes.indexOf(focusedRoute);

      tabController.index = focusedDirection;
    }, [service, focusedRoute]);

    return switch (service) {
      AsyncData(:final value) => NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            final hasTabBar = value.directionCount > 1;

            return [
              SliverOverlapAbsorber(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
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
                        child: Text(serviceNumber,
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
                              text: 'To ${value.destinations[0].defaultName}',
                            ),
                            Tab(
                              text: 'To ${value.destinations[1].defaultName}',
                            ),
                          ],
                        )
                      : null,
                ),
              ),
            ];
          },
          body: (value.directionCount == 1
              ? _buildRouteBusStops(context, value.routes[0])
              : _buildPageView(context, value, tabController)),
        ),
      AsyncError(:final error) => Text('Unable to fetch bus service: $error'),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _buildRouteBusStops(BuildContext context, BusServiceRoute route) {
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
                delegate: SliverChildBuilderDelegate((routeBusStop, position) {
                  final routeBusStop = route.busStops[position];
                  final busStop = routeBusStop.busStop;
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
                                  ? const EdgeInsetsDirectional.only(
                                      start: 44.0, top: 72.0)
                                  : position < route.busStops.length - 1
                                      ? const EdgeInsetsDirectional.only(
                                          start: 44.0)
                                      : const EdgeInsetsDirectional.only(
                                          start: 44.0, bottom: 8.0),
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
                              padding: const EdgeInsetsDirectional.only(
                                  start: 72.0, top: 24.0, bottom: 8.0),
                              child: Text(busStop.road,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium),
                            ),
                          Material(
                            color: busStop == focusedBusStop
                                ? focusedColor
                                : Colors.transparent,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: BusStopOverviewItem(
                                busStop,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPageView(BuildContext context, BusServiceWithRoutes service,
      TabController tabController) {
    return TabBarView(
      controller: tabController,
      children: [
        _buildRouteBusStops(context, service.routes[0]),
        _buildRouteBusStops(context, service.routes[1]),
      ],
    );
  }
}
