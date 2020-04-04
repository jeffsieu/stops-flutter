import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/database_utils.dart';
import 'home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  static SystemUiOverlayStyle overlayStyleOf(BuildContext context) {
    final Brightness brightness = MediaQuery.of(context).platformBrightness;
    final SystemUiOverlayStyle templateStyle = brightness == Brightness.light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;
    return templateStyle.copyWith(
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: brightness == Brightness.light ? Brightness.dark : Brightness.light,
      statusBarBrightness: brightness,
      systemNavigationBarColor: Theme.of(context).canvasColor,
      systemNavigationBarIconBrightness: brightness == Brightness.light ? Brightness.dark : Brightness.light,
    );
  }

  static StopsAppState of(BuildContext context) => context.findAncestorStateOfType<StopsAppState>();
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
        popupMenuTheme: PopupMenuThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
        cardTheme: CardTheme(elevation: 2.0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
        dialogTheme: DialogTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
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
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF272727),
        canvasColor: const Color(0xFF323232),
        popupMenuTheme: PopupMenuThemeData(color: const Color(0xFF323232), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
        cardTheme: CardTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
        dialogTheme: DialogTheme(backgroundColor: const Color(0xFF323232), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
        textTheme: TextTheme(
          display1: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 3, color: Colors.orangeAccent),
          headline: TextStyle(fontWeight: FontWeight.w300, fontSize: 28),
        ),
      ),
    );
  }
}
