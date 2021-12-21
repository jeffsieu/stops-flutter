import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bus.dart';
import '../models/bus_service.dart';
import '../models/bus_service_route.dart';
import '../models/bus_service_with_routes.dart';
import '../models/bus_stop.dart';
import '../models/bus_stop_with_distance.dart';
import '../models/bus_stop_with_pinned_services.dart';
import '../models/user_route.dart';
import 'bus_api.dart';
import 'database.dart';
import 'notification_utils.dart';

/* Called when a bus stop is modified */
typedef BusStopChangeListener = void Function(BusStop busStop);
/* Called when bus is followed/un-followed */
typedef BusFollowStatusListener = void Function(
    String stop, String bus, bool isFollowed);
/* Called when bus service is pinned/unpinned for a bus stop*/
typedef BusPinStatusListener = void Function(
    String stop, String bus, bool isPinned);

const int defaultRouteId = -1;
const String defaultRouteName = 'Home';
const String _themeModeKey = 'THEME_OPTION';
const String _isBusFollowedKey = 'BUS_FOLLOW';
const String _busTimingsKey = 'BUS_TIMINGS';
const String _busServiceSkipNumberKey = 'BUS_SERVICE_SKIP';
const String _searchHistoryKey = 'SEARCH_HISTORY';
const String _areBusStopsCachedKey = 'BUS_STOP_CACHE';
const String _areBusServicesCachedKey = 'BUS_SERVICE_CACHE';
const String _areBusServiceRoutesCachedKey = 'BUS_ROUTE_CACHE';

final Map<String, List<BusFollowStatusListener>> _busFollowStatusListeners =
    <String, List<BusFollowStatusListener>>{};
final Map<BusStop, List<BusStopChangeListener>> _busStopListeners =
    <BusStop, List<BusStopChangeListener>>{};
final StreamController<List<Bus>> _followedBusesController =
    StreamController<List<Bus>>.broadcast(onListen: updateFollowedBusesStream);
final Map<UserRoute, StreamController<List<BusStopWithPinnedServices>>>
    _userRouteBusStopStreamControllers =
    <UserRoute, StreamController<List<BusStopWithPinnedServices>>>{};

final StopsDatabase _database = StopsDatabase.create();

// Future<Database> _accessDatabase() async {
//   return openDatabase(
// join(await getDatabasesPath(), 'busstop_database.db'),
// onUpgrade: (Database db, int oldVersion, int newVersion) async {
//   if (oldVersion == 1 && newVersion == 2) {
//     final Batch batch = db.batch();
//     batch.execute('DROP TABLE pinned_bus_service');
//     batch.execute('DROP TABLE bus_stop');
//     await batch.commit(noResult: true);
//     await _initializeDatabase(db);

//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     await prefs.setBool(_areBusStopsCachedKey, false);
//   }
// },
// onCreate: (Database db, int version) async {
//   await _initializeDatabase(db);
// },
// onConfigure: (Database db) async {
//     await db.execute('PRAGMA foreign_keys = ON');
//   },
//   version: 2,
// );
// }

// Future<void> _initializeDatabase(Database db) async {
//   final Batch batch = db.batch();
//   batch.execute('CREATE TABLE bus_stop('
//       'code VARCHAR(5) PRIMARY KEY,'
//       'displayName TEXT,'
//       'defaultName TEXT,'
//       'road TEXT,'
//       'latitude DOUBLE,'
//       'longitude DOUBLE)');
//   batch.execute('CREATE TABLE bus_service('
//       'number VARCHAR(4) PRIMARY KEY,'
//       'operator TEXT)');
//   batch.execute('CREATE TABLE bus_route('
//       'serviceNumber VARCHAR(4) NOT NULL,'
//       'direction INTEGER NOT NULL,'
//       'busStopCode VARCHAR(5) NOT NULL,'
//       'distance DOUBLE,'
//       'PRIMARY KEY (serviceNumber, direction, busStopCode))');
//   batch.execute('CREATE TABLE user_route('
//       'id INTEGER PRIMARY KEY AUTOINCREMENT,'
//       'name TEXT,'
//       'color INTEGER,'
//       'position INTEGER NOT NULL)');
//   batch.execute('CREATE TABLE user_route_bus_stop('
//       'routeId INTEGER DEFAULT -1,'
//       'busStopCode VARCHAR(5),'
//       'position INTEGER NOT NULL,'
//       'PRIMARY KEY (routeId, busStopCode),'
//       'FOREIGN KEY (routeId) REFERENCES user_route(id) ON DELETE CASCADE,'
//       'FOREIGN KEY (busStopCode) REFERENCES bus_stop(code))');
//   batch.execute('CREATE TABLE pinned_bus_service('
//       'routeId INTEGER,'
//       'busStopCode VARCHAR(5),'
//       'busServiceNumber VARCHAR(4),'
//       'PRIMARY KEY (routeId, busStopCode, busServiceNumber),'
//       'FOREIGN KEY (routeId, busStopCode) REFERENCES user_route_bus_stop(routeId, busStopCode) ON DELETE CASCADE,'
//       'FOREIGN KEY (busServiceNumber) REFERENCES bus_service(number))');
//   await batch.commit(noResult: true);
//   await db.insert('user_route', <String, dynamic>{
//     'id': defaultRouteId,
//     'name': defaultRouteName,
//     'color': 0,
//     'position': -1
//   });
// }

