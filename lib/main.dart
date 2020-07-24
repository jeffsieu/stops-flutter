import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'routes/home_page.dart';
import 'utils/database_utils.dart';

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

  static String monospacedFont = 'Cousine';

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
    final TextStyle headerTextStyle = GoogleFonts.nunitoSans(fontWeight: FontWeight.bold);
    final TextStyle mainTextStyle = GoogleFonts.nunitoSans(fontWeight: FontWeight.bold);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stops SG',
      themeMode: themeMode,
      home: HomePage(),
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        toggleableActiveColor: Colors.deepOrangeAccent,
        accentColor: Colors.deepOrangeAccent,
        cursorColor: Colors.deepOrangeAccent,
        textSelectionColor: Colors.orangeAccent[100],
        textSelectionHandleColor: Colors.deepOrangeAccent,
        brightness: Brightness.light,
        popupMenuTheme: PopupMenuThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
        cardTheme: CardTheme(elevation: 2.0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
        dialogTheme: DialogTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
        textTheme: TextTheme(
          headline1: mainTextStyle,
          headline2: mainTextStyle,
          headline3: mainTextStyle,
          headline4: headerTextStyle.copyWith(color: Colors.deepOrangeAccent, fontSize: 18),
          headline5: headerTextStyle.copyWith(fontSize: 24),
          headline6: mainTextStyle,
          subtitle1: mainTextStyle,
          subtitle2: mainTextStyle,
          bodyText1: mainTextStyle,
          bodyText2: mainTextStyle,
          button: mainTextStyle,
          caption: mainTextStyle,
          overline: mainTextStyle,
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.orange,
        toggleableActiveColor: Colors.orangeAccent,
        accentColor: Colors.orangeAccent,
        cursorColor: Colors.orangeAccent,
        textSelectionColor: Colors.deepOrangeAccent,
        textSelectionHandleColor: Colors.orangeAccent,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF272727),
        canvasColor: const Color(0xFF323232),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF323232),
          contentTextStyle: TextStyle(color: Colors.white),
          actionTextColor: Colors.orangeAccent,
        ),
        popupMenuTheme: PopupMenuThemeData(color: const Color(0xFF323232), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
        cardTheme: CardTheme(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
        dialogTheme: DialogTheme(backgroundColor: const Color(0xFF323232), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0))),
        textTheme: TextTheme(
          headline1: mainTextStyle,
          headline2: mainTextStyle,
          headline3: mainTextStyle,
          headline4: headerTextStyle.copyWith(color: Colors.orangeAccent, fontSize: 18),
          headline5: headerTextStyle.copyWith(fontSize: 24),
          headline6: mainTextStyle,
          subtitle1: mainTextStyle,
          subtitle2: mainTextStyle,
          bodyText1: mainTextStyle,
          bodyText2: mainTextStyle,
          button: mainTextStyle,
          caption: mainTextStyle,
          overline: mainTextStyle,
        ),
      ),
    );
  }
}
