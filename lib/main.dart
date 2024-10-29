import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/routes/router.dart';
import 'package:stops_sg/routes/routes.dart';
import 'package:stops_sg/routes/search_route.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: StopsApp()));
}

class StopsApp extends HookConsumerWidget {
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

    useEffect(() {
      _initializeQuickActions(context);
      return null;
    }, []);

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

        // final darkTheme = FlexThemeData.dark(
        //   useMaterial3: true,
        //   colorScheme: darkColorScheme,
        //   fontFamily: GoogleFonts.nunitoSans().fontFamily,
        //   blendLevel: 16,
        //   subThemesData: const FlexSubThemesData(
        //     inputDecoratorBorderType: FlexInputBorderType.underline,
        //     inputDecoratorRadius: 8,
        //     inputDecoratorIsFilled: false,
        //   ),
        //   appBarStyle: FlexAppBarStyle.surface,
        //   tabBarStyle: FlexTabBarStyle.forBackground,
        //   surfaceMode: FlexSurfaceMode.highBackgroundLowScaffold,
        // );
        final darkTheme = ThemeData.dark().copyWith(
            colorScheme: darkDynamic ??
                ColorScheme.fromSeed(
                  seedColor: Colors.orange,
                  brightness: Brightness.dark,
                  dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
                ));

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

        final router = ref.watch(routerProvider);

        return MaterialApp.router(
          title: 'Stops',
          themeMode: themeMode.value ?? ThemeMode.system,
          theme: lightThemeWithBoldText,
          darkTheme: darkThemeWithBoldText,
          routerConfig: router,
        );
      },
    );
  }

  void _initializeQuickActions(BuildContext context) {
    if (Platform.isAndroid || Platform.isIOS) {
      const quickActions = QuickActions();
      quickActions.initialize((String shortcutType) {
        if (shortcutType == 'action_search') {
          SearchRoute().go(context);
        }
      });
      quickActions.setShortcutItems(<ShortcutItem>[
        const ShortcutItem(
            type: 'action_search',
            localizedTitle: 'Search',
            icon: 'ic_shortcut_search'),
      ]);
    }
  }
}
