import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';

import 'package:quick_actions/quick_actions.dart';

import '../routes/settings_page.dart';
import '../utils/bus_stop.dart';
import '../utils/database_utils.dart';
import '../utils/location_utils.dart';
import '../widgets/bus_stop_overview_list.dart';
import 'bottom_sheet_page.dart';
import 'search_page.dart';

Future<void> main() async {
  final ThemeMode themeMode = await getThemeMode();
  runApp(StopsApp(themeMode));
}

class StopsApp extends StatefulWidget {
  const StopsApp(this._themeMode);
  final ThemeMode _themeMode;

  @override
  State createState() {
    return StopsAppState(_themeMode);
  }

  static StopsAppState of(BuildContext context) => context.ancestorStateOfType(const TypeMatcher<StopsAppState>());

  static SystemUiOverlayStyle overlayStyleWithBrightness(Brightness brightness) {
    final SystemUiOverlayStyle templateStyle = brightness == Brightness.light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;
    return templateStyle.copyWith(
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: brightness == Brightness.light ? Brightness.dark : Brightness.light,
      statusBarBrightness: brightness,
      systemNavigationBarColor: brightness == Brightness.light ? ThemeData.light().canvasColor : ThemeData.dark().canvasColor,
      systemNavigationBarIconBrightness: brightness == Brightness.light ? Brightness.dark : Brightness.light,
    );
  }
}

class StopsAppState extends State<StopsApp> {
  StopsAppState(this.themeMode);
  ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stops SG',
      themeMode: themeMode,
      home: HomePage(),
      theme: ThemeData(
        fontFamily: 'Source Sans Pro',
        primarySwatch: Colors.deepOrange,
        toggleableActiveColor: Colors.deepOrangeAccent,
        accentColor: Colors.deepOrangeAccent,
        textSelectionColor: Colors.deepOrangeAccent,
        textSelectionHandleColor: Colors.deepOrangeAccent,
        brightness: Brightness.light,
        textTheme: TextTheme(
          display1: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 3, color: Colors.deepOrangeAccent),
          headline: TextStyle(fontWeight: FontWeight.w300, fontSize: 28),
        ),
      ),
      darkTheme: ThemeData(
        fontFamily: 'Source Sans Pro',
        primarySwatch: Colors.orange,
        toggleableActiveColor: Colors.orangeAccent,
        accentColor: Colors.orangeAccent,
        textSelectionColor: Colors.deepOrangeAccent,
        textSelectionHandleColor: Colors.orangeAccent,
        brightness: Brightness.dark,
        textTheme: TextTheme(
          display1: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 3, color: Colors.orangeAccent),
          headline: TextStyle(fontWeight: FontWeight.w300, fontSize: 28),
        ),
      ),
    );
  }
}

class HomePage extends BottomSheetPage {
  @override
  _HomePageState createState() => _HomePageState();

  static _HomePageState of(BuildContext context) => context.ancestorStateOfType(const TypeMatcher<_HomePageState>());
}

class _HomePageState extends BottomSheetPageState<HomePage> {
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
  }

  @override
  Widget build(BuildContext context) {
    buildSheet(hasAppBar: false);
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleWithBrightness(Theme.of(context).brightness));

    final Widget bottomSheetContainer = bottomSheet(child: _buildBody());

    return Scaffold(
      body: bottomSheetContainer,
      resizeToAvoidBottomInset: false,
    );
  }

  Widget _buildSearchField() {
    return Hero(
      tag: 'searchField',
      child: Material(
        clipBehavior: Clip.none,
        type: MaterialType.card,
        elevation: 2.0,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: _pushSearchRoute,
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.only(
                    left: 16.0, top: 8.0, right: 8.0, bottom: 8.0),
                child: Icon(Icons.search, color: Theme.of(context).hintColor),
              ),
              Expanded(
                child: TextField(
                  enabled: false,
                  focusNode: _NeverFocusNode(),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(16.0),
                    border: InputBorder.none,
                    hintText: 'Search for bus stops and buses',
                    hintStyle: const TextStyle().copyWith(color:
                    Theme.of(context).hintColor),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Search on map',
                icon: Icon(Icons.map, color: Theme.of(context).hintColor),
                onPressed: _pushSearchRouteWithMap,
              ),
              PopupMenuButton<String>(
                tooltip: 'Search on map',
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
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: refreshLocation,
      child: CustomScrollView(
        scrollDirection: Axis.vertical,
        slivers: <Widget>[
          SliverAppBar(
            brightness: Theme.of(context).brightness,
            titleSpacing: 8.0,
            title: Container(
              child: _buildSearchField(),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0.0,
          ),
          _buildSuggestions(),
          BusStopOverviewList(),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getNearestBusStops(),
      builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
        return snapshot.hasData && snapshot.data['busStops'].length == 3 ? SliverToBoxAdapter(
          child: Container(
            height: 150,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (BuildContext context, int position) {
                final BusStop busStop = snapshot.data['busStops'][position];
                final double distanceInMeters = snapshot.data['distances'][position];

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    margin: const EdgeInsets.all(8.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8.0),
                      onTap: () => showBusDetailSheet(busStop),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('${position == 0 ? 'Nearest' : 'Nearby'} bus stop', style: Theme.of(context).textTheme.display1),
                            Text('${distanceInMeters.floor()} m away', style: Theme.of(context).textTheme.body2.copyWith(color: Colors.grey)),
                            Container(height: 16.0),
                            Text('${busStop.displayName}', style: Theme.of(context).textTheme.title),
                            Text('${busStop.code} · ${busStop.road}', style: Theme.of(context).textTheme.body2.copyWith(color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ) : const SliverToBoxAdapter();
      },
    );
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
    setState(() {  });
  }

  void _pushSearchRoute() {
    busStopDetailSheet.rubberAnimationController.animateTo(to: busStopDetailSheet.rubberAnimationController.lowerBound);
    final Route<void> route = MaterialPageRoute<void>(builder: (BuildContext context) => SearchPage());
    Navigator.push(context, route);
  }

  void _pushSearchRouteWithMap() {
    busStopDetailSheet.rubberAnimationController.animateTo(to: busStopDetailSheet.rubberAnimationController.lowerBound);
    final Route<void> route = MaterialPageRoute<void>(builder: (BuildContext context) => SearchPage(showMap: true));
    Navigator.push(context, route);
  }

  void _pushSettingsRoute() {
    final Route<void> route = MaterialPageRoute<void>(builder: (BuildContext context) => SettingsPage());
    Navigator.push(context, route);
  }
}

class _NeverFocusNode extends FocusNode {
  @override
  bool get hasFocus {
    return false;
  }
}
