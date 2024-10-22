import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/main.dart';
import 'package:stops_sg/pages/fetch_data_page.dart';
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

class _HomePageScaffoldState extends ConsumerState<HomePageScaffold> {
  int _bottomNavIndex = defaultBottomNavIndex;

  Widget get body => widget.child;

  @override
  void initState() {
    super.initState();
    showSetupDialog();
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

  Future<void> showSetupDialog() async {
    final cacheProgress = await ref.read(cachedDataProgressProvider.future);
    final isFullyCached = cacheProgress == 1.0;

    if (!isFullyCached && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (context) => const FetchDataPage(isSetup: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Verify if the bottom line is still required
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleOf(context));

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: _onPopInvokedWithResult,
      child: KeyboardDismissOnTap(
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _bottomNavIndex,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (int index) {
              setState(() {
                _bottomNavIndex = index;
              });
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
                icon: Icon(Icons.bookmark_rounded),
                label: 'Saved',
              ),
              NavigationDestination(
                icon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_rounded),
                label: 'Routes',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
          body: body,
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

  void _onPopInvokedWithResult<T>(bool didPop, T? result) {
    if (didPop) {
      return;
    }

    if (_bottomNavIndex != defaultBottomNavIndex) {
      setState(() {
        _bottomNavIndex = defaultBottomNavIndex;
      });

      return;
    }
  }
}