Future<ThemeMode> getThemeMode() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final int themeModeIndex =
      prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
  return ThemeMode.values[themeModeIndex];
}

Future<void> setThemeMode(ThemeMode themeMode) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setInt(_themeModeKey, themeMode.index);
}

Future<List<BusStopWithDistance>> getNearestBusStops(
    double latitude, double longitude, String busServiceFilter) async {
  return await _database.getNearestBusStops(
      latitude, longitude, busServiceFilter);
  // const String distanceQuery =
  //     '(latitude - ?) * (latitude - ?) + (longitude - ?) * (longitude - ?) AS distance';

  // final int? busService = int.tryParse(busServiceFilter);
  // if (busService == null && busServiceFilter.isNotEmpty) {
  //   return <BusStopWithDistance>[];
  // }

  // final String filter = busServiceFilter.isEmpty
  //     ? ''
  //     : 'WHERE code IN (SELECT busStopCode from bus_route WHERE serviceNumber = $busServiceFilter)';

  // final String fullQuery =
  //     'SELECT *, $distanceQuery FROM bus_stop $filter ORDER BY distance';
  // final List<String> args = <String>[
  //   '$latitude',
  //   '$latitude',
  //   '$longitude',
  //   '$longitude',
  // ];

  // final Database database = await _accessDatabase();
  // final List<Map<String, dynamic>> results =
  //     await database.rawQuery(fullQuery, args);

  // Generate list of bus stops
//   return results.map((Map<String, dynamic> result) {
//     final BusStop busStop = BusStop.fromMap(result);
//     final double distanceMeters = const latlong.Distance().as(
//         latlong.LengthUnit.Meter,
//         latlong.LatLng(
//             result['latitude'] as double, result['longitude'] as double),
//         latlong.LatLng(latitude, longitude));
//     return BusStopWithDistance(busStop, distanceMeters);
//   }).toList();
}

Future<void> updateBusStop(BusStop busStop) async {
  await _database.updateBusStop(busStop);
  // final Database database = await _accessDatabase();
  // await database.update('bus_stop', busStop.toMap(),
  //     where: 'code = ?', whereArgs: <String>[busStop.code]);
}

Stream<List<BusStopWithPinnedServices>> routeBusStopsStream(UserRoute route) {
  if (!_userRouteBusStopStreamControllers.containsKey(route)) {
    _userRouteBusStopStreamControllers[route] =
        StreamController<List<BusStopWithPinnedServices>>.broadcast();
  }
  getBusStopsInRoute(route).then((List<BusStopWithPinnedServices> busStops) {
    _userRouteBusStopStreamControllers[route]!.add(busStops);
  });
  return _userRouteBusStopStreamControllers[route]!.stream;
}

Future<void> _updateRouteBusStopsStream(UserRoute route) async {
  _userRouteBusStopStreamControllers.putIfAbsent(route,
      () => StreamController<List<BusStopWithPinnedServices>>.broadcast());
  _userRouteBusStopStreamControllers[route]!
      .add(await getBusStopsInRoute(route));
}

Future<List<BusStopWithPinnedServices>> getBusStopsInRoute(
    UserRoute route) async {
  // final Database database = await _accessDatabase();
  // final List<Map<String, dynamic>> result = await database.rawQuery(
  //     'SELECT * FROM bus_stop JOIN user_route_bus_stop ON code = busStopCode WHERE routeId = ${route.id} ORDER BY position');
  // final List<BusStop> busStops = List<BusStop>.generate(
  //     result.length, (int i) => BusStop.fromMap(result[i]));

  final List<BusStop> busStops = await _database.getBusStopsInRoute(route);
  final List<BusStopWithPinnedServices> busStopsWithPinnedServices =
      <BusStopWithPinnedServices>[];

  for (BusStop busStop in busStops) {
    final List<BusService> pinnedServices =
        await getPinnedServicesIn(busStop, route);
    busStopsWithPinnedServices
        .add(BusStopWithPinnedServices.fromBusStop(busStop, pinnedServices));
  }

  return busStopsWithPinnedServices;
}

