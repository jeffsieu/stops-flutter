import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/main.dart';
import 'package:stops_sg/routes/fade_page_route.dart';
import 'package:stops_sg/routes/fetch_data_page.dart';
import 'package:stops_sg/routes/routes_page.dart';
import 'package:stops_sg/routes/saved_page/saved_page.dart';
import 'package:stops_sg/routes/search_page/search_page.dart';
import 'package:stops_sg/routes/settings_page.dart';

const defaultBottomNavIndex = 0;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _bottomNavIndex = defaultBottomNavIndex;

  Widget get body {
    if (_bottomNavIndex == 0) {
      return const SavedPage();
    } else if (_bottomNavIndex == 1) {
      return SearchPage();
    } else if (_bottomNavIndex == 2) {
      return const RoutesPage();
    } else if (_bottomNavIndex == 3) {
      return const SettingsPage();
    }

    throw Exception('Invalid index: $_bottomNavIndex');
  }

  @override
  void initState() {
    super.initState();
    showSetupDialog();
    if (Platform.isAndroid || Platform.isIOS) {
      const quickActions = QuickActions();
      quickActions.initialize((String shortcutType) {
        if (shortcutType == 'action_search') {
          _pushSearchRoute();
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

  void _pushSearchRoute() {
    final Widget page = SearchPage();
    final Route<void> route = FadePageRoute<void>(child: page);
    Navigator.push(context, route);
  }
}
