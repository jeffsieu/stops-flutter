import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:location/location.dart';

import 'package:quick_actions/quick_actions.dart';
import 'package:stops_sg/utils/location_utils.dart';

import '../utils/bus_stop.dart';
import '../utils/shared_preferences_utils.dart';
import '../widgets/bus_stop_overview_list.dart';
import 'bottom_sheet_page.dart';
import 'search_page.dart';

void main() => runApp(StopsApp());

class StopsApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Stops SG',
        theme: ThemeData(
          fontFamily: 'Source Sans Pro',
          primarySwatch: Colors.blue,
          accentColor: Colors.deepOrangeAccent,
          brightness: Brightness.light,
          textTheme: TextTheme(headline: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 3, color: Colors.orangeAccent)),
        ),
        darkTheme: ThemeData(
          fontFamily: 'Source Sans Pro',
          primarySwatch: Colors.blue,
          accentColor: Colors.orangeAccent,
          brightness: Brightness.dark,
          textTheme: TextTheme(headline: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 3, color: Colors.orangeAccent)),
        ),
        home: HomePage(),
    );
  }

  static SystemUiOverlayStyle overlayStyleWithBrightness(Brightness brightness) {
    return SystemUiOverlayStyle(
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: brightness == Brightness.light ? Brightness.dark : Brightness.light,
      statusBarBrightness: brightness,
      systemNavigationBarColor: brightness == Brightness.light ? ThemeData.light().canvasColor : ThemeData.dark().canvasColor,
      systemNavigationBarIconBrightness: brightness == Brightness.light ? Brightness.dark : Brightness.light,
    );
  }
}

class HomePage extends BottomSheetPage {
  @override
  _HomePageState createState() => _HomePageState();

  static _HomePageState of(BuildContext context) => context.ancestorStateOfType(const TypeMatcher<_HomePageState>());
}

class _HomePageState extends BottomSheetPageState<HomePage> {
  String name;
  String code;

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
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleWithBrightness(MediaQuery.of(context).platformBrightness));
    buildSheet(isHomePage: true);

    final Widget bottomSheetContainer = bottomSheet(child: _buildBody());

    return Scaffold(
      appBar: AppBar(
        brightness: MediaQuery.of(context).platformBrightness,
        titleSpacing: 8.0,
        title: Container(
          child: _buildSearchField(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0.0,
      ),
      body: Center(
        child: bottomSheetContainer,
      ),
    );
  }

  Widget _buildSearchField() {
    return Hero(
      tag: 'searchField',
      child: Material(
        clipBehavior: Clip.none,
        type: MaterialType.card,
        elevation: 4.0,
        borderRadius: BorderRadius.circular(8.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: _pushSearchRoute,
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.only(
                    left: 16.0, top: 8.0, right: 8.0, bottom: 8.0),
                child: Icon(Icons.search, color: Theme.of(context).hintColor)),
              Expanded(
                child: TextField(
                  enabled: false,
                  focusNode: _NeverFocusNode(),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.all(16.0),
                    border: InputBorder.none,
                    hintText: 'Search for bus stops and buses',
                    hintStyle: TextStyle().copyWith(color:
                    Theme.of(context).hintColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return CustomScrollView(
      scrollDirection: Axis.vertical,
      slivers: <Widget>[
        _buildSuggestions(),
        BusStopOverviewList(),
      ],
    );
  }

  Widget _buildSuggestions() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getNearestBusStops(),
      builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>> snapshot) {
        return snapshot.hasData ? SliverToBoxAdapter(
          child: Container(
            height: 150,
            child: PageView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (BuildContext context, int position) {
                final BusStop busStop = snapshot.data['busStops'][position];
                final double distanceInMeters = snapshot.data['distances'][position];

                return Container(
                  width: MediaQuery.of(context).size.width,
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
                            Text('${position == 0 ? 'Nearest' : 'Nearby'} bus stop', style: Theme.of(context).textTheme.headline),
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

  void _pushSearchRoute() {
    busStopDetailSheet.rubberAnimationController.animateTo(to: busStopDetailSheet.rubberAnimationController.lowerBound);
    final Route<void> route = MaterialPageRoute<void>(builder: (BuildContext context) => SearchPage());
    Navigator.push(context, route);
  }
}

class _NeverFocusNode extends FocusNode {
  @override
  bool get hasFocus {
    return false;
  }
}
