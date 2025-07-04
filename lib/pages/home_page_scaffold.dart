import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stops_sg/main.dart';
import 'package:stops_sg/routes/routes.dart';
import 'package:stops_sg/routes/routes_route.dart';
import 'package:stops_sg/routes/saved_route.dart';
import 'package:stops_sg/routes/search_route.dart';
import 'package:stops_sg/routes/settings_route.dart';

const defaultBottomNavIndex = 0;

class HomePageScaffold extends ConsumerStatefulWidget {
  const HomePageScaffold({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<HomePageScaffold> createState() => _HomePageScaffoldState();
}

final savedRouteLocation = SavedRoute().location;
final searchRouteLocation = SearchRoute().location;
final routesRouteLocation = RoutesRoute().location;
final settingsRouteLocation = SettingsRoute().location;

class _HomePageScaffoldState extends ConsumerState<HomePageScaffold> {
  int get _bottomNavIndex {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == savedRouteLocation) {
      return 0;
    } else if (location == searchRouteLocation) {
      return 1;
    } else if (location == routesRouteLocation) {
      return 2;
    } else if (location == settingsRouteLocation) {
      return 3;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Verify if the bottom line is still required
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleOf(context));

    return PopScope(
      canPop: _canPop,
      child: KeyboardDismissOnTap(
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _bottomNavIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (int index) {
              if (index == 0) {
                SavedRoute().go(context);
              } else if (index == 1) {
                SearchRoute().go(context);
              } else if (index == 2) {
                RoutesRoute().go(context);
              } else if (index == 3) {
                SettingsRoute().go(context);
              }
            },
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.bookmark_outline_rounded),
                selectedIcon: Icon(Icons.bookmark_rounded),
                label: 'Saved',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_outlined),
                selectedIcon: Icon(Icons.directions_rounded),
                label: 'Routes',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
          body: widget.child,
        ),
      ),
    );
  }

  bool get _canPop {
    if (_bottomNavIndex != defaultBottomNavIndex) {
      return false;
    }

    return true;
  }
}