Future<void> addBusStopToRoute(
    BusStop busStop, UserRoute route, BuildContext context) async {
  // final Database database = await _accessDatabase();
  // final int newBusStopPosition = (await database.rawQuery(
  //         'SELECT COUNT(busStopCode) as count FROM user_route_bus_stop WHERE routeId = $defaultRouteId'))[
  //     0]['count'] as int;
  // final Map<String, dynamic> entry = <String, dynamic>{
  //   'routeId': route.id,
  //   'busStopCode': busStop.code,
  //   'position': newBusStopPosition,
  // };
  // await database.insert('user_route_bus_stop', entry);
  await _database.addBusStopToRoute(busStop, route);

  _updateBusStopListeners(busStop);
  await _updateRouteBusStopsStream(route);

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(
        'Pinned ${busStop.displayName} to ${route == UserRoute.home ? "home" : route.name}'),
//    action: SnackBarAction(
//      label: 'SHOW ME',
//      onPressed: () {
//        Navigator.popUntil(context, ModalRoute.withName('/home'));
//      },
//    ),
  ));
}

Future<void> removeBusStopFromRoute(
    BusStop busStop, UserRoute route, BuildContext context) async {
  // final Database database = await _accessDatabase();
  // final int position = (await database.query('user_route_bus_stop',
  //         where: 'routeId = ? AND busStopCode = ?',
  //         whereArgs: <dynamic>[route.id, busStop.code]))
  //     .first['position'] as int;
  // await database.delete('user_route_bus_stop',
  //     where: 'routeId = ? AND busStopCode = ?',
  //     whereArgs: <dynamic>[route.id, busStop.code]);
  // await database.rawUpdate(
  //     'UPDATE user_route_bus_stop SET position = position - 1 WHERE routeId = ? AND position > ?',
  //     <dynamic>[route.id, position]);
  await _database.removeBusStopFromRoute(busStop, route);

  _updateBusStopListeners(busStop);
  await _updateRouteBusStopsStream(route);

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(
        'Unpinned ${busStop.displayName} from ${route == UserRoute.home ? "home" : route.name}'),
    action: SnackBarAction(
      label: 'UNDO',
      onPressed: () {
        addBusStopToRoute(busStop, route, context);
      },
    ),
  ));
}

Future<bool> isBusStopInRoute(BusStop busStop, UserRoute route) async {
  return await _database.isBusStopInRoute(busStop, route);
  // final Database database = await _accessDatabase();
  // final List<Map<String, dynamic>> result = await database.query(
  //     'user_route_bus_stop',
  //     where: 'routeId = ? AND busStopCode = ?',
  //     whereArgs: <dynamic>[route.id, busStop.code]);
  // return result.isNotEmpty;
}

Future<void> storeUserRoute(UserRoute route) async {
  await _database.storeUserRoute(route);
  // final Database database = await _accessDatabase();
  // final int newRoutePosition =
  //     ((await database.rawQuery('SELECT COUNT(*) as count FROM user_route'))[0]
  //             ['count'] as int) -
  //         1;
  // final Map<String, dynamic> routeEntry = route.toMap()
  //   ..putIfAbsent('position', () => newRoutePosition);
  // final int newRouteId = await database.insert('user_route', routeEntry);
  // final Batch batch = database.batch();
  // int position = 0;
  // for (BusStop busStop in route.busStops) {
  //   final Map<String, dynamic> busStopEntry = <String, dynamic>{
  //     'routeId': newRouteId,
  //     'busStopCode': busStop.code,
  //     'position': position,
  //   };
  //   batch.insert('user_route_bus_stop', busStopEntry);
  //   position++;
  // }
  // await batch.commit(noResult: true);
}

Future<void> updateUserRoute(UserRoute route) async {
  await _database.updateUserRoute(route);
  // assert(route.id != null);
  // final Database database = await _accessDatabase();
  // final Map<String, dynamic> routeEntry = route.toMap();
  // await database.update('user_route', routeEntry,
  //     where: 'id = ?', whereArgs: <int>[route.id!]);
  // final List<Map<String, dynamic>> oldBusStops =
  //     List<Map<String, dynamic>>.from(await database.query(
  //         'user_route_bus_stop',
  //         where: 'routeId = ?',
  //         whereArgs: <int>[route.id!]));

  // for (BusStop busStop in route.busStops) {
  //   oldBusStops
  //       .removeWhere((dynamic stop) => stop['busStopCode'] == busStop.code);
  // }

  // // Delete removed bus stops from database
  // final Batch deleteBatch = database.batch();
  // for (dynamic deletedBusStop in oldBusStops) {
  //   deleteBatch.delete('user_route_bus_stop',
  //       where: 'routeId = ? AND busStopCode = ?',
  //       whereArgs: <dynamic>[route.id, deletedBusStop['busStopCode']]);
  // }
  // deleteBatch.commit(noResult: true);

  // final Batch batch = database.batch();
  // int position = 0;
  // for (BusStop busStop in route.busStops) {
  //   final Map<String, dynamic> busStopEntry = <String, dynamic>{
  //     'routeId': route.id,
  //     'busStopCode': busStop.code,
  //     'position': position,
  //   };
  //   batch.insert('user_route_bus_stop', busStopEntry,
  //       conflictAlgorithm: ConflictAlgorithm.ignore);
  //   batch.update('user_route_bus_stop', busStopEntry,
  //       where: 'routeId = ? AND busStopCode = ?',
  //       whereArgs: <dynamic>[route.id, busStop.code]);
  //   position++;
  // }
  // await batch.commit(noResult: true);
  await _updateRouteBusStopsStream(route);
}

