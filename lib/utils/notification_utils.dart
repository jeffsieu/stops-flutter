import 'dart:typed_data';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/bus.dart';
import 'bus_api.dart';
import 'bus_utils.dart';
import 'database_utils.dart';
import 'time_utils.dart';

FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

const String _busArrivalChannelId = 'bus_arrival_channel';
const String _busArrivalChannelName = 'Bus arrival alerts';
const String _busArrivalChannelDescription = ' Alerts when buses arrive';

const String _busArrivalSilentChannelId = 'bus_arrival_silent_channel';
const String _busArrivalSilentChannelName = 'Silent bus arrivals';
const String _busArrivalSilentChannelDescription =
    ' Tracks bus arrival timings silently';

const int notificationId = 0;
const int silentNotificationId = 1;
const int alarmManagerTaskId = 0;

const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('ic_notification');
const Future<dynamic> Function(int, String?, String?, String?)?
    onDidReceiveLocalNotification = null;
const DarwinInitializationSettings darwinSettings =
    DarwinInitializationSettings(
        onDidReceiveLocalNotification: onDidReceiveLocalNotification);
const InitializationSettings initializationSettings =
    InitializationSettings(android: androidSettings, iOS: darwinSettings);

AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
  _busArrivalChannelId,
  _busArrivalChannelName,
  channelDescription: _busArrivalChannelDescription,
  timeoutAfter: 30000,
  priority: Priority.high,
  importance: Importance.max,
  enableVibration: true,
  vibrationPattern: Int64List.fromList(<int>[0, 30, 60, 30, 60, 30, 60, 800]),
);
DarwinNotificationDetails darwinDetails = const DarwinNotificationDetails();
NotificationDetails notificationDetails =
    NotificationDetails(android: androidDetails, iOS: darwinDetails);

bool _isInitialized = false;

/*
 * Updates the live notification with current bus timing info,
 * and displays an alert notification if any buses are arriving.
 *
 * Calls itself when the notifications need to be updated (usually
 * about a minute later), and continues doing so until the last
 * tracked bus has arrived. Then, it will cancel the live notification
 * and stop calling itself.
 */
Future<void> updateNotifications() async {
  if (!_isInitialized) {
    notifications.initialize(initializationSettings);
    _isInitialized = true;
  }
  final arrivalTimes = <DateTime>[];
  final followedBuses = List<Bus>.from(await getFollowedBuses());
  final shortMessageParts = <String>[];
  final longMessageParts = <String>[];

  DateTime? earliestNotificationTime;

  var busCount = 0;
  int? leastMinutesLeft;
  for (var followedBus in followedBuses) {
    final busNumber = followedBus.busService.number;
    final stopCode = followedBus.busStop.code;

    // TODO: Fix arrival Time
    // final arrivalTime =
    //     await BusAPI().getArrivalTime(followedBus.busStop, busNumber);
    final DateTime? arrivalTime = null;

    var minutesLeft = 0;
    if (arrivalTime != null) {
      arrivalTimes.add(arrivalTime);
      minutesLeft = arrivalTime.getMinutesFromNow();
    } else {
      // No more bus arrival timings; assume that bus has arrived.
    }

    if (minutesLeft >= 2) {
      final nextNotificationTime =
          arrivalTime!.subtract(Duration(minutes: minutesLeft - 1));

      if (earliestNotificationTime == null ||
          earliestNotificationTime.isAfter(nextNotificationTime)) {
        earliestNotificationTime = nextNotificationTime;
      }
      if (leastMinutesLeft == null || minutesLeft < leastMinutesLeft) {
        leastMinutesLeft = minutesLeft;
      }
      shortMessageParts.add('$busNumber ($minutesLeft min)');
      longMessageParts.add('$busNumber - $minutesLeft min');
      busCount++;
    } else {
      // Bus arrived
      notifications.show(
        notificationId,
        '$busNumber is arriving',
        'This notification will auto-dismiss in 1 min',
        notificationDetails,
      );
      unfollowBus(stop: stopCode, bus: busNumber);
    }
  }

  if (busCount == 0) {
    notifications.cancel(silentNotificationId);
    return;
  }

  longMessageParts.sort((String a, String b) =>
      compareBusNumber(a.split(' ')[0], b.split(' ')[0]));
  final message = longMessageParts.join('\n');

  final silentAndroidDetails = AndroidNotificationDetails(
    _busArrivalSilentChannelId,
    _busArrivalSilentChannelName,
    channelDescription: _busArrivalSilentChannelDescription,
    importance: Importance.low,
    priority: Priority.high,
    ongoing: true,
    autoCancel: false,
    progress: 50,
    showProgress: true,
    onlyAlertOnce: true,
    enableVibration: true,
    showWhen: false,
    styleInformation: BigTextStyleInformation(message),
  );

  final silentNotificationDetails =
      NotificationDetails(android: silentAndroidDetails, iOS: darwinDetails);

  notifications.show(
    silentNotificationId,
    'Next bus - $leastMinutesLeft min',
    shortMessageParts.join(' · '),
    silentNotificationDetails,
  );

  if (earliestNotificationTime == null) return;
  await AndroidAlarmManager.initialize();

  // Cancel any scheduled notification update
  await AndroidAlarmManager.cancel(alarmManagerTaskId);
  await AndroidAlarmManager.oneShotAt(
      DateTime.now(), alarmManagerTaskId, updateNotifications);
}
