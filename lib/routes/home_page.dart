import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shimmer/shimmer.dart';

import '../bus_stop_sheet/bloc/bus_stop_sheet_bloc.dart';
import '../main.dart';
import '../models/bus.dart';
import '../models/bus_stop.dart';
import '../models/bus_stop_with_distance.dart';
import '../models/user_route.dart';
import '../routes/add_route_page.dart';
import '../routes/fetch_data_dialog.dart';
import '../routes/route_page.dart';
import '../routes/scan_card_page.dart';
import '../routes/settings_page.dart';
import '../utils/bus_api.dart';
import '../utils/bus_service_arrival_result.dart';
import '../utils/database_utils.dart';
import '../utils/location_utils.dart';
import '../utils/reorder_status_notification.dart';
import '../utils/time_utils.dart';
import '../widgets/bus_stop_overview_list.dart';
import '../widgets/card_app_bar.dart';
import '../widgets/crossed_icon.dart';
import '../widgets/edit_model.dart';
import '../widgets/home_page_content_switcher.dart';
import '../widgets/never_focus_node.dart';
import '../widgets/outline_titled_container.dart';
import '../widgets/route_list.dart';
import '../widgets/route_list_item.dart';
import 'bottom_sheet_page.dart';
import 'fade_page_route.dart';
import 'search_page.dart';

class HomePage extends BottomSheetPage {
  HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();

  static _HomePageState? of(BuildContext context) =>
      context.findAncestorStateOfType<_HomePageState>();
}