Future<List<UserRoute>> getUserRoutes() async {
  // final Database database = await _accessDatabase();
  // final List<Map<String, dynamic>> result = await database.query('user_route',
  //     where: 'id != $defaultRouteId', orderBy: 'position');
  // final List<UserRoute> routes =
  //     result.map<UserRoute>(UserRoute.fromMap).toList();
  final List<UserRoute> routes = await _database.getUserRoutes();
  for (UserRoute route in routes) {
    final List<BusStop> busStops = await getBusStopsInRoute(route);
    // final List<Map<String, dynamic>> busStops = await database.query(
    //     'user_route_bus_stop',
    //     where: 'routeId = ?',
    //     whereArgs: <int>[route.id!],
    //     orderBy: 'position');
    // for (Map<String, dynamic> entry in busStops) {
    //   final BusStop busStop =
    //       await getCachedBusStopWithCode(entry['busStopCode'] as String);
    //   final List<BusService> pinnedServices =
    //       await getPinnedServicesIn(busStop, route);
    //   final BusStopWithPinnedServices busStopWithPinnedServices =
    //       BusStopWithPinnedServices.fromBusStop(busStop, pinnedServices);
    //   route.busStops.add(busStopWithPinnedServices);
    // }
    for (BusStop busStop in busStops) {
      final List<BusService> pinnedServices =
          await getPinnedServicesIn(busStop, route);
      final BusStopWithPinnedServices busStopWithPinnedServices =
          BusStopWithPinnedServices.fromBusStop(busStop, pinnedServices);
      route.busStops.add(busStopWithPinnedServices);
    }
  }
  return routes;
}

Future<void> deleteUserRoute(UserRoute userRoute) async {
  await _database.deleteUserRoute(userRoute);
  // final Database database = await _accessDatabase();
  // final int position = (await database.query('user_route',
  //         where: 'id = ?', whereArgs: <int>[userRoute.id!]))
  //     .first['position'] as int;
  // await database
  //     .delete('user_route', where: 'id = ?', whereArgs: <int>[userRoute.id!]);
  // await database.rawUpdate(
  //     'UPDATE user_route SET position = position - 1 WHERE position > ?',
  //     <int>[position]);
}

Future<void> moveUserRoutePosition(int from, int to) async {
  await _database.moveUserRoutePosition(from, to);
  // final Database database = await _accessDatabase();
  // final int direction = (to - from).sign;
  // final Batch batch = database.batch();

  // // Change from's position to -2
  // batch.update('user_route', <String, dynamic>{'position': -2},
  //     where: 'position = ?', whereArgs: <int>[from]);

  // // Shift everything after 'from' one step closer to 'from'
  // for (int i = from; i != to; i += direction) {
  //   batch.update('user_route', <String, dynamic>{'position': i},
  //       where: 'position = ?', whereArgs: <int>[i + direction]);
  // }

  // // Change from's position to to
  // batch.update('user_route', <String, dynamic>{'position': to},
  //     where: 'position = ?', whereArgs: <int>[-2]);
  // await batch.commit(noResult: true);
}

Future<void> moveBusStopPositionInRoute(
    int from, int to, UserRoute route) async {
  await _database.moveBusStopPositionInRoute(from, to, route);
  // final Database database = await _accessDatabase();
  // final Batch batch = database.batch();
  // final int direction = (to - from).sign;

  // // Change from's position to -2
  // batch.update('user_route_bus_stop', <String, dynamic>{'position': -2},
  //     where: 'routeId = ? AND position = ?',
  //     whereArgs: <dynamic>[route.id, from]);

  // // Shift everything after 'from' one step closer to 'from'
  // for (int i = from; i != to; i += direction) {
  //   batch.update('user_route_bus_stop', <String, dynamic>{'position': i},
  //       where: 'routeId = ? AND position = ?',
  //       whereArgs: <dynamic>[route.id, i + direction]);
  // }

  // // Change from's position to to
  // batch.update('user_route_bus_stop', <String, dynamic>{'position': to},
  //     where: 'routeId = ? AND position = ?',
  //     whereArgs: <dynamic>[route.id, -2]);
  // await batch.commit(noResult: true);
  // // await _updateRouteBusStopsStream(route);
}

void registerBusStopListener(BusStop busStop, BusStopChangeListener listener) {
  _busStopListeners.putIfAbsent(busStop, () => <BusStopChangeListener>[]);
  _busStopListeners[busStop]!.add(listener);
}

void unregisterBusStopListener(
    BusStop busStop, BusStopChangeListener listener) {
  if (_busStopListeners.containsKey(busStop)) {
    final List<BusStopChangeListener> listeners = _busStopListeners[busStop]!;
    listeners.remove(listener);
    if (listeners.isEmpty) _busStopListeners.remove(busStop);
  }
}

void _updateBusStopListeners(BusStop busStop) {
  if (_busStopListeners[busStop] != null) {
    for (BusStopChangeListener listener in _busStopListeners[busStop]!) {
      listener(busStop);
    }
  }
}

Future<void> followBus(
    {required String stop,
    required String bus,
    required DateTime arrivalTime}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(_isBusFollowedKey)) {
    prefs.setStringList(_isBusFollowedKey, <String>[]);
  }
  if (!prefs.containsKey(_busTimingsKey)) {
    prefs.setStringList(_busTimingsKey, <String>[]);
  }

  final List<String> followedBuses = prefs.getStringList(_isBusFollowedKey)!;
  final List<String> followedBusTimings = prefs.getStringList(_busTimingsKey)!;

  assert(followedBuses.length == followedBusTimings.length);

  final String key = _followerKey(stop, bus);
  followedBuses.add(key);
  followedBusTimings.add(arrivalTime.toIso8601String());

  prefs.setStringList(_isBusFollowedKey, followedBuses);
  prefs.setStringList(_busTimingsKey, followedBusTimings);

  // Update followed buses stream
  updateFollowedBusesStream();
  updateNotifications();

  // To allow removal of listener while in iteration
  // (as it is common behaviour for a listener to
  // detach itself after a certain call)
  if (_busFollowStatusListeners[key] == null) return;
  final List<BusFollowStatusListener> listeners =
      List<BusFollowStatusListener>.from(_busFollowStatusListeners[key]!);

  for (BusFollowStatusListener listener in listeners) {
    listener(stop, bus, true);
  }
}

Future<void> updateFollowedBusesStream() async {
  _followedBusesController.add(await getFollowedBuses());
}

Future<List<Bus>> getFollowedBuses() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(_isBusFollowedKey) ||
      !prefs.containsKey(_busTimingsKey)) {
    return <Bus>[];
  }
  final List<Bus> followedBuses = <Bus>[];
  final List<String> followedBusesRaw = prefs.getStringList(_isBusFollowedKey)!;
  final List<String> followedBusTimings = prefs.getStringList(_busTimingsKey)!;

  assert(followedBusesRaw.length == followedBusTimings.length);

  final DateTime now = DateTime.now();

  for (int i = followedBusesRaw.length - 1; i >= 0; i--) {
    final DateTime arrivalTime = DateTime.parse(followedBusTimings[i]);
    if (arrivalTime.isBefore(now)) {
      followedBusesRaw.removeAt(i);
      followedBusTimings.removeAt(i);
    }
  }

  for (int i = 0; i < followedBusesRaw.length; i++) {
    final List<String> tokens = followedBusesRaw[i].split(' ');
    final BusStop busStop = await getCachedBusStopWithCode(tokens[0]);
    final BusService busService = await getCachedBusService(tokens[1]);
    followedBuses.add(Bus(busStop: busStop, busService: busService));
  }

  prefs.setStringList(_isBusFollowedKey, followedBusesRaw);
  prefs.setStringList(_busTimingsKey, followedBusTimings);

  return followedBuses;
}

Future<void> unfollowBus({required String stop, required String bus}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(_isBusFollowedKey)) {
    prefs.setStringList(_isBusFollowedKey, <String>[]);
  }
  if (!prefs.containsKey(_busTimingsKey)) {
    prefs.setStringList(_busTimingsKey, <String>[]);
  }

  final List<String> followedBuses = prefs.getStringList(_isBusFollowedKey)!;
  final List<String> followedBusTimings = prefs.getStringList(_busTimingsKey)!;

  assert(followedBuses.length == followedBusTimings.length);

  final String key = _followerKey(stop, bus);
  final int index = followedBuses.indexOf(key);

  if (index != -1) {
    // If bus is not already un-followed (by cancelling)
    followedBuses.remove(key);
    followedBusTimings.removeAt(index);
  }

  prefs.setStringList(_isBusFollowedKey, followedBuses);
  prefs.setStringList(_busTimingsKey, followedBusTimings);

  // Update followed buses stream
  updateFollowedBusesStream();
  updateNotifications();

  // To allow removal of listener while in iteration
  // (as it is common behaviour for a listener to
  // detach itself after a certain call)
  if (_busFollowStatusListeners[key] == null) return;
  final List<BusFollowStatusListener> listeners =
      List<BusFollowStatusListener>.from(_busFollowStatusListeners[key]!);

  for (BusFollowStatusListener listener in listeners) {
    listener(stop, bus, false);
  }
}

