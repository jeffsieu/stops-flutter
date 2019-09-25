import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:latlong/latlong.dart' as latlong;
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'bus_stop.dart';

/* Called when bus stop name is changed */
typedef BusStopChangeListener = Function(BusStop busStop);
/* Called when bus stop is followed/un-followed */
typedef BusFollowStatusListener = void Function(String stop, String bus, bool isFollowed);

const String _isBusFollowedKey = 'BUS_FOLLOW';
const String _busServiceSkipNumberKey = 'BUS_SERVICE_SKIP';
const String _searchHistoryKey = 'SEARCH_HISTORY';
const String _areBusStopsCachedKey = 'BUS_STOP_CACHE';

Map<String, List<BusFollowStatusListener>> _busFollowStatusListeners = <String, List<BusFollowStatusListener>>{};
Map<BusStop, List<BusStopChangeListener>> _busStopListeners = <BusStop, List<BusStopChangeListener>>{};

Future<Database> _accessDatabase() async {
  return openDatabase(
      join(await getDatabasesPath(), 'busstop_database.db'),
      onCreate: (Database db, int version) {
        db.execute('CREATE TABLE busstops(code TEXT PRIMARY KEY, displayName TEXT, defaultName TEXT, road TEXT, latitude DOUBLE, longitude DOUBLE, starred INTEGER DEFAULT 0)');
      },
      version: 1,
  );
}

Future<Map<String, dynamic>> getNearestBusStops(double latitude, double longitude) async {
  const int numberOfEntries = 3;

  const String distanceQuery = '(latitude - ?) * (latitude - ?) + (longitude - ?) * (longitude - ?) AS distance';
  const String fullQuery = 'SELECT *, $distanceQuery FROM busstops ORDER BY distance LIMIT ?';
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
  final List<Map<String, dynamic>> result = await database.query('busstops', where: 'starred = 1');
  final List<BusStop> busStops = List<BusStop>.generate(result.length, (int i) => BusStop.fromMap(result[i]));

  return busStops;
}

Future<void> starBusStop(BusStop busStop) async {
  final Database database = await _accessDatabase();
  final Map<String, dynamic> map = busStop.toMap();
  map['starred'] = 1;
  await database.update(
    'busstops',
    map,
    where: 'code = ?',
    whereArgs: <dynamic>[busStop.code],
  );

  if (_busStopListeners[busStop] != null)
    for (BusStopChangeListener listener in _busStopListeners[busStop]) {
      listener(busStop);
    }
}

Future<void> unstarBusStop(BusStop busStop) async {
  final Database database = await _accessDatabase();
  final Map<String, dynamic> map = busStop.toMap();
  map['starred'] = 0;
  await database.update(
    'busstops',
    map,
    where: 'code = ?',
    whereArgs: <dynamic>[busStop.code],
  );
}

Future<bool> isBusStopStarred(BusStop busStop) async {
  final Database database = await _accessDatabase();
  final List<Map<String, dynamic>> result = await database.query('busstops', where: 'starred = 1 and code = ?', whereArgs: <dynamic>[busStop.code]);
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

Future<void> followBus({@required String stop, @required String bus}) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setBool('$_isBusFollowedKey$stop$bus', true);

  final String key = _followerKey(stop, bus);

  for (BusFollowStatusListener listener in _busFollowStatusListeners[key]) {
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

  for (int i = 0; i < busStops.length; i++) {
    await _cacheBusStop(busStops[i], database);
  }

  getCachedBusStops().then((List<BusStop> bs) {
    assert(bs.length == busStops.length);
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.setBool(_areBusStopsCachedKey, true);
    });
  });
}

Future<void> _cacheBusStop(BusStop busStop, Database database) async {
  await database.insert(
    'busstops',
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
  final List<Map<String, dynamic>> maps = await database.query('busstops');

  return List<BusStop>.generate(maps.length, (int i) => BusStop.fromMap(maps[i]));
}

Future<BusStop> getCachedBusStopWithCode(String busStopCode) async {
  final Database database = await _accessDatabase();
  final List<Map<String, dynamic>> result = await database.query('busstops', where: 'code = ?', whereArgs: <dynamic>[busStopCode]);

  return BusStop.fromMap(result[0]);
}