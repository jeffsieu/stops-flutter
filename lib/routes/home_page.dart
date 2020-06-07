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
import '../utils/bus_stop.dart';
import '../utils/database_utils.dart';
import '../utils/location_utils.dart';
import '../utils/reorder_status_notification.dart';
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
    return RefreshIndicator(
      onRefresh: refreshLocation,
      child: CustomScrollView(
        controller: _scrollController,
        scrollDirection: Axis.vertical,
        physics: canScroll ? const AlwaysScrollableScrollPhysics() : const NeverScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            floating: true,
            pinned: true,
            brightness: Theme.of(context).brightness,
            titleSpacing: 8.0,
            title: Container(
              child: _buildSearchField(),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0.0,
          ),
          SliverToBoxAdapter(
            child: HomePageContentSwitcher(
              scrollController: _scrollController,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getNearestBusStops(),
      initialData: _nearestBusStops,
      builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
        if (snapshot.hasData)
          _nearestBusStops = snapshot.data;
        final bool isLoaded = snapshot.hasData && snapshot.data['busStops'].length == 5;
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          margin: const EdgeInsets.all(8.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: ExpandablePanel(
              tapHeaderToExpand: true,
              headerAlignment: ExpandablePanelHeaderAlignment.center,
              header: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(16.0),
                child: Text('Nearby stops', style: Theme.of(context).textTheme.headline4),
              ),
              collapsed: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (isLoaded)
                    _buildSuggestionItem(snapshot.data['busStops'][0], snapshot.data['distances'][0]),
                  if (!isLoaded)
                    _buildSuggestionItem(null, null),
                ],
              ),
              expanded: isLoaded ? ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                itemCount: 5,
                separatorBuilder: (BuildContext context, int position) => const Divider(),
                itemBuilder: (BuildContext context, int position) {
                  final BusStop busStop = snapshot.data['busStops'][position ];
                  final double distanceInMeters = snapshot.data['distances'][position];
                  return _buildSuggestionItem(busStop, distanceInMeters);
                },
              ) : Container(),
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
      _buildSuggestions(),
      const Divider(height: 32.0, indent: 8.0, endIndent: 8.0),
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
      // Location permissions not given
      return null;
    } else {
      return await getNearestBusStops(locationData.latitude, locationData.longitude);
    }
  }

  Future<void> refreshLocation() async {
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