Future<List<Map<String, dynamic>>> unfollowAllBuses() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();

  final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
  final List<String> followedBuses = prefs.getStringList(_isBusFollowedKey)!;
  final List<String> followedBusTimings = prefs.getStringList(_busTimingsKey)!;

  for (int i = 0; i < followedBuses.length; i++) {
    final List<String> tokens = followedBuses[i].split(' ');
    final String stop = tokens[0];
    final String bus = tokens[1];
    result.add(<String, dynamic>{
      'stop': stop,
      'bus': bus,
      'arrivalTime': DateTime.parse(followedBusTimings[i]),
    });
  }

  prefs.setStringList(_isBusFollowedKey, <String>[]);
  prefs.setStringList(_busTimingsKey, <String>[]);

  // Update followed buses stream
  updateFollowedBusesStream();
  updateNotifications();

  for (MapEntry<String, List<BusFollowStatusListener>> entry
      in _busFollowStatusListeners.entries) {
    final List<String> tokens = entry.key.split(' ');
    final String stop = tokens[0];
    final String bus = tokens[1];

    for (BusFollowStatusListener listener in entry.value) {
      listener(stop, bus, false);
    }
  }

  return result;
}

Future<bool> isBusFollowed({required String stop, required String bus}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(_isBusFollowedKey)) {
    return false;
  }
  if (!prefs.containsKey(_busTimingsKey)) {
    return false;
  }
  final List<String> followedBuses = prefs.getStringList(_isBusFollowedKey)!;
  final List<String> followedBusTimings = prefs.getStringList(_busTimingsKey)!;

  if (followedBuses.length != followedBusTimings.length) {
    followedBuses.clear();
    followedBusTimings.clear();

    prefs.setStringList(_isBusFollowedKey, followedBuses);
    prefs.setStringList(_busTimingsKey, followedBusTimings);
  }

  assert(followedBuses.length == followedBusTimings.length);

  final String key = _followerKey(stop, bus);
  if (followedBuses.contains(key)) {
    final int index = followedBuses.indexOf(key);
    final DateTime arrivalTime = DateTime.parse(followedBusTimings[index]);
    if (arrivalTime.isAfter(DateTime.now())) {
      return true;
    } else {
      followedBuses.remove(key);
      followedBusTimings.removeAt(index);
      prefs.setStringList(_isBusFollowedKey, followedBuses);
      prefs.setStringList(_busTimingsKey, followedBusTimings);
      return false;
    }
  }
  return false;
}

Stream<List<Bus>> followedBusesStream() {
  return _followedBusesController.stream;
}

String _followerKey(String stop, String bus) => '$stop $bus';

void addBusFollowStatusListener(
    String stop, String bus, BusFollowStatusListener listener) {
  final String key = _followerKey(stop, bus);
  _busFollowStatusListeners.putIfAbsent(key, () => <BusFollowStatusListener>[]);
  _busFollowStatusListeners[key]!.add(listener);
}

void removeBusFollowStatusListener(
    String stop, String bus, BusFollowStatusListener listener) {
  final String key = _followerKey(stop, bus);
  if (_busFollowStatusListeners.containsKey(key)) {
    _busFollowStatusListeners[key]!.remove(listener);
  }
}

// Retrieves the skip number required by the API to access that bus services data
Future<int> getBusServiceSkip(String serviceNumber) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String key = serviceNumber;
  return prefs.getInt(key + _busServiceSkipNumberKey) ?? -1;
}

Future<void> storeBusServiceSkip(String serviceNumber, int skip) async {
  assert(serviceNumber.isNotEmpty);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String key = serviceNumber;
  prefs.setInt(key + _busServiceSkipNumberKey, skip);
}

Future<bool> busServiceSkipsStored() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(_busServiceSkipNumberKey);
}

Future<void> setBusServiceSkipsStored() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setBool(_busServiceSkipNumberKey, true);
}

Future<void> pushHistory(String query) async {
  if (query.isEmpty) return;
  final List<String> history = await getHistory();
  history.remove(query);
  history.add(query);
  if (history.length > 3) history.removeAt(0);
  storeHistory(history);
}

Future<void> storeHistory(List<String> history) async {
  assert(history.length <= 3);
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  for (int i = 0; i < history.length; i++) {
    await prefs.setString('$_searchHistoryKey $i', history[i]);
  }
}

Future<List<String>> getHistory() async {
  final List<String> history = <String>[];
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  for (int i = 0; i < 3; i++) {
    if (prefs.containsKey('$_searchHistoryKey $i')) {
      history.add(prefs.getString('$_searchHistoryKey $i')!);
    } else {
      break;
    }
  }
  return history;
}

Future<void> cacheBusStops(List<BusStop> busStops) async {
  // final Database database = await _accessDatabase();
  // final Batch batch = database.batch();

  // for (final BusStop busStop in busStops) {
  //   batch.insert(
  //     'bus_stop',
  //     busStop.toMap(),
  //     conflictAlgorithm: ConflictAlgorithm.replace,
  //   );
  // }
  // await batch.commit(noResult: true);
  await _database.cacheBusStops(busStops);

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_areBusStopsCachedKey, true);
}

Future<bool> areBusStopsCached() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(_areBusStopsCachedKey);
}

Future<List<BusStop>> getCachedBusStops() async {
  // final Database database = await _accessDatabase();
  // final List<Map<String, dynamic>> maps = await database.query('bus_stop');

  // return List<BusStop>.generate(
  //     maps.length, (int i) => BusStop.fromMap(maps[i]));
  return await _database.getCachedBusStops();
}

Future<BusStop> getCachedBusStopWithCode(String busStopCode) async {
  // assert(await areBusStopsCached());
  // final Database database = await _accessDatabase();
  // final List<Map<String, dynamic>> result = await database
  //     .query('bus_stop', where: 'code = ?', whereArgs: <dynamic>[busStopCode]);

  // return BusStop.fromMap(result.first);
  return await getCachedBusStopWithCode(busStopCode);
}

Future<void> cacheBusServices(List<BusService> busServices) async {
  await _database.cacheBusServices(busServices);
  // final Database database = await _accessDatabase();
  // final Batch batch = database.batch();

  // for (final BusService busService in busServices) {
  //   batch.insert(
  //     'bus_service',
  //     busService.toMap(),
  //     conflictAlgorithm: ConflictAlgorithm.replace,
  //   );
  // }
  // await batch.commit(noResult: true);

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_areBusServicesCachedKey, true);
}

Future<bool> areBusServicesCached() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(_areBusServicesCachedKey);
}

Future<List<BusService>> getCachedBusServices() async {
  return await _database.getCachedBusServices();
  // final Database database = await _accessDatabase();
  // final List<Map<String, dynamic>> maps = await database.query('bus_service');

  // return List<BusService>.generate(
  //     maps.length, (int i) => BusService.fromMap(maps[i]));
}

Future<BusService> getCachedBusService(String serviceNumber) async {
  // final Database database = await _accessDatabase();
  // final List<Map<String, dynamic>> maps = await database.query('bus_service',
  //     where: 'number = ?', whereArgs: <dynamic>[serviceNumber]);
  // return BusService.fromMap(maps.first);
  return await _database.getCachedBusService(serviceNumber);
}

Future<BusServiceWithRoutes> getCachedBusServiceWithRoutes(
    String serviceNumber) async {
  final BusService service = await getCachedBusService(serviceNumber);
  final List<BusServiceRoute> routes = await getCachedBusRoutes(service);

  return BusServiceWithRoutes.fromBusService(service, routes);
}

Map<String, dynamic> busServiceRouteStopToJson(dynamic busStop) {
  final String serviceNumber = busStop[BusAPI.kBusServiceNumberKey] as String;
  final int direction = busStop[BusAPI.kBusServiceDirectionKey] as int;
  final String busStopCode = busStop[BusAPI.kBusStopCodeKey] as String;
  final double distance =
      double.parse(busStop[BusAPI.kBusStopDistanceKey].toString());

  final Map<String, dynamic> json = <String, dynamic>{
    'serviceNumber': serviceNumber,
    'direction': direction,
    'busStopCode': busStopCode,
    'distance': distance,
  };
  return json;
}

Future<void> cacheBusServiceRoutes(
    List<Map<String, dynamic>> busServiceRoutesRaw) async {
  // final Database database = await _accessDatabase();
  // final Batch batch = database.batch();
  // for (dynamic busStop in busServiceRoutesRaw) {
  //   batch.insert(
  //     'bus_route',
  //     busStop as Map<String, dynamic>,
  //     conflictAlgorithm: ConflictAlgorithm.replace,
  //   );
  // }
  // await batch.commit(noResult: true);
  await _database.cacheBusServiceRoutes(busServiceRoutesRaw);

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_areBusServiceRoutesCachedKey, true);
}

