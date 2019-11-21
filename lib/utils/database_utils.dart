import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:latlong/latlong.dart' as latlong;
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:stops_sg/utils/bus_api.dart';
import 'package:stops_sg/utils/bus_route.dart';
import 'package:stops_sg/utils/bus_utils.dart';

import 'bus_service.dart';
import 'bus_stop.dart';

/* Called when a bus stop is modified */
typedef BusStopChangeListener = void Function(BusStop busStop);
/* Called when bus is followed/un-followed */
typedef BusFollowStatusListener = void Function(String stop, String bus, bool isFollowed);
/* Called when bus service is pinned/unpinned for a bus stop*/
typedef BusPinStatusListener = void Function(String stop, String bus, bool isPinned);

const String _isBusFollowedKey = 'BUS_FOLLOW';
const String _busServiceSkipNumberKey = 'BUS_SERVICE_SKIP';
const String _searchHistoryKey = 'SEARCH_HISTORY';
const String _areBusStopsCachedKey = 'BUS_STOP_CACHE';
const String _areBusServicesCachedKey = 'BUS_SERVICE_CACHE';
const String _areBusServiceRoutesCachedKey = 'BUS_ROUTE_CACHE';

Map<String, List<BusFollowStatusListener>> _busFollowStatusListeners = <String, List<BusFollowStatusListener>>{};
Map<BusStop, List<BusStopChangeListener>> _busStopListeners = <BusStop, List<BusStopChangeListener>>{};

Future<Database> _accessDatabase() async {
  return openDatabase(
      join(await getDatabasesPath(), 'busstop_database.db'),
      onCreate: (Database db, int version) {
        db.execute('CREATE TABLE bus_stop('
          'code VARCHAR(5) PRIMARY KEY,'
          'displayName TEXT,'
          'defaultName TEXT,'
          'road TEXT,'
          'latitude DOUBLE,'
          'longitude DOUBLE,'
          'starred BOOLEAN DEFAULT 0)');
        db.execute('CREATE TABLE bus_service('
          'number VARCHAR(4) PRIMARY KEY,'
          'operator TEXT)');
        db.execute('CREATE TABLE bus_route('
          'serviceNumber VARCHAR(4) NOT NULL,'
          'direction INTEGER NOT NULL,'
          'busStopCode VARCHAR(5) NOT NULL,'
          'distance DOUBLE,'
          'PRIMARY KEY (serviceNumber, direction, busStopCode))');
        db.execute('CREATE TABLE pinned_bus_service('
            'busStopCode VARCHAR(5),'
            'busServiceNumber VARCHAR(4),'
            'PRIMARY KEY (busStopCode, busServiceNumber),'
            'FOREIGN KEY (busStopCode) REFERENCES bus_stop(code),'
            'FOREIGN KEY (busServiceNumber) REFERENCES bus_service(number))');
      },
      version: 1,
  );
}

Future<Map<String, dynamic>> getNearestBusStops(double latitude, double longitude) async {
  const int numberOfEntries = 3;

  const String distanceQuery = '(latitude - ?) * (latitude - ?) + (longitude - ?) * (longitude - ?) AS distance';
  const String fullQuery = 'SELECT *, $distanceQuery FROM bus_stop ORDER BY distance LIMIT ?';
  final List<String> args = <String>['$latitude', '$latitude', '$longitude', '$longitude', '$numberOfEntries'];

  final Database database = await _accessDatabase();
  final List<Map<String, dynamic>> result = await database.rawQuery(fullQuery, args);
  final List<BusStop> busStops = List<BusStop>.generate(result.length, (int i) => BusStop.fromMap(result[i]));
  final List<double> distances = List<double>.generate(result.length, (int i) {
    final double distanceMeters = const latlong.Distance().as(
        latlong.LengthUnit.Meter,
        latlong.LatLng(result[i]['latitude'], result[i]['longitude']),
        latlong.LatLng(latitude, longitude));
    return distanceMeters;
  });

  return <String, dynamic> {'busStops': busStops, 'distances': distances};
}

