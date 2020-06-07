import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/bus_api.dart';
import '../utils/bus_service.dart';
import 'bus_stop.dart';
import 'bus_utils.dart';
import 'database_utils.dart';
import 'time_utils.dart';

class NotificationAPI {
  factory NotificationAPI() {
    if (!_isInitialized) {
      notifications.initialize(initializationSettings);
      _isInitialized = true;
    }

    return _singleton;
  }

  NotificationAPI._internal();

  static final NotificationAPI _singleton = NotificationAPI._internal();

  static FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  static const String _busArrivalChannelId = 'bus_arrival_channel';
  static const String _busArrivalChannelName = 'Bus arrival alerts';
  static const String _busArrivalChannelDescription = ' Alerts when buses arrive';

  static const String _busArrivalSilentChannelId = 'bus_arrival_silent_channel';
  static const String _busArrivalSilentChannelName = 'Silent bus arrivals';
  static const String _busArrivalSilentChannelDescription = ' Tracks bus arrival timings silently';

  static const AndroidInitializationSettings androidSettings = AndroidInitializationSettings(
      'ic_notification');
  static const Function onDidReceiveLocalNotification = null;
  static const IOSInitializationSettings iosSettings = IOSInitializationSettings(
      onDidReceiveLocalNotification: onDidReceiveLocalNotification);
  static const InitializationSettings initializationSettings = InitializationSettings(
      androidSettings, iosSettings);

  static const int notificationId = 0;
  static const int silentNotificationId = 1;

  static AndroidNotificationDetails silentAndroidDetails = const AndroidNotificationDetails(
    _busArrivalSilentChannelId,
    _busArrivalSilentChannelName,
    _busArrivalSilentChannelDescription,
    importance: Importance.Low,
    priority: Priority.Default,
    ongoing: true,
    autoCancel: false,
    progress: 50,
    showProgress: true,
    onlyAlertOnce: true,
    enableVibration: true,
    showWhen: false,
    styleInformation: BigTextStyleInformation(''),
  );

  static AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _busArrivalChannelId,
      _busArrivalChannelName,
      _busArrivalChannelDescription,
      timeoutAfter: 30000,
      priority: Priority.High,
      importance: Importance.Max,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(<int>[0, 30, 60, 30, 60, 30, 60, 800]),
  );
  static IOSNotificationDetails iosDetails = const IOSNotificationDetails();

  static NotificationDetails notificationDetails = NotificationDetails(
      androidDetails, iosDetails);
  static NotificationDetails silentNotificationDetails = NotificationDetails(
      silentAndroidDetails, iosDetails);

  static bool _isInitialized = false;

  static List<int> notificationIds = <int>[];

  /*
   * Schedules a notification to remind the user
   * of the bus' arrival, at the given time
   */
  Future<void> trackBus(BusStop stop, BusService bus, DateTime busArrivalTime) async {
    updateSilentNotification();
    final Duration timeDifference = busArrivalTime.difference(DateTime.now());
    Future<void>.delayed(timeDifference, () {
      // Un-follow bus
      unfollowBus(stop: stop.code, bus: bus.number);
    });
  }

  Future<void> untrackBus() async {
    await updateSilentNotification();
  }

  Future<void> updateSilentNotification() async {
    final List<DateTime> arrivalTimes = <DateTime>[];
    final List<String> followedBuses = await getFollowedBuses();

    if (followedBuses.isEmpty) {
      notifications.cancel(silentNotificationId);
      return;
    }

    for (String followedBus in followedBuses) {
      final List<String> tokens = followedBus.split(' ');
      final String stopCode = tokens[0];
      final String busNumber = tokens[1];

      final DateTime arrivalTime = await BusAPI().getArrivalTime(BusStop.withCode(stopCode), busNumber);
      arrivalTimes.add(arrivalTime);
    }

    final List<DateTime> notificationTimes = <DateTime>[];


    // Set up a list of times to update the notification
    for (DateTime arrivalTime in arrivalTimes) {
      // Now, sift out those times that have arrived.
      final int minutesLeftTillArrival = arrivalTime.getMinutesFromNow();

      if (minutesLeftTillArrival <= 1) {
        continue;
      }

      // Update the silent notification every minute, until and including when the bus arrives
      // in 1 min (during which it is removed from the silent list and brought to user attention)
      for (int minutesLeft = minutesLeftTillArrival - 1; minutesLeft >
          0; minutesLeft--) {
        final DateTime notificationTime = arrivalTime.subtract(
            Duration(minutes: minutesLeft));
        notificationTimes.add(notificationTime);
      }
    }

    // Show updated notification now
    final List<String> messageParts = <String>[];
    int busCount = 0;
    // Loop through un-arrived buses
    for (int i = 0; i < arrivalTimes.length; i++) {
      final int minutesLeft = arrivalTimes[i].getMinutesFromNow();
      final String followedBus = followedBuses[i];
      final List<String> tokens = followedBus.split(' ');
      final String busNumber = tokens[1];

      if (minutesLeft > 1) {
        busCount++;
        messageParts.add('$busNumber arrives in $minutesLeft min');
      }

      // When time left is 1 minute or less (as 1.1 min counts as 2 min), alert the user as the bus is arriving.
      notifications.schedule(
        notificationId,
        '$busNumber is arriving',
        'This notification will auto-dismiss in 1 min',
        arrivalTimes[i],
        notificationDetails,
        androidAllowWhileIdle: true,
      );
    }

    messageParts.sort((String a, String b) => compareBusNumber(a.split(' ')[0], b.split(' ')[0]));
    final String message = messageParts.join('\n');

    notifications.show(
      silentNotificationId,
      'Currently tracking $busCount ${busCount == 1 ? 'bus' : 'buses'}',
      message,
      silentNotificationDetails,
    );

    // Schedule the silent notification to update every time it needs to
    for (DateTime notificationTime in notificationTimes) {
      final List<String> messageParts = <String>[];
      int busCount = 0;

      // Loop through un-arrived buses
      for (int i = 0; i < arrivalTimes.length; i++) {
        final int minutesLeft = notificationTime.getMinutesUntil(arrivalTimes[i]);
        if (minutesLeft > 1) {
          final String followedBus = followedBuses[i];
          final List<String> tokens = followedBus.split(' ');
          final String busNumber = tokens[1];
          messageParts.add('$busNumber arrives in $minutesLeft min');
          busCount++;
        }
      }

      // If the last bus has arrived, the message will be empty
      if (messageParts.isEmpty) {
        Future<void>.delayed(notificationTime.difference(DateTime.now()), () {
          notifications.cancel(silentNotificationId);
        });
        continue;
      }

      messageParts.sort((String a, String b) => compareBusNumber(a.split(' ')[0], b.split(' ')[0]));
      final String message = messageParts.join('\n');

      notifications.schedule(
        silentNotificationId,
        'Currently tracking $busCount ${busCount == 1 ? 'bus' : 'buses'}',
        message,
        notificationTime,
        silentNotificationDetails,
        androidAllowWhileIdle: true,
      );
    }
  }


  Future<bool> isBusTracked(String busStop, String busServiceNumber) async {
    final List<PendingNotificationRequest> requests = await notifications.pendingNotificationRequests();
    for (PendingNotificationRequest request in requests){
      if (request.payload == '')
        continue;
      final String stop = request.payload.split(' ')[0];
      final String bus = request.payload.split(' ')[1];
      if (busStop == stop && busServiceNumber == bus)
        return true;
    }
    return false;
  }
}