Future<bool> areBusServiceRoutesCached() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(_areBusServiceRoutesCachedKey);
}

Future<List<BusServiceRoute>> getCachedBusRoutes(BusService busService) async {
  return await _database.getCachedBusRoutes(busService);
  // final Database database = await _accessDatabase();
  // final List<Map<String, dynamic>> maps = await database.query('bus_route',
  //     where: 'serviceNumber = ?',
  //     whereArgs: <dynamic>[busService.number],
  //     orderBy: 'distance');
  // final Map<int, List<BusStopWithDistance>> routeBusStops =
  //     <int, List<BusStopWithDistance>>{};
  // for (Map<String, dynamic> bs in maps) {
  //   final int direction = bs['direction'] as int;
  //   final double distance = bs['distance'] as double;
  //   final String busStopCode = bs['busStopCode'] as String;
  //   final BusStop busStop = await getCachedBusStopWithCode(busStopCode);
  //   final BusStopWithDistance busStopWithDistance =
  //       BusStopWithDistance(busStop, distance);

  //   routeBusStops.putIfAbsent(direction, () => <BusStopWithDistance>[]);
  //   routeBusStops[direction]!.add(busStopWithDistance);
  // }
  // return routeBusStops.entries
  //     .map((MapEntry<int, List<BusStopWithDistance>> entry) {
  //   return BusServiceRoute(
  //     service: busService,
  //     direction: entry.key,
  //     busStops: entry.value,
  //   );
  // }).toList();
}

Future<void> pinBusService(
    BusStop busStop, BusService busService, UserRoute route) async {
  // final Database database = await _accessDatabase();
  // final Map<String, dynamic> data = <String, dynamic>{
  //   'routeId': route.id,
  //   'busStopCode': busStop.code,
  //   'busServiceNumber': busService.number,
  // };
  // await database.insert('pinned_bus_service', data);
  await _database.pinBusService(busStop, busService, route);
  await _updateRouteBusStopsStream(route);
}

Future<void> unpinBusService(
    BusStop busStop, BusService busService, UserRoute route) async {
  // final Database database = await _accessDatabase();
  // await database.delete(
  //   'pinned_bus_service',
  //   where: 'routeId = ? and busStopCode = ? and busServiceNumber = ?',
  //   whereArgs: <dynamic>[
  //     route.id,
  //     busStop.code,
  //     busService.number,
  //   ],
  // );
  await _database.unpinBusService(busStop, busService, route);
  await _updateRouteBusStopsStream(route);
}

Future<bool> isBusServicePinned(
    BusStop busStop, BusService busService, UserRoute route) async {
  return await _database.isBusServicePinned(busStop, busService, route);
  // final Database database = await _accessDatabase();
  // final int routeId = route.id ?? defaultRouteId;
  // final List<Map<String, dynamic>> result = await database.query(
  //   'pinned_bus_service',
  //   where: 'routeId = ? and busStopCode = ? and busServiceNumber = ?',
  //   whereArgs: <dynamic>[
  //     routeId,
  //     busStop.code,
  //     busService.number,
  //   ],
  // );
  // return result.isNotEmpty;
}

Future<List<BusService>> getPinnedServicesIn(
    BusStop busStop, UserRoute route) async {
  return await _database.getPinnedServicesIn(busStop, route);
  // final Database database = await _accessDatabase();
  // final int routeId = route.id!;
  // final List<Map<String, dynamic>> result = await database.rawQuery(
  //   'SELECT * FROM pinned_bus_service INNER JOIN bus_service '
  //   'ON pinned_bus_service.busServiceNumber = bus_service.number '
  //   'WHERE routeId = ? and pinned_bus_service.busStopCode = ?',
  //   <dynamic>[routeId, busStop.code],
  // );

  // final List<BusService> services =
  //     result.map(BusService.fromMap).toList(growable: false);
  // services.sort(
  //     (BusService a, BusService b) => compareBusNumber(a.number, b.number));
  // return services;
}

Future<List<BusService>> getServicesIn(BusStop busStop) async {
  return await _database.getServicesIn(busStop);
  // final Database database = await _accessDatabase();
  // final List<Map<String, dynamic>> result = await database.rawQuery(
  //   'SELECT * FROM (SELECT DISTINCT(serviceNumber) FROM bus_route WHERE busStopCode = ?) INNER JOIN bus_service '
  //   'ON serviceNumber = bus_service.number',
  //   <String>[busStop.code],
  // );

  // final List<BusService> services =
  //     result.map(BusService.fromMap).toList(growable: false);
  // services.sort(
  //     (BusService a, BusService b) => compareBusNumber(a.number, b.number));
  // return services;
}
