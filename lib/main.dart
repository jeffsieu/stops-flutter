import 'package:flex_color_scheme/flex_color_scheme.dart';
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

    final TextTheme textTheme = TextTheme(
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
    );

    final ThemeData lightTheme = FlexThemeData.light(
      useMaterial3: true,
      colors: FlexSchemeColor.from(primary: Colors.deepOrange),
      fontFamily: GoogleFonts.nunitoSans().fontFamily,
      blendLevel: 16,
      subThemesData: const FlexSubThemesData(
        inputDecoratorBorderType: FlexInputBorderType.underline,
        inputDecoratorRadius: 8,
        inputDecoratorIsFilled: false,
      ),
      appBarStyle: FlexAppBarStyle.surface,
      tabBarStyle: FlexTabBarStyle.forBackground,
      surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
    );

    final ThemeData lightThemeWithBoldText = lightTheme.copyWith(
      textTheme: lightTheme.textTheme.merge(textTheme),
      splashColor: Colors.black.withOpacity(0.05),
      splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
      popupMenuTheme: PopupMenuThemeData(
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        color: FlexSchemeSurfaceColors.blend(
                blendLevel: 32,
                schemeColors: FlexSchemeColor.from(primary: Colors.deepOrange))
            .dialogBackground,
      ),
    );

    final ThemeData darkTheme = FlexThemeData.dark(
      useMaterial3: true,
      colors: FlexSchemeColor.from(primary: Colors.orange),
      fontFamily: GoogleFonts.nunitoSans().fontFamily,
      blendLevel: 16,
      subThemesData: const FlexSubThemesData(
        inputDecoratorBorderType: FlexInputBorderType.underline,
        inputDecoratorRadius: 8,
        inputDecoratorIsFilled: false,
      ),
      appBarStyle: FlexAppBarStyle.surface,
      tabBarStyle: FlexTabBarStyle.forBackground,
      surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
    );

    final ThemeData darkThemeWithBoldText = darkTheme.copyWith(
      textTheme: darkTheme.textTheme.merge(textTheme),
      splashColor: Colors.white.withOpacity(0.05),
      splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
      popupMenuTheme: PopupMenuThemeData(
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        color: FlexSchemeSurfaceColors.blend(
                brightness: Brightness.dark,
                blendLevel: 32,
                schemeColors: FlexSchemeColor.from(primary: Colors.orange))
            .dialogBackground,
      ),
    );

    return MaterialApp(
      title: 'Stops',
      themeMode: themeMode,
      home: HomePage(),
      theme: lightThemeWithBoldText,
      darkTheme: darkThemeWithBoldText,
    );
  }
}