Future<List<BusStop>> getStarredBusStops() async {
  final Database database = await _accessDatabase();
  final List<Map<String, dynamic>> result = await database.query('bus_stop', where: 'starred = 1');
  final List<BusStop> busStops = List<BusStop>.generate(result.length, (int i) => BusStop.fromMap(result[i]));

  return busStops;
}

Future<void> starBusStop(BusStop busStop) async {
  final Database database = await _accessDatabase();
  final Map<String, dynamic> map = busStop.toMap();
  map['starred'] = 1;
  await database.update(
    'bus_stop',
    map,
    where: 'code = ?',
    whereArgs: <dynamic>[busStop.code],
  );

  _updateBusStopListeners(busStop);
}

Future<void> unstarBusStop(BusStop busStop) async {
  final Database database = await _accessDatabase();
  busStop.displayName = busStop.defaultName;
  final Map<String, dynamic> map = busStop.toMap();
  map['starred'] = 0;
  await database.update(
    'bus_stop',
    map,
    where: 'code = ?',
    whereArgs: <dynamic>[busStop.code],
  );

  _updateBusStopListeners(busStop);
}

Future<bool> isBusStopStarred(BusStop busStop) async {
  final Database database = await _accessDatabase();
  final List<Map<String, dynamic>> result = await database.query('bus_stop', where: 'starred = 1 and code = ?', whereArgs: <dynamic>[busStop.code]);
  return result.isNotEmpty;
}

void registerBusStopListener(BusStop busStop, BusStopChangeListener listener) {
  _busStopListeners.putIfAbsent(busStop, () => <BusStopChangeListener>[]);
  _busStopListeners[busStop].add(listener);
}

void unregisterBusStopListener(BusStop busStop, BusStopChangeListener listener) {
  if (_busStopListeners.containsKey(busStop)) {
    final List<BusStopChangeListener> listeners = _busStopListeners[busStop];
    listeners.remove(listener);
    if (listeners.isEmpty)
      _busStopListeners.remove(busStop);
  }
}

void _updateBusStopListeners(BusStop busStop) {
  if (_busStopListeners[busStop] != null)
    for (BusStopChangeListener listener in _busStopListeners[busStop]) {
      listener(busStop);
    }
}

Future<void> followBus({@required String stop, @required String bus}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setBool('$_isBusFollowedKey$stop$bus', true);

  final String key = _followerKey(stop, bus);

  // To allow removal of listener while in iteration
  // (as it is common behaviour for a listener to
  // detach itself after a certain call)
  final List<BusFollowStatusListener> listeners = List<BusFollowStatusListener>.from(_busFollowStatusListeners[key]);

  for (BusFollowStatusListener listener in listeners) {
    listener(stop, bus, true);
  }
}

Future<void> unfollowBus({@required String stop, @required String bus}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.remove('$_isBusFollowedKey$stop$bus');

  final String key = _followerKey(stop, bus);

  // To allow removal of listener while in iteration
  // (as it is common behaviour for a listener to
  // detach itself after a certain call)
  final List<BusFollowStatusListener> listeners = List<BusFollowStatusListener>.from(_busFollowStatusListeners[key]);

  for (BusFollowStatusListener listener in listeners) {
    listener(stop, bus, false);
  }
}

Future<bool> isBusFollowed({@required String stop, @required String bus}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.containsKey('$_isBusFollowedKey$stop$bus');
}

String _followerKey(String stop, String bus) => '$stop $bus';

void addBusFollowStatusListener(String stop, String bus, BusFollowStatusListener listener) {
  final String key = _followerKey(stop, bus);
  _busFollowStatusListeners.putIfAbsent(key, () => <BusFollowStatusListener>[]);
  _busFollowStatusListeners[key].add(listener);
}

