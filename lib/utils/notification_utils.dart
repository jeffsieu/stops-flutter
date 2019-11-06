import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'database_utils.dart';

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
  static const String _busArrivalChannelName = 'Bus arrivals';
  static const String _busArrivalChannelDescription = ' Send notifications about bus arrivals';

  static const AndroidInitializationSettings androidSettings = AndroidInitializationSettings(
      'mipmap/ic_launcher');
  static const Function onDidReceiveLocalNotification = null;
  static const IOSInitializationSettings iosSettings = IOSInitializationSettings(
      onDidReceiveLocalNotification: onDidReceiveLocalNotification);
  static const InitializationSettings initializationSettings = InitializationSettings(
      androidSettings, iosSettings);

  static AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _busArrivalChannelId,
      _busArrivalChannelName,
      _busArrivalChannelDescription,
      importance: Importance.Max,
      priority: Priority.High,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(<int>[0, 30, 60, 30, 60, 30, 60, 800]),
  );
  static IOSNotificationDetails iosDetails = IOSNotificationDetails();
  static NotificationDetails notificationDetails = NotificationDetails(
      androidDetails, iosDetails);

  static bool _isInitialized = false;

  static List<int> notificationIds = <int>[];

  /*
   * Schedules a notification to remind the user
   * of the bus' arrival, at the given time
   *
   * Returns the id of the scheduled notification
   */
  Future<int> scheduleNotification(String stop, String bus, DateTime notificationTime) async {
    int notificationId = 0;
    int index = 0;

    for (int id in notificationIds) {
      if (notificationId == id) {
        notificationId++;
      } else {
        break;
      }
      index++;
    }

    notificationIds.insert(index, notificationId);

    notifications.schedule(
        notificationId,
        '$bus arrives in about 30s',
        'This notification will auto-dismiss in 1 min',
        notificationTime,
        notificationDetails,
        androidAllowWhileIdle: true
    );

    BusFollowStatusListener listener;
    listener = (String stop, String bus, bool isFollowed) {
      if (!isFollowed) {
        notifications.cancel(notificationId);
        notificationIds.remove(notificationId);
      }
      removeBusFollowStatusListener(stop, bus, listener);
    };
    addBusFollowStatusListener(stop, bus, listener);
    
    final Duration timeDifference = notificationTime.difference(DateTime.now());

    Future<void>.delayed(timeDifference + const Duration(minutes: 1), () {
      // Auto-dismiss notification after 1 minute
      notifications.cancel(notificationId);
      notificationIds.remove(notificationId);
    });

    Future<void>.delayed(timeDifference, () {
      // Un-follow bus
      removeBusFollowStatusListener(stop, bus, listener);
      unfollowBus(stop: stop, bus: bus);
    });

    return notificationId;
  }
}