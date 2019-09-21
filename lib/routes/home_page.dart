import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quick_actions/quick_actions.dart';

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
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          fontFamily: 'Source Sans Pro',
          primarySwatch: Colors.blue,
          brightness: Brightness.dark,
        ),
        home: HomePage(),
    );
  }

  static SystemUiOverlayStyle overlayStyleWithBrightness(Brightness brightness) {
    return SystemUiOverlayStyle(
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: brightness,
      statusBarBrightness: brightness,
      systemNavigationBarColor: brightness == Brightness.light ? ThemeData.light().canvasColor : ThemeData.dark().canvasColor,
      systemNavigationBarIconBrightness: brightness == Brightness.light ? Brightness.dark : Brightness.light,
    );
  }

  static Widget themeAnnotatedRegion({BuildContext context, Widget child}) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: StopsApp.overlayStyleWithBrightness(MediaQuery.of(context).platformBrightness),
        child: child,
    );
  }

}

class HomePage extends BottomSheetPage {
  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

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
      // More handling code...
    });
    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(type: 'action_search', localizedTitle: 'Search', icon: 'icon_search'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    buildSheet(isHomePage: true);
    return StopsApp.themeAnnotatedRegion(
      context: context,
      child: Scaffold(
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
            child: _buildBody()
        ),
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
    return bottomSheet(child: BusStopOverviewList());
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
