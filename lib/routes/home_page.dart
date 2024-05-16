import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:location/location.dart';
import 'package:provider/provider.dart' hide Consumer;
import 'package:quick_actions/quick_actions.dart';
import 'package:shimmer/shimmer.dart';
import 'package:stops_sg/bus_api/bus_api.dart';
import 'package:stops_sg/bus_api/models/bus.dart';
import 'package:stops_sg/bus_api/models/bus_stop_with_distance.dart';
import 'package:stops_sg/bus_stop_sheet/bloc/bus_stop_sheet_bloc.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/location/location.dart';
import 'package:stops_sg/main.dart';
import 'package:stops_sg/routes/add_route_page.dart';
import 'package:stops_sg/routes/bottom_sheet_page.dart';
import 'package:stops_sg/routes/fade_page_route.dart';
import 'package:stops_sg/routes/fetch_data_page.dart';
import 'package:stops_sg/routes/route_page.dart';
import 'package:stops_sg/routes/scan_card_page.dart';
import 'package:stops_sg/routes/search_page.dart';
import 'package:stops_sg/routes/settings_page.dart';
import 'package:stops_sg/utils/database/followed_buses.dart';
import 'package:stops_sg/utils/reorder_status_notification.dart';
import 'package:stops_sg/utils/time_utils.dart';
import 'package:stops_sg/widgets/bus_stop_overview_list.dart';
import 'package:stops_sg/widgets/card_app_bar.dart';
import 'package:stops_sg/widgets/crossed_icon.dart';
import 'package:stops_sg/widgets/edit_model.dart';
import 'package:stops_sg/widgets/home_page_content_switcher.dart';
import 'package:stops_sg/widgets/never_focus_node.dart';
import 'package:stops_sg/widgets/outline_titled_container.dart';
import 'package:stops_sg/widgets/route_list.dart';
import 'package:stops_sg/widgets/route_list_item.dart';

const Duration _minimumRefreshDuration = Duration(milliseconds: 300);

class HomePage extends BottomSheetPage {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();

  static HomePageState? of(BuildContext context) =>
      context.findAncestorStateOfType<HomePageState>();
}

class HomePageState extends BottomSheetPageState<HomePage> {
  HomePageState() : super(hasAppBar: false);

  int _bottomNavIndex = 0;
  int _suggestionsCount = 1;
  bool _isEditing = false;
  List<Bus> get _followedBuses =>
      ref.watch(followedBusesProvider).valueOrNull ?? [];
  final ScrollController _scrollController = ScrollController();
  bool canScroll = true;
  late final AnimationController _fabScaleAnimationController =
      AnimationController(
          vsync: this, duration: HomePageContentSwitcher.animationDuration);
  final TextEditingController _busServiceTextController =
      TextEditingController();
  String get _busServiceFilterText => _busServiceTextController.text;
  StoredUserRoute? _activeRoute;
  bool get hasLocationPermissions => ref.watch(userLocationProvider
      .select((value) => value.valueOrNull?.hasPermission ?? false));
  LocationData? get locationData => ref
      .watch(userLocationProvider.select((value) => value.valueOrNull?.data));
  AsyncValue<List<BusStopWithDistance>?> get _nearestBusStops =>
      ref.watch(nearestBusStopsProvider(
          busServiceFilter: _busServiceFilterText,
          minimumRefreshDuration: _minimumRefreshDuration));

  @override
  void initState() {
    super.initState();
    showSetupDialog();
    if (!kIsWeb) {
      const quickActions = QuickActions();
      quickActions.initialize((String shortcutType) {
        if (shortcutType == 'action_search') {
          _pushSearchRoute();
        }
      });
      quickActions.setShortcutItems(<ShortcutItem>[
        const ShortcutItem(
            type: 'action_search',
            localizedTitle: 'Search',
            icon: 'ic_shortcut_search'),
      ]);
    }
  }

  @override
  void dispose() {
    _fabScaleAnimationController.dispose();
    super.dispose();
  }

  Future<void> showSetupDialog() async {
    final cacheProgress = await ref.read(cachedDataProgressProvider.future);
    final isFullyCached = cacheProgress == 1.0;

    if (!isFullyCached && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (context) => const FetchDataPage(isSetup: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleOf(context));

    final bottomSheetContainer = bottomSheet(child: _buildBody());

    return PopScope(
      canPop: _canPop,
      onPopInvoked: _onPopInvoked,
      child: KeyboardDismissOnTap(
        child: Scaffold(
          body: bottomSheetContainer,
          resizeToAvoidBottomInset: false,
          floatingActionButton: ScaleTransition(
            scale: CurvedAnimation(
                parent: _fabScaleAnimationController,
                curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic)),
            child: FloatingActionButton.extended(
              heroTag: null,
              onPressed: _pushAddRouteRoute,
              label: const Text('Add route'),
              icon: const Icon(Icons.add_rounded),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _bottomNavIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (int index) {
              if (index == 0) {
                _fabScaleAnimationController.reverse();
              } else {
                _fabScaleAnimationController.forward();
              }
              setState(() {
                _bottomNavIndex = index;

                // Return back to the first page no matter which tab I'm on
                _activeRoute = null;
              });
              hideBusStopDetailSheet();
            },
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_rounded),
                label: 'Routes',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onPopInvoked(bool didPop) {
    if (didPop) {
      return;
    }

    if (_activeRoute != null) {
      setState(() {
        _activeRoute = null;
      });
      _fabScaleAnimationController.forward();
      return;
    }
    if (_bottomNavIndex == 1) {
      setState(() {
        _bottomNavIndex = 0;
        _fabScaleAnimationController.reverse();
      });
      return;
    }
  }

  bool get _canPop {
    if (isBusDetailSheetVisible()) {
      return true;
    }

    if (_activeRoute != null) {
      return false;
    }
    if (_bottomNavIndex == 1) {
      return false;
    }
    return true;
  }

  Widget _buildSearchField() {
    return Hero(
      tag: 'searchField',
      child: CardAppBar(
        elevation: 2.0,
        onTap: _pushSearchRoute,
        leading: Container(
          padding: const EdgeInsets.only(
              left: 16.0, top: 8.0, right: 8.0, bottom: 8.0),
          child: Icon(Icons.search_rounded, color: Theme.of(context).hintColor),
        ),
        title: TextField(
          enabled: false,
          focusNode: NeverFocusNode(),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(16.0),
            border: InputBorder.none,
            disabledBorder: InputBorder.none,
            hintText: 'Search for stops, services',
            hintStyle:
                const TextStyle().copyWith(color: Theme.of(context).hintColor),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Search on map',
            icon: Icon(Icons.map_rounded, color: Theme.of(context).hintColor),
            onPressed: _pushSearchRouteWithMap,
          ),
          FutureBuilder<NFCAvailability>(
            future: FlutterNfcKit.nfcAvailability,
            builder: (BuildContext context,
                AsyncSnapshot<NFCAvailability> snapshot) {
              return PopupMenuButton<String>(
                tooltip: 'More',
                icon: Icon(Icons.more_vert_rounded,
                    color: Theme.of(context).hintColor),
                onSelected: (String item) {
                  if (item == 'Settings') {
                    _pushSettingsRoute();
                  } else if (item == 'Check card value') {
                    _pushScanCardRoute();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
                  if (snapshot.hasData &&
                      snapshot.data == NFCAvailability.available)
                    const PopupMenuItem<String>(
                      value: 'Check card value',
                      child: Text('Check card value'),
                    ),
                  const PopupMenuItem<String>(
                    value: 'Settings',
                    child: Text('Settings'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          controller: _scrollController,
          scrollDirection: Axis.vertical,
          physics: canScroll
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                alignment: Alignment.topCenter,
                height: 64.0 + MediaQuery.of(context).padding.top,
              ),
            ),
            SliverToBoxAdapter(
              child: HomePageContentSwitcher(
                scrollController: _scrollController,
                child: _buildContent(),
              ),
            ),
          ],
        ),
        // Hide the overscroll contents from the status bar
        Container(
          height: kToolbarHeight / 2 + MediaQuery.of(context).padding.top,
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: AppBar(
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            scrolledUnderElevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarBrightness: Theme.of(context).brightness,
            ),
            backgroundColor: Colors.transparent,
            leading: null,
            automaticallyImplyLeading: false,
            titleSpacing: 16.0,
            elevation: 0.0,
            toolbarHeight: kToolbarHeight + 8,
            title: _buildSearchField(),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackedBuses() {
    final hasTrackedBuses = _followedBuses.isNotEmpty;

    return AnimatedSize(
      alignment: Alignment.topCenter,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: hasTrackedBuses ? 1 : 0,
        duration:
            hasTrackedBuses ? const Duration(milliseconds: 650) : Duration.zero,
        curve: const Interval(0.66, 1),
        child: hasTrackedBuses
            ? Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Tracked buses',
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      AnimatedSize(
                        alignment: Alignment.topCenter,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutCubic,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (BuildContext context, int position) {
                            final bus = _followedBuses[position];
                            return ListTile(
                              onTap: () {
                                context.read<BusStopSheetBloc>().add(
                                    SheetRequested(
                                        bus.busStop, kDefaultRouteId));
                              },
                              title: Consumer(
                                builder: (context, ref, child) {
                                  final arrivalTime = ref
                                      .watch(firstArrivalTimeProvider(
                                          busStop: bus.busStop,
                                          busServiceNumber:
                                              bus.busService.number))
                                      .value;

                                  return Text(
                                    arrivalTime != null
                                        ? '${bus.busService.number} - ${arrivalTime.getMinutesFromNow()} min'
                                        : '',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  );
                                },
                              ),
                              subtitle: Text(bus.busStop.displayName),
                            );
                          },
                          itemCount: _followedBuses.length,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.notifications_off_rounded),
                            label: Text(
                              'STOP TRACKING ALL BUSES',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            onPressed: () async {
                              final trackedBuses =
                                  await ref.read(followedBusesProvider.future);
                              await ref
                                  .read(followedBusesProvider.notifier)
                                  .unfollowAllBuses();
                              ScaffoldMessenger.of(context)
                                  .hideCurrentSnackBar();
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content:
                                    const Text('Stopped tracking all buses'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () async {
                                    for (var trackedBus in trackedBuses) {
                                      await ref
                                          .read(followedBusesProvider.notifier)
                                          .followBus(
                                              busStopCode:
                                                  trackedBus.busStop.code,
                                              busServiceNumber:
                                                  trackedBus.busService.number);
                                    }

                                    // Update the bus stop detail sheet to reflect change in bus stop follow status
                                    // TODO - This is a hack, find a better way to do this
                                    // widget.bottomSheetKey.currentState!
                                    //     .setState(() {});
                                  },
                                ),
                              ));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            : Container(),
      ),
    );
  }

  Widget _buildNearbyStops() {
    final homeRoute =
        ref.watch(savedUserRouteProvider(id: kDefaultRouteId)).valueOrNull;

    if (homeRoute == null) {
      return Container();
    }

    return Provider<StoredUserRoute>(
      create: (context) => homeRoute,
      child: Builder(
        builder: (BuildContext context) {
          if (!hasLocationPermissions) {
            return Container();
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16.0),
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                      'Nearby stops${_busServiceFilterText.isEmpty ? '' : ' (with bus $_busServiceFilterText)'}',
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
                TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Filter by bus service',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _busServiceTextController.clear();
                        });
                      },
                    ),
                  ),
                  controller: _busServiceTextController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16.0),
                AnimatedSize(
                  alignment: Alignment.topCenter,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: (_nearestBusStops.valueOrNull?.isNotEmpty ?? true)
                      ? ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          scrollDirection: Axis.vertical,
                          shrinkWrap: true,
                          itemCount: min(
                              _suggestionsCount,
                              _nearestBusStops.valueOrNull?.length ??
                                  _suggestionsCount),
                          separatorBuilder:
                              (BuildContext context, int position) =>
                                  const SizedBox(height: 8.0),
                          itemBuilder: (BuildContext context, int position) {
                            return switch (_nearestBusStops) {
                              AsyncData(:final value) =>
                                _buildSuggestionItem(value?[position]),
                              _ => _buildSuggestionItem(null),
                            };
                          },
                        )
                      : OutlineTitledContainer(
                          topOffset: 0,
                          body: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                CrossedIcon(
                                  icon: Icon(
                                    Icons.directions_bus_rounded,
                                    color: Theme.of(context).hintColor,
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Text(
                                  'Nothing found',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(
                                          color: Theme.of(context).hintColor),
                                )
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8.0),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: TextButton.icon(
                          icon: _suggestionsCount <= 4
                              ? const Icon(Icons.keyboard_arrow_down_rounded)
                              : const Icon(Icons.keyboard_arrow_up_rounded),
                          label: _suggestionsCount <= 4
                              ? const Text('Show more')
                              : const Text('Collapse'),
                          onPressed: () {
                            setState(() {
                              if (_suggestionsCount <= 4) {
                                _suggestionsCount += 2;
                              } else {
                                _suggestionsCount = 1;
                              }
                            });
                          },
                        ),
                      ),
                      const VerticalDivider(),
                      TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                        onPressed: refreshLocation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestionItem(BusStopWithDistance? busStopWithDistance) {
    final distanceText =
        '${busStopWithDistance?.distance.floor() ?? Random().nextInt(500) + 100} m away';
    final busStop = busStopWithDistance?.busStop;
    final busStopNameText = busStop?.displayName ?? 'Bus stop';
    final busStopCodeText = busStop != null
        ? '${busStop.code} · ${busStop.road}'
        : '${Random().nextInt(90000) + 10000} · ${Random().nextInt(99) + 1} Street';

    final showShimmer =
        _nearestBusStops.isRefreshing || _nearestBusStops.isReloading;

    Widget buildChild(bool showShimmer) => Builder(builder: (context) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: OutlineTitledContainer(
              showGap: !showShimmer,
              topOffset: 8.0,
              titlePadding: 16.0,
              title: Text(distanceText,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: Theme.of(context).hintColor)),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8.0),
                    onTap: busStopWithDistance != null
                        ? () => context.read<BusStopSheetBloc>().add(
                            SheetRequested(
                                busStopWithDistance.busStop, kDefaultRouteId))
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(busStopNameText,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(busStopCodeText,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall!
                                  .copyWith(
                                      color: Theme.of(context).hintColor)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 300),
      firstChild: Shimmer.fromColors(
        baseColor: Color.lerp(
            Theme.of(context).hintColor, Theme.of(context).canvasColor, 0.9)!,
        highlightColor: Theme.of(context).canvasColor,
        child: buildChild(true),
      ),
      secondChild: buildChild(false),
      crossFadeState:
          showShimmer ? CrossFadeState.showFirst : CrossFadeState.showSecond,
    );
  }

  Widget _buildContent() {
    if (_bottomNavIndex == 1 && _activeRoute != null) {
      return RoutePage(route: _activeRoute!);
    } else {
      return MediaQuery.removePadding(
        key: ValueKey<int>(_bottomNavIndex),
        context: context,
        removeTop: true,
        child: NotificationListener<ReorderStatusNotification>(
          onNotification: (ReorderStatusNotification notification) {
            setState(() {
              canScroll = !notification.isReordering;
            });

            return true;
          },
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children:
                _bottomNavIndex == 0 ? _buildHomeItems() : _buildRoutesItems(),
          ),
        ),
      );
    }
  }

  List<Widget> _buildHomeItems() {
    return [
      _buildTrackedBuses(),
      if (hasLocationPermissions) ...<Widget>{
        _buildNearbyStops(),
        const Divider(
          height: 32.0,
          indent: 16.0,
          endIndent: 16.0,
        ),
      } else ...<Widget>{
        const SizedBox(height: 32.0),
      },
      _buildMyStopsHeader(),
      ProxyProvider0<EditModel>(
        update: (_, __) => EditModel(isEditing: _isEditing),
        child: const BusStopOverviewList(
          routeId: kDefaultRouteId,
        ),
      ),
      // _busStopOverviewList,
      const SizedBox(height: 64.0),
    ];
  }

  Widget _buildMyStopsHeader() {
    return Padding(
      padding:
          const EdgeInsets.only(top: 0, left: 32.0, right: 16.0, bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('My Stops', style: Theme.of(context).textTheme.headlineMedium),
          // OverflowButton
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            firstChild: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: Theme.of(context).hintColor),
              itemBuilder: (BuildContext context) {
                return <PopupMenuItem<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Edit stops'),
                  ),
                ];
              },
              onSelected: (String value) {
                if (value == 'edit') {
                  setState(() {
                    _isEditing = true;
                  });
                }
              },
            ),
            secondChild: IconButton(
                icon: const Icon(Icons.done_rounded),
                tooltip: 'Save',
                color: Theme.of(context).colorScheme.secondary,
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                  });
                }),
            crossFadeState: _isEditing
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRoutesItems() {
    return [
      NotificationListener<RouteActionNotification>(
        onNotification: (RouteActionNotification notification) {
          if (notification.action == RouteAction.select) {
            _pushRoutePageRoute(notification.route);
            return true;
          }
          if (notification.action == RouteAction.edit) {
            _pushEditRouteRoute(notification.route);
          }

          return false;
        },
        child: const RouteList(),
      ),
    ];
  }

  Future<void> refreshLocation() async {
    ref.invalidate(userLocationProvider);
  }

  Future<void> _pushAddRouteRoute() async {
    final Route<UserRoute> route =
        FadePageRoute<UserRoute>(child: const AddRoutePage());
    final userRoute = await Navigator.push(context, route);

    if (userRoute != null) {
      await ref.read(savedUserRoutesProvider.notifier).addRoute(userRoute);
    }
  }

  void _pushRoutePageRoute(StoredUserRoute route) {
    _fabScaleAnimationController.reverse();
    setState(() {
      _activeRoute = route;
    });
  }

  Future<void> _pushEditRouteRoute(StoredUserRoute route) async {
    final editedRoute = await Navigator.push(context,
        FadePageRoute<StoredUserRoute>(child: AddRoutePage.edit(route)));
    if (editedRoute != null) {
      await ref.read(savedUserRoutesProvider.notifier).updateRoute(editedRoute);
    }
  }

  void _pushSearchRoute() {
    hideBusStopDetailSheet();
    final Widget page = SearchPage();
    final Route<void> route = FadePageRoute<void>(child: page);
    Navigator.push(context, route);
  }

  void _pushSearchRouteWithMap() {
    hideBusStopDetailSheet();
    final Widget page = SearchPage(showMap: true);
    final Route<void> route =
        MaterialPageRoute<void>(builder: (BuildContext context) => page);
    Navigator.push(context, route);
  }

  void _pushSettingsRoute() {
    const Widget page = SettingsPage();
    final Route<void> route =
        MaterialPageRoute<void>(builder: (BuildContext context) => page);
    Navigator.push(context, route);
  }

  void _pushScanCardRoute() {
    const Widget page = ScanCardPage();
    final Route<void> route =
        MaterialPageRoute<void>(builder: (BuildContext context) => page);
    Navigator.push(context, route);
  }
}
