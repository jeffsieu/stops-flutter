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
  const StopsApp(this._themeMode, {Key? key}) : super(key: key);
  final ThemeMode _themeMode;

  @override
  State createState() {
    return StopsAppState();
  }

  static String monospacedFont = 'Cousine';

  static SystemUiOverlayStyle overlayStyleOf(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final SystemUiOverlayStyle templateStyle = brightness == Brightness.light
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;
    return templateStyle.copyWith(
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          brightness == Brightness.light ? Brightness.dark : Brightness.light,
      statusBarBrightness: brightness,
      systemNavigationBarColor: Theme.of(context).canvasColor,
      systemNavigationBarIconBrightness:
          brightness == Brightness.light ? Brightness.dark : Brightness.light,
    );
  }

  static StopsAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<StopsAppState>();
}

class StopsAppState extends State<StopsApp> {
  late ThemeMode themeMode = widget._themeMode;

  @override
  Widget build(BuildContext context) {
    final TextStyle headerTextStyle =
        GoogleFonts.nunitoSans(fontWeight: FontWeight.bold);
    final TextStyle mainTextStyle =
        GoogleFonts.nunitoSans(fontWeight: FontWeight.bold);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stops Singapore',
      themeMode: themeMode,
      home: HomePage(),
      theme: ThemeData(
        toggleableActiveColor: Colors.deepOrangeAccent,
        indicatorColor: Colors.orange,
        popupMenuTheme: PopupMenuThemeData(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0))),
        buttonTheme: ButtonThemeData(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0))),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)))),
        cardTheme: CardTheme(
            elevation: 2.0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0))),
        dialogTheme: DialogTheme(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0))),
        textTheme: TextTheme(
          headline1: mainTextStyle,
          headline2: mainTextStyle,
          headline3: mainTextStyle,
          headline4: headerTextStyle.copyWith(
              color: Colors.deepOrangeAccent, fontSize: 18),
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
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.deepOrangeAccent,
          selectionColor: Colors.orangeAccent[100],
          selectionHandleColor: Colors.deepOrangeAccent,
        ),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.deepOrange,
          accentColor: Colors.deepOrangeAccent,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
          toggleableActiveColor: Colors.orangeAccent,
          indicatorColor: Colors.orange,
          scaffoldBackgroundColor: const Color(0xFF121212),
          cardColor: const Color(0xFF272727),
          canvasColor: const Color(0xFF323232),
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: Color(0xFF323232),
            contentTextStyle: TextStyle(color: Colors.white),
            actionTextColor: Colors.orangeAccent,
          ),
          popupMenuTheme: PopupMenuThemeData(
              color: const Color(0xFF323232),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0))),
          buttonTheme: ButtonThemeData(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0))),
          elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)))),
          cardTheme: CardTheme(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0))),
          dialogTheme: DialogTheme(
              backgroundColor: const Color(0xFF323232),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0))),
          textTheme: TextTheme(
            headline1: mainTextStyle,
            headline2: mainTextStyle,
            headline3: mainTextStyle,
            headline4: headerTextStyle.copyWith(
                color: Colors.orangeAccent, fontSize: 18),
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
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Colors.orangeAccent,
            selectionColor: Colors.deepOrangeAccent,
            selectionHandleColor: Colors.orangeAccent,
          ),
          colorScheme: const ColorScheme.dark(
            primary: Colors.orange,
            secondary: Colors.orangeAccent,
            secondaryVariant: Colors.deepOrangeAccent,
          )),
    );
  }
}
