import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/routes/fetch_data_page.dart';
import 'package:stops_sg/routes/scan_card_page.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SettingsPage extends ConsumerStatefulWidget {
  static const String _kThemeLabelSystem = 'System';
  static const String _kThemeLabelLight = 'Light';
  static const String _kThemeLabelDark = 'Dark';

  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() {
    return SettingsPageState();
  }
}

class SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(selectedThemeModeProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Settings',
                style: Theme.of(context).textTheme.displaySmall),
          ),
          _buildThemeTile(themeMode.value),
          _buildScanCardTile(),
          _buildRefreshDataTile(),
          _buildAboutTile(),
        ],
      ),
    );
  }

  Widget _buildThemeTile(ThemeMode? themeMode) {
    return ListTile(
      title: const Text('Theme'),
      subtitle: Text(_getThemeLabel(themeMode)),
      leading: const Icon(Icons.brush_rounded),
      onTap: () {
        showDialog<ThemeMode>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Choose theme'),
                contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<ThemeMode>(
                      title: Text(_getThemeLabel(ThemeMode.system)),
                      value: ThemeMode.system,
                      groupValue: themeMode,
                      onChanged: _onThemeModeChanged,
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text(SettingsPage._kThemeLabelLight),
                      value: ThemeMode.light,
                      groupValue: themeMode,
                      onChanged: _onThemeModeChanged,
                    ),
                    RadioListTile<ThemeMode>(
                      title: const Text(SettingsPage._kThemeLabelDark),
                      value: ThemeMode.dark,
                      groupValue: themeMode,
                      onChanged: _onThemeModeChanged,
                    ),
                  ],
                ),
              );
            });
      },
    );
  }

  Widget _buildScanCardTile() {
    return ListTile(
      title: const Text('Scan card value'),
      leading: const Icon(Icons.credit_card_rounded),
      onTap: () {
        const Widget page = ScanCardPage();
        final Route<void> route =
            MaterialPageRoute<void>(builder: (BuildContext context) => page);
        Navigator.push(context, route);
      },
    );
  }

  Widget _buildAboutTile() {
    return ListTile(
      title: const Text('About'),
      leading: const Icon(Icons.info_outline_rounded),
      onTap: () async {
        final packageInfo = await PackageInfo.fromPlatform();
        final appName = packageInfo.appName;
        final appVersion = packageInfo.version;

        if (!context.mounted) {
          return;
        }

        showAboutDialog(
          context: context,
          applicationIcon: Image.asset(
            'assets/images/icon/icon_squircle.png',
            width: IconTheme.of(context).size! * 2,
            height: IconTheme.of(context).size! * 2,
          ),
          applicationName: appName,
          applicationVersion: appVersion,
          children: [
            RichText(
              text: TextSpan(
                text: 'Made by ',
                style: Theme.of(context).textTheme.bodyMedium,
                children: <TextSpan>[
                  TextSpan(
                    text: 'Jeff Sieu',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        const url = 'https://github.com/jeffsieu';
                        if (await canLaunchUrlString(url)) {
                          await launchUrlString(
                            url,
                          );
                        }
                      },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRefreshDataTile() {
    return ListTile(
      title: const Text('Refresh cached data'),
      subtitle: const Text('Select if there are missing stops/services'),
      leading: const Icon(Icons.update_rounded),
      onTap: () {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const FetchDataPage(isSetup: false);
          },
        );
      },
    );
  }

  String _getThemeLabel(ThemeMode? themeMode) {
    switch (themeMode) {
      case ThemeMode.system:
        final brightness = MediaQuery.of(context).platformBrightness;
        final brightnessLabel = brightness == Brightness.light
            ? SettingsPage._kThemeLabelLight
            : SettingsPage._kThemeLabelDark;
        return '${SettingsPage._kThemeLabelSystem} ($brightnessLabel)';
      case ThemeMode.light:
        return SettingsPage._kThemeLabelLight;
      case ThemeMode.dark:
        return SettingsPage._kThemeLabelDark;
      default:
        return SettingsPage._kThemeLabelSystem;
    }
  }

  Future<void> _onThemeModeChanged(ThemeMode? themeMode) async {
    if (themeMode == null) {
      return;
    }

    await ref.read(selectedThemeModeProvider.notifier).setThemeMode(themeMode);

    if (context.mounted) {
      Navigator.pop(context);
    }
  }
}