class _HomePageState extends BottomSheetPageState<HomePage>
    with WidgetsBindingObserver {
  _HomePageState() : super(hasAppBar: false);

  final Duration _minimumRefreshDuration = const Duration(milliseconds: 300);
  int _bottomNavIndex = 0;
  int _suggestionsCount = 1;
  List<BusStopWithDistance>? _nearestBusStops;
  bool _isNearestBusStopsCurrent = false;
  bool _isEditing = false;
  List<Bus>? _followedBuses;
  final ScrollController _scrollController = ScrollController();
  bool canScroll = true;
  late final AnimationController _fabScaleAnimationController =
      AnimationController(
          vsync: this, duration: HomePageContentSwitcher.animationDuration);
  final TextEditingController _busServiceTextController =
      TextEditingController();
  String get _busServiceFilterText => _busServiceTextController.text;
  StoredUserRoute? _activeRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    showSetupDialog();
    if (!kIsWeb) {
      const QuickActions quickActions = QuickActions();
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
    WidgetsBinding.instance.removeObserver(this);
    _fabScaleAnimationController.dispose();
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      refresh();
    }
  }

  Future<void> showSetupDialog() async {
    final bool cachedBusStops = await areBusStopsCached();
    final bool cachedBusServices = await areBusServicesCached();
    final bool cachedBusServiceRoutes = await areBusServiceRoutesCached();
    final bool isFullyCached =
        cachedBusStops && cachedBusServices && cachedBusServiceRoutes;
    if (!isFullyCached) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const FetchDataDialog(isSetup: true);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleOf(context));

    final Widget bottomSheetContainer = bottomSheet(child: _buildBody());

    return WillPopScope(
      onWillPop: _onWillPop,
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

  Future<bool> _onWillPop() async {
    if (isBusDetailSheetVisible()) {
      return true;
    }

    if (_activeRoute != null) {
      setState(() {
        _activeRoute = null;
      });
      _fabScaleAnimationController.forward();
      return false;
    }
    if (_bottomNavIndex == 1) {
      setState(() {
        _bottomNavIndex = 0;
        _fabScaleAnimationController.reverse();
      });
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
                      child: Text('Check card value'),
                      value: 'Check card value',
                    ),
                  const PopupMenuItem<String>(
                    child: Text('Settings'),
                    value: 'Settings',
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
    return AnimatedSize(
      alignment: Alignment.topCenter,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      child: StreamBuilder<List<Bus>>(
        initialData: _followedBuses,
        stream: followedBusesStream(),
        builder: (BuildContext context, AsyncSnapshot<List<Bus>> snapshot) {
          if (snapshot.hasData &&
              snapshot.connectionState != ConnectionState.waiting) {
            _followedBuses = snapshot.data!;
          }
          final bool hasTrackedBuses =
              snapshot.hasData && snapshot.data!.isNotEmpty;
          return AnimatedOpacity(
            opacity: hasTrackedBuses ? 1 : 0,
            duration: hasTrackedBuses
                ? const Duration(milliseconds: 650)
                : Duration.zero,
            curve: const Interval(0.66, 1),
            child: hasTrackedBuses
                ? Card(
                    margin: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 16.0),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
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
                              itemBuilder:
                                  (BuildContext context, int position) {
                                final Bus bus = snapshot.data![position];
                                return ListTile(
                                  onTap: () {
                                    context.read<BusStopSheetBloc>().add(
                                        SheetRequested(
                                            bus.busStop, kDefaultRouteId));
                                  },
                                  title: StreamBuilder<
                                      List<BusServiceArrivalResult>>(
                                    stream: BusAPI()
                                        .busStopArrivalStream(bus.busStop),
                                    builder: (BuildContext context,
                                        AsyncSnapshot<
                                                List<BusServiceArrivalResult>>
                                            snapshot) {
                                      DateTime? arrivalTime;
                                      if (snapshot.hasData) {
                                        for (BusServiceArrivalResult arrivalResult
                                            in snapshot.data!) {
                                          if (arrivalResult.busService ==
                                              bus.busService) {
                                            arrivalTime = arrivalResult
                                                .buses.firstOrNull?.arrivalTime;
                                          }
                                        }
                                      }
                                      return Text(
                                        arrivalTime != null
                                            ? '${bus.busService.number} - ${arrivalTime.getMinutesFromNow()} min'
                                            : '',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      );
                                    },
                                  ),
                                  subtitle: Text(bus.busStop.displayName),
                                );
                              },
                              itemCount: snapshot.data?.length ?? 0,
                            ),
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                icon:
                                    const Icon(Icons.notifications_off_rounded),
                                label: Text(
                                  'STOP TRACKING ALL BUSES',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                                onPressed: () async {
                                  final List<Map<String, dynamic>>
                                      trackedBuses = await unfollowAllBuses();
                                  ScaffoldMessenger.of(context)
                                      .hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: const Text(
                                        'Stopped tracking all buses'),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () async {
                                        for (Map<String, dynamic> trackedBus
                                            in trackedBuses) {
                                          await followBus(
                                              stop:
                                                  trackedBus['stop'] as String,
                                              bus: trackedBus['bus'] as String,
                                              arrivalTime:
                                                  trackedBus['arrivalTime']
                                                      as DateTime);
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
          );
        },
      ),
    );
  }

  Widget _buildNearbyStops() {
    return FutureBuilder<StoredUserRoute>(
        future: getRouteWithId(kDefaultRouteId),
        builder: (context, snapshot) {
          if (snapshot == null || !snapshot.hasData) {
            return Container();
          }

          return Provider<StoredUserRoute>(
            create: (context) => snapshot.data!,
            child: FutureBuilder<List<BusStopWithDistance>?>(
              future: _getNearestBusStops(_busServiceFilterText)
                  .withMinimumDuration(_isNearestBusStopsCurrent
                      ? Duration.zero
                      : _minimumRefreshDuration),
              initialData: _nearestBusStops,
              builder: (BuildContext context,
                  AsyncSnapshot<List<BusStopWithDistance>?> snapshot) {
                if (!LocationUtils.isLocationAllowed()) {
                  return Container();
                }

                if (snapshot.hasData &&
                    snapshot.connectionState == ConnectionState.done) {
                  _nearestBusStops = snapshot.data!;
                  _isNearestBusStopsCurrent = true;
                }
                final bool isLoaded = _nearestBusStops?.isNotEmpty ?? false;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                            'Nearby stops' +
                                (_busServiceFilterText.isEmpty
                                    ? ''
                                    : ' (with bus $_busServiceFilterText)'),
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
                        onChanged: (String value) {
                          setState(() {
                            _isNearestBusStopsCurrent = false;
                          });
                        },
                      ),
                      const SizedBox(height: 16.0),
                      AnimatedSize(
                        alignment: Alignment.topCenter,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: (_nearestBusStops?.isNotEmpty ?? true)
                            ? ListView.separated(
                                physics: const NeverScrollableScrollPhysics(),
                                scrollDirection: Axis.vertical,
                                shrinkWrap: true,
                                itemCount: min(
                                    _suggestionsCount,
                                    _nearestBusStops?.length ??
                                        _suggestionsCount),
                                separatorBuilder:
                                    (BuildContext context, int position) =>
                                        const SizedBox(height: 8.0),
                                itemBuilder:
                                    (BuildContext context, int position) {
                                  final BusStopWithDistance?
                                      busStopWithDistance = isLoaded &&
                                              position <
                                                  _nearestBusStops!.length
                                          ? _nearestBusStops![position]
                                          : null;
                                  return _buildSuggestionItem(
                                      busStopWithDistance);
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
                                            .subtitle1!
                                            .copyWith(
                                                color: Theme.of(context)
                                                    .hintColor),
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
                                    ? const Icon(
                                        Icons.keyboard_arrow_down_rounded)
                                    : const Icon(
                                        Icons.keyboard_arrow_up_rounded),
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
        });
  }

  Widget _buildSuggestionItem(BusStopWithDistance? busStopWithDistance) {
    final String distanceText =
        '${busStopWithDistance?.distance.floor() ?? Random().nextInt(500) + 100} m away';
    final BusStop? busStop = busStopWithDistance?.busStop;
    final String busStopNameText = busStop?.displayName ?? 'Bus stop';
    final String busStopCodeText = busStop != null
        ? '${busStop.code} · ${busStop.road}'
        : '${Random().nextInt(90000) + 10000} · ${Random().nextInt(99) + 1} Street';

    final bool showShimmer = !_isNearestBusStopsCurrent;

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
      return RoutePage(_activeRoute!);
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
      if (LocationUtils.isLocationAllowed()) ...<Widget>{
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

  Future<List<BusStopWithDistance>?> _getNearestBusStops(
      String busServiceFilter) async {
    final LocationData? locationData = await LocationUtils.getLocation();
    if (locationData == null) {
      return null;
    } else {
      return await getNearestBusStops(
          locationData.latitude!, locationData.longitude!, busServiceFilter);
    }
  }

  Future<void> refreshLocation() async {
    setState(() {
      LocationUtils.invalidateLocation();
      _isNearestBusStopsCurrent = false;
    });
  }

  Future<void> refresh() async {
    setState(() {});
  }

  Future<void> _pushAddRouteRoute() async {
    final Route<UserRoute> route =
        FadePageRoute<UserRoute>(child: const AddRoutePage());
    final UserRoute? userRoute = await Navigator.push(context, route);

    if (userRoute != null) storeUserRoute(userRoute);
  }

  void _pushRoutePageRoute(StoredUserRoute route) {
    _fabScaleAnimationController.reverse();
    setState(() {
      _activeRoute = route;
    });
  }

  Future<void> _pushEditRouteRoute(StoredUserRoute route) async {
    final StoredUserRoute? editedRoute = await Navigator.push(context,
        FadePageRoute<StoredUserRoute>(child: AddRoutePage.edit(route)));
    if (editedRoute != null) {
      updateUserRoute(editedRoute);
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

extension<T> on Future<T> {
  Future<T> withMinimumDuration(Duration duration) async {
    await Future.wait(<Future<dynamic>>[this, Future<void>.delayed(duration)]);
    return this;
  }
}