void removeBusFollowStatusListener(String stop, String bus, BusFollowStatusListener listener) {
  final String key = _followerKey(stop, bus);
  if (_busFollowStatusListeners.containsKey(key))
    _busFollowStatusListeners[key].remove(listener);
}

// Retrieves the skip number required by the API to access that bus services data
Future<int> getBusServiceSkip(String serviceNumber) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final String key = serviceNumber;
  return prefs.containsKey(key + _busServiceSkipNumberKey) ? prefs.getInt(key + _busServiceSkipNumberKey) : -1;
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
  if (query.isEmpty)
    return;
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('$_searchHistoryKey 0')) {
    final String historyTop = prefs.getString('$_searchHistoryKey 0');
    if (query == historyTop)
      return;
  }
  await shiftHistory();
  prefs.setString('$_searchHistoryKey 0',  query);
}

Future<void> shiftHistory() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.containsKey('$_searchHistoryKey 1'))
    prefs.setString('$_searchHistoryKey 2', prefs.getString('$_searchHistoryKey 1'));
  if (prefs.containsKey('$_searchHistoryKey 0'))
    prefs.setString('$_searchHistoryKey 1', prefs.getString('$_searchHistoryKey 0'));
}

Future<List<String>> getHistory() async {
  final List<String> history = <String>[];
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  for (int i = 0; i < 3; i++) {
    if (prefs.containsKey('$_searchHistoryKey $i')) {
      history.add(prefs.getString('$_searchHistoryKey $i'));
    } else {
      break;
    }
  }
  return history;
}

Future<void> cacheBusStops(List<BusStop> busStops) async {
  final Database database = await _accessDatabase();
  final Batch batch = database.batch();

  for (final BusStop busStop in busStops) {
    _cacheBusStop(busStop, batch);
  }
  await batch.commit(noResult: true);

  getCachedBusStops().then((List<BusStop> bs) {
    assert(bs.length == busStops.length);
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.setBool(_areBusStopsCachedKey, true);
    });
  });
}

void _cacheBusStop(BusStop busStop, Batch batch) {
  batch.insert(
    'bus_stop',
    busStop.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<bool> areBusStopsCached() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(_areBusStopsCachedKey);
}

Future<List<BusStop>> getCachedBusStops() async {
  final Database database = await _accessDatabase();
  final List<Map<String, dynamic>> maps = await database.query('bus_stop');

  return List<BusStop>.generate(maps.length, (int i) => BusStop.fromMap(maps[i]));
}

Future<BusStop> getCachedBusStopWithCode(String busStopCode) async {
  assert (await areBusStopsCached());
  final Database database = await _accessDatabase();
  final List<Map<String, dynamic>> result = await database.query('bus_stop', where: 'code = ?', whereArgs: <dynamic>[busStopCode]);

  return BusStop.fromMap(result.first);
}

Future<void> cacheBusServices(List<BusService> busServices) async {
  final Database database = await _accessDatabase();
  final Batch batch = database.batch();

  for (final BusService busService in busServices) {
    _cacheBusService(busService, batch);
  }
  await batch.commit(noResult: true);

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_areBusServicesCachedKey, true);
}

void _cacheBusService(BusService busService, Batch batch) {
  batch.insert(
    'bus_service',
    busService.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<bool> areBusServicesCached() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(_areBusServicesCachedKey);
}

Future<List<BusService>> getCachedBusServices() async {
  final Database database = await _accessDatabase();
  final List<Map<String, dynamic>> maps = await database.query('bus_service');

  return List<BusService>.generate(maps.length, (int i) => BusService.fromMap(maps[i]));
}

Future<BusService> getCachedBusServiceWithNumber(String serviceNumber) async {
  final Database database = await _accessDatabase();
  final List<Map<String, dynamic>> maps = await database.query('bus_service', where: 'number = ?', whereArgs: <dynamic>[serviceNumber]);

  return BusService.fromMap(maps.first);
}

Future<Batch> beginBatchTransaction() async {
  return (await _accessDatabase()).batch();
}

void cacheBusServiceRouteStop(Map<String, dynamic> busStop, Batch batch) {
  final String serviceNumber = busStop[BusAPI.kBusServiceNumberKey];
  final int direction = busStop[BusAPI.kBusServiceDirectionKey];
  final String busStopCode = busStop[BusAPI.kBusStopCodeKey];
  final double distance = busStop[BusAPI.kBusStopDistanceKey]?.toDouble() ?? 0;

  final dynamic json = <String, dynamic>{
    'serviceNumber': serviceNumber,
    'direction': direction,
    'busStopCode': busStopCode,
    'distance': distance,
  };

  batch.insert(
    'bus_route',
    json,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<bool> areBusServiceRoutesCached() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(_areBusServiceRoutesCachedKey);
}

Future<void> setBusServiceRoutesCached() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_areBusServiceRoutesCachedKey, true);
}

Future<List<BusServiceRoute>> getCachedBusRoutes(BusService busService) async {
  final Database database = await _accessDatabase();
  final List<Map<String, dynamic>> maps = await database.query('bus_route', where: 'serviceNumber = ?', whereArgs: <dynamic>[busService.number], orderBy: 'distance');
  final Map<int, BusServiceRoute> routes = <int, BusServiceRoute>{};
  for (Map<String, dynamic> bs in maps) {
    final int direction = bs['direction'];
    final double distance = bs['distance'];
    final String busStopCode = bs['busStopCode'];
    final BusStop busStop = await getCachedBusStopWithCode(busStopCode);

    if (!routes.containsKey(direction)) {
      routes[direction] = BusServiceRoute(direction: direction);
    }
    routes[direction].busStops.add(busStop);
    routes[direction].distances.add(distance);
  }
  return routes.values.toList(growable: false);
}

Future<void> pinBusService(BusStop busStop, BusService busService) async {
  final Database database = await _accessDatabase();
  final Map<String, String> data = <String, String>{
    'busStopCode': busStop.code,
    'busServiceNumber':  busService.number,
  };
  await database.insert('pinned_bus_service', data);
}

Future<void> unpinBusService(BusStop busStop, BusService busService) async {
  final Database database = await _accessDatabase();
  await database.delete(
      'pinned_bus_service',
      where: 'busStopCode = ? and busServiceNumber = ?',
      whereArgs: <String>[
        busStop.code,
        busService.number,
      ],
  );
}

Future<bool> isBusServicePinned(BusStop busStop, BusService busService) async {
  final Database database = await _accessDatabase();
  final List<Map<String, dynamic>> result = await database.query(
    'pinned_bus_service',
    where: 'busStopCode = ? and busServiceNumber = ?',
    whereArgs: <String>[
      busStop.code,
      busService.number,
    ],
  );
  return result.isNotEmpty;
}

Future<List<BusService>> getPinnedServicesIn(BusStop busStop) async {
  final Database database = await _accessDatabase();
  final List<Map<String, dynamic>> result = await database.rawQuery(
      'SELECT * FROM pinned_bus_service INNER JOIN bus_service '
      'ON pinned_bus_service.busServiceNumber = bus_service.number '
      'WHERE pinned_bus_service.busStopCode = ?',
      <String>[busStop.code],
  );

  final List<BusService> services = result.map(BusService.fromMap).toList(growable: false);
  services.sort((BusService a, BusService b) => compareBusNumber(a.number, b.number));
  return services;
}

Future<List<BusService>> getServicesIn(BusStop busStop) async {
  final Database database = await _accessDatabase();
  final List<Map<String, dynamic>> result = await database.rawQuery(
    'SELECT * FROM (SELECT DISTINCT(serviceNumber) FROM bus_route WHERE busStopCode = ?) INNER JOIN bus_service '
    'ON serviceNumber = bus_service.number',
    <String>[busStop.code],
  );

  final List<BusService> services = result.map(BusService.fromMap).toList(growable: false);
  services.sort((BusService a, BusService b) => compareBusNumber(a.number, b.number));
  return services;
}