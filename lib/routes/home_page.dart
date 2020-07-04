import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shimmer/shimmer.dart';

import '../main.dart';
import '../routes/add_route_page.dart';
import '../routes/route_page.dart';
import '../routes/settings_page.dart';
import '../utils/bus.dart';
import '../utils/bus_api.dart';
import '../utils/bus_stop.dart';
import '../utils/database_utils.dart';
import '../utils/location_utils.dart';
import '../utils/reorder_status_notification.dart';
import '../utils/time_utils.dart';
import '../utils/user_route.dart';
import '../widgets/bus_stop_overview_list.dart';
import '../widgets/card_app_bar.dart';
import '../widgets/home_page_content_switcher.dart';
import '../widgets/never_focus_node.dart';
import '../widgets/route_list.dart';
import '../widgets/route_list_item.dart';
import '../widgets/route_model.dart';
import 'bottom_sheet_page.dart';
import 'fade_page_route.dart';
import 'search_page.dart';

class HomePage extends BottomSheetPage {
  @override
  _HomePageState createState() => _HomePageState();

  static _HomePageState of(BuildContext context) => context.findAncestorStateOfType<_HomePageState>();
}

class _HomePageState extends BottomSheetPageState<HomePage> {
  Widget _busStopOverviewList;
  int _bottomNavIndex;
  Map<String, dynamic> _nearestBusStops;
  List<Bus> _followedBuses;
  ScrollController _scrollController;
  bool canScroll;
  AnimationController _fabScaleAnimationController;
  UserRoute _activeRoute;

  @override
  void initState() {
    super.initState();
    final QuickActions quickActions = QuickActions();
    quickActions.initialize((String shortcutType) {
      if (shortcutType == 'action_search') {
        _pushSearchRoute();
      }
    });
    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(type: 'action_search', localizedTitle: 'Search', icon: 'icon_search'),
    ]);

    _bottomNavIndex = 0;
    _busStopOverviewList = BusStopOverviewList();
    _scrollController = ScrollController();
    _fabScaleAnimationController = AnimationController(vsync: this, duration: HomePageContentSwitcher.animationDuration);
    canScroll = true;
  }

  @override
  Widget build(BuildContext context) {
    buildSheet(hasAppBar: false);
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleOf(context));

    final Widget bottomSheetContainer = bottomSheet(child: _buildBody());

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: bottomSheetContainer,
        resizeToAvoidBottomInset: false,
        floatingActionButton: ScaleTransition(
          scale: CurvedAnimation(parent: _fabScaleAnimationController, curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic)),
          child: FloatingActionButton.extended(
            heroTag: null,
            onPressed: _pushAddRouteRoute,
            label: const Text('Add new route'),
            icon: const Icon(Icons.add),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        bottomNavigationBar: BottomNavigationBar(
          elevation: 8.0,
          currentIndex: _bottomNavIndex,
          onTap: (int index) {
            if (index == 0)
              _fabScaleAnimationController.reverse();
            else
              _fabScaleAnimationController.forward();
            setState(() {
              _bottomNavIndex = index;

              // Return back to the first page no matter which tab I'm on
              _activeRoute = null;
            });
            hideBusDetailSheet();
          },
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              title: Text('Home'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.directions),
              title: Text('Routes'),
            ),
          ],
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
          child: Icon(Icons.search, color: Theme.of(context).hintColor),
        ),
        title: TextField(
          enabled: false,
          focusNode: NeverFocusNode(),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(16.0),
            border: InputBorder.none,
            hintText: 'Search for bus stops and buses',
            hintStyle: const TextStyle().copyWith(color:
            Theme.of(context).hintColor),
          ),
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Search on map',
            icon: Icon(Icons.map, color: Theme.of(context).hintColor),
            onPressed: _pushSearchRouteWithMap,
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(Icons.more_vert, color: Theme.of(context).hintColor),
            onSelected: (String item) {
              if (item == 'Settings') {
                _pushSettingsRoute();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
              const PopupMenuItem<String>(
                child: Text('Settings'),
                value: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: <Widget>[
        CustomScrollView(
          controller: _scrollController,
          scrollDirection: Axis.vertical,
          physics: canScroll ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
          slivers: <Widget>[
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
            brightness: Theme.of(context).brightness,
            backgroundColor: Colors.transparent,
            leading: null,
            automaticallyImplyLeading: false,
            titleSpacing: 8.0,
            elevation: 0.0,
            title: Container(
              child: _buildSearchField(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackedBuses() {
    return AnimatedSize(
      alignment: Alignment.topCenter,
      vsync: this,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      child: StreamBuilder<List<Bus>>(
        initialData: _followedBuses,
        stream: followedBusesStream(),
        builder: (BuildContext context, AsyncSnapshot<List<Bus>> snapshot) {
          final bool isLoaded = snapshot.hasData && snapshot.data.isNotEmpty;
          if (isLoaded)
            _followedBuses = snapshot.data;

          return AnimatedOpacity(
            opacity: isLoaded ? 1 : 0,
            duration: isLoaded ? const Duration(milliseconds: 650) : Duration.zero,
            curve: const Interval(0.66, 1),
            child: isLoaded ? Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('Tracked buses', style: Theme.of(context).textTheme.headline4),
                    ),
                    AnimatedSize(
                      alignment: Alignment.topCenter,
                      vsync: this,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (BuildContext context, int position) {
                          final Bus bus = snapshot.data[position];

                          return ListTile(
                            onTap: () {
                              showBusDetailSheet(bus.busStop, UserRoute.home);
                            },
                            title: FutureBuilder<DateTime>(
                              future: BusAPI().getArrivalTime(bus.busStop, bus.busService.number),
                              builder: (BuildContext context, AsyncSnapshot<DateTime> snapshot) {
                                return Text(snapshot.hasData ? '${bus.busService.number} - ${snapshot.data.getMinutesFromNow()} min' : '',
                                  style: Theme.of(context).textTheme.headline6,
                                );
                              },
                            ),
                            subtitle: Text(bus.busStop.displayName),
                          );
                        },
                        itemCount: snapshot.data.length,
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        FlatButton.icon(
                          icon: const Icon(Icons.notifications_off),
                          label: const Text(
                            'STOP TRACKING ALL BUSES',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          textColor: Theme.of(context).accentColor,
                          onPressed: () async {
                            final List<Map<String, dynamic>> trackedBuses = await unfollowAllBuses();
                            Scaffold.of(context).showSnackBar(SnackBar(
                              content: const Text('Stopped tracking all buses'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () async {
                                  for (Map<String, dynamic> trackedBus in trackedBuses) {
                                    await followBus(stop: trackedBus['stop'], bus: trackedBus['bus'], arrivalTime: trackedBus['arrivalTime']);
                                  }

                                  // Update the bus stop detail sheet to reflect change in bus stop follow status
                                  widget.bottomSheetKey.currentState.setState(() {});
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
            ) : Container(),
          );
        },
      ),
    );
  }

  Widget _buildSuggestions() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getNearestBusStops(),
      initialData: _nearestBusStops,
      builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
        if (snapshot.hasData && snapshot.connectionState == ConnectionState.done)
          _nearestBusStops = snapshot.data;
        else if (snapshot.connectionState == ConnectionState.done || !LocationUtils.isLocationAllowed()) {
          return Container();
        }
        final bool isLoaded = _nearestBusStops != null && _nearestBusStops['busStops'].length == 5;

        final Widget refreshButton = Row(
          children: <Widget>[
            FlatButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text(
                'REFRESH LOCATION',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              textColor: Theme.of(context).accentColor,
              onPressed: refreshLocation,
            ),
          ],
        );

        return Card(
          elevation: 0.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(
              color: Theme.of(context).dividerColor,
            ),
          ),
          color: Theme.of(context).scaffoldBackgroundColor,
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              children: [
                ExpandablePanel(
                  tapHeaderToExpand: true,
                  hasIcon: true,
                  headerAlignment: ExpandablePanelHeaderAlignment.center,
                  header: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Nearby stops', style: Theme.of(context).textTheme.headline4),
                  ),
                  collapsed: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (isLoaded)
                        _buildSuggestionItem(_nearestBusStops['busStops'][0], _nearestBusStops['distances'][0]),
                      if (!isLoaded)
                        _buildSuggestionItem(null, null),
                    ],
                  ),
                  expanded: ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    scrollDirection: Axis.vertical,
                    shrinkWrap: true,
                    itemCount: 5,
                    separatorBuilder: (BuildContext context, int position) => const Divider(),
                    itemBuilder: (BuildContext context, int position) {
                      final BusStop busStop = isLoaded ? _nearestBusStops['busStops'][position] : null;
                      final double distanceInMeters = isLoaded ? _nearestBusStops['distances'][position] : null;
                      return _buildSuggestionItem(busStop, distanceInMeters);
                    },
                  ),
                ),
                refreshButton,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuggestionItem(BusStop busStop, double distanceInMeters) {
    final bool showShimmer = busStop == null || distanceInMeters == null;

    Widget child;
    if (showShimmer) {
      child = Shimmer.fromColors(
        baseColor: Color.lerp(Theme.of(context).hintColor, Theme.of(context).canvasColor, 0.9),
        highlightColor: Theme.of(context).canvasColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('▅▅▅▅▅▅▅▅', style: Theme.of(context).textTheme.overline.copyWith(backgroundColor: Colors.grey)),
            Text('██████████', style: Theme.of(context).textTheme.bodyText2.copyWith(backgroundColor: Colors.grey)),
            Text('▅▅▅▅▅▅▅▅▅▅▅▅▅▅▅', style: Theme.of(context).textTheme.overline.copyWith(backgroundColor: Colors.grey)),
          ],
        ),
      );
    } else {
      final String distanceText = '${distanceInMeters.floor()} m away';
      final String busStopNameText = busStop.displayName;
      final String busStopCodeText = '${busStop.code} · ${busStop.road}';
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(distanceText, style: Theme.of(context).textTheme.bodyText1.copyWith(color: Colors.grey)),
          Text(busStopNameText, style: Theme.of(context).textTheme.headline6),
          Text(busStopCodeText, style: Theme.of(context).textTheme.bodyText1.copyWith(color: Colors.grey)),
        ],
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8.0),
      onTap: () => showBusDetailSheet(busStop, UserRoute.home),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: child,
      ),
    );
  }

  Widget _buildContent() {
    if (_bottomNavIndex == 1 && _activeRoute != null) {
      return RoutePage(_activeRoute);
    } else {
      return MediaQuery.removePadding(
        key: ValueKey<int>(_bottomNavIndex),
        context: context,
        removeTop: true,
        child: RouteModel(
          route: UserRoute.home,
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
              children: _bottomNavIndex == 0 ? _buildHomeItems() : _buildRoutesItems(),
            ),
          ),
        ),
      );
    }
  }

  List<Widget> _buildHomeItems() {
    return <Widget>[
      _buildTrackedBuses(),
      _buildSuggestions(),
      const Divider(height: 32.0, indent: 8.0, endIndent: 8.0),
      Center(child: Text('My Stops', style: Theme.of(context).textTheme.headline4,)),
      _busStopOverviewList,
    ];
  }

  List<Widget> _buildRoutesItems() {
    return <Widget>[
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
        child: RouteList(),
      ),
    ];
  }

  Future<Map<String, dynamic>> _getNearestBusStops() async {
    final LocationData locationData = await LocationUtils.getLocation();
    if (locationData == null) {
      return null;
    } else {
      return await getNearestBusStops(locationData.latitude, locationData.longitude);
    }
  }

  Future<void> refreshLocation() async {
    setState((){
      _nearestBusStops = null;
    });
  }

  Future<void> refresh() async {
    setState(() {});
  }

  Future<void> _pushAddRouteRoute() async {
    final Route<void> route = FadePageRoute<UserRoute>(child: const AddRoutePage());
    final UserRoute userRoute = await Navigator.push(context, route);

    if (userRoute != null)
      storeUserRoute(userRoute);
  }

  void _pushRoutePageRoute(UserRoute route) {
    _fabScaleAnimationController.reverse();
    setState(() {
      _activeRoute = route;
    });
  }

  Future<void> _pushEditRouteRoute(UserRoute route) async {
    final UserRoute editedRoute = await Navigator.push(context, FadePageRoute<UserRoute>(child: AddRoutePage.edit(route)));
    if (editedRoute != null) {
      updateUserRoute(editedRoute);
    }
  }

  void _pushSearchRoute() {
    hideBusDetailSheet();
    final Route<void> route = MaterialPageRoute<void>(builder: (BuildContext context) => SearchPage());
    Navigator.push(context, route);
  }

  void _pushSearchRouteWithMap() {
    hideBusDetailSheet();
    final Route<void> route = MaterialPageRoute<void>(builder: (BuildContext context) => SearchPage(showMap: true));
    Navigator.push(context, route);
  }

  void _pushSettingsRoute() {
    final Route<void> route = MaterialPageRoute<void>(builder: (BuildContext context) => SettingsPage());
    Navigator.push(context, route);
  }
}
