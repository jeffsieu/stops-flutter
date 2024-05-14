import 'package:dynamic_color/dynamic_color.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'routes/home_page.dart';
import 'utils/database_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ProviderScope(child: StopsApp()));
}

class StopsApp extends ConsumerWidget {
  const StopsApp({super.key});

  static String monospacedFont = 'Cousine';

  static SystemUiOverlayStyle overlayStyleOf(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final templateStyle = brightness == Brightness.light
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(selectedThemeModeProvider);
    final headerTextStyle = GoogleFonts.nunitoSans(fontWeight: FontWeight.bold);
    final mainTextStyle = GoogleFonts.nunitoSans(fontWeight: FontWeight.bold);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightColorScheme = lightDynamic != null
            ? FlexColorScheme(colorScheme: lightDynamic).toScheme
            : const FlexColorScheme(
                    primary: Colors.deepOrange, brightness: Brightness.light)
                .toScheme;

        final darkColorScheme = darkDynamic != null
            ? FlexColorScheme(colorScheme: darkDynamic).toScheme
            : const FlexColorScheme(
                    primary: Colors.orange, brightness: Brightness.dark)
                .toScheme;

        final lightTextTheme = TextTheme(
          displayLarge: mainTextStyle,
          displayMedium: mainTextStyle,
          displaySmall: mainTextStyle,
          headlineMedium: headerTextStyle.copyWith(
              color: lightColorScheme.tertiary, fontSize: 18),
          headlineSmall: headerTextStyle.copyWith(fontSize: 24),
          titleLarge: mainTextStyle,
          titleMedium: mainTextStyle,
          titleSmall: mainTextStyle,
          bodyLarge: mainTextStyle,
          bodyMedium: mainTextStyle,
          labelLarge: mainTextStyle,
          bodySmall: mainTextStyle,
          labelSmall: mainTextStyle,
        );

        final darkTextTheme = TextTheme(
          displayLarge: mainTextStyle,
          displayMedium: mainTextStyle,
          displaySmall: mainTextStyle,
          headlineMedium: headerTextStyle.copyWith(
              color: darkColorScheme.tertiary, fontSize: 18),
          headlineSmall: headerTextStyle.copyWith(fontSize: 24),
          titleLarge: mainTextStyle,
          titleMedium: mainTextStyle,
          titleSmall: mainTextStyle,
          bodyLarge: mainTextStyle,
          bodyMedium: mainTextStyle,
          labelLarge: mainTextStyle,
          bodySmall: mainTextStyle,
          labelSmall: mainTextStyle,
        );

        final lightTheme = FlexThemeData.light(
          useMaterial3: true,
          colorScheme: lightColorScheme,
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

        final lightThemeWithBoldText = lightTheme.copyWith(
          textTheme: lightTheme.textTheme.merge(lightTextTheme),
          splashColor: Colors.black.withOpacity(0.05),
          splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
          popupMenuTheme: PopupMenuThemeData(
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            color: FlexSchemeSurfaceColors.blend(
                    blendLevel: 32,
                    schemeColors:
                        FlexSchemeColor.from(primary: lightColorScheme.primary))
                .dialogBackground,
          ),
        );

        final darkTheme = FlexThemeData.dark(
          useMaterial3: true,
          colorScheme: darkColorScheme,
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

        final darkThemeWithBoldText = darkTheme.copyWith(
          textTheme: darkTheme.textTheme.merge(darkTextTheme),
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
                    schemeColors:
                        FlexSchemeColor.from(primary: darkColorScheme.primary))
                .dialogBackground,
          ),
        );

        return MaterialApp(
          title: 'Stops',
          themeMode: themeMode.value ?? ThemeMode.system,
          home: const HomePage(),
          theme: lightThemeWithBoldText,
          darkTheme: darkThemeWithBoldText,
        );
      },
    );
  }
}
