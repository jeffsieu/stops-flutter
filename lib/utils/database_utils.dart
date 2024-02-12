import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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
import 'user_location.dart';

part 'database_utils.g.dart';

/* Called when bus is followed/un-followed */
typedef BusFollowStatusListener = void Function(
    String stop, String bus, bool isFollowed);
/* Called when bus service is pinned/unpinned for a bus stop*/
typedef BusPinStatusListener = void Function(
    String stop, String bus, bool isPinned);

const int kDefaultRouteId = -1;
const String defaultRouteName = 'Home';
const String _themeModeKey = 'THEME_OPTION';
const String _isBusFollowedKey = 'BUS_FOLLOW';
const String _busTimingsKey = 'BUS_TIMINGS';
const String _busServiceSkipNumberKey = 'BUS_SERVICE_SKIP';
const String _searchHistoryKey = 'SEARCH_HISTORY';
const String kAreBusStopsCachedKey = 'BUS_STOP_CACHE';
const String kAreBusServicesCachedKey = 'BUS_SERVICE_CACHE';
const String _areBusServiceRoutesCachedKey = 'BUS_ROUTE_CACHE';

final Map<String, List<BusFollowStatusListener>> _busFollowStatusListeners =
    <String, List<BusFollowStatusListener>>{};
final StreamController<List<Bus>> _followedBusesController =
    StreamController<List<Bus>>.broadcast(onListen: updateFollowedBusesStream);

final StopsDatabase _database = StopsDatabase();

Future<ThemeMode> getThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final themeModeIndex = prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
  return ThemeMode.values[themeModeIndex];
}

Future<void> setThemeMode(ThemeMode themeMode) async {
  final prefs = await SharedPreferences.getInstance();
  prefs.setInt(_themeModeKey, themeMode.index);
}

@riverpod
class BusStopList extends _$BusStopList {
  @override
  Future<List<BusStop>> build() async {
    return await _database.getCachedBusStops();
  }

  Future<void> fetchFromApi() async {
    final busStopList = await ref.read(apiBusStopListProvider.future);
    await _cacheBusStops(busStopList);
    ref.invalidateSelf();
  }

  Future<void> updateBusStop(BusStop newBusStop) async {
    await _database.updateBusStop(newBusStop);
    ref.invalidateSelf();
  }
}

@riverpod
class BusServiceList extends _$BusServiceList {
  @override
  Future<List<BusService>> build() async {
    return await _database.getCachedBusServices();
  }

  Future<void> fetchFromApi() async {
    final busServiceList = await ref.read(apiBusServiceListProvider.future);
    await cacheBusServices(busServiceList);
    ref.invalidateSelf();
  }
}

@riverpod
class BusServiceRouteList extends _$BusServiceRouteList {
  @override
  Future<List<BusServiceRoute>> build(BusService busService) async {
    return await getCachedBusRoutes(busService);
  }

  Future<void> fetchFromApi() async {
    final busServiceRouteList =
        await ref.read(apiBusServiceRouteListProvider.future);
    await cacheBusServiceRoutes(busServiceRouteList);
    ref.invalidateSelf();
    ref.invalidate(busStopServicesProvider);
  }
}

Future<List<StoredUserRoute>> _getUserRoutes() async {
  final routeEntries = await _database.getStoredUserRoutes();
  final routes = <StoredUserRoute>[];
  for (var routeEntry in routeEntries) {
    final List<BusStop> busStops =
        await _getBusStopsInRouteWithId(routeEntry.id);
    final routeBusStops = <BusStopWithPinnedServices>[];
    for (var busStop in busStops) {
      final pinnedServices =
          await getPinnedServicesInRouteWithId(busStop, routeEntry.id);
      final busStopWithPinnedServices =
          BusStopWithPinnedServices.fromBusStop(busStop, pinnedServices);
      routeBusStops.add(busStopWithPinnedServices);
    }

    routes.add(StoredUserRoute(
        id: routeEntry.id,
        name: routeEntry.name,
        color: Color(routeEntry.color),
        busStops: routeBusStops));
  }
  return routes;
}

@riverpod
Future<List<BusStopWithDistance>?> nearestBusStops(NearestBusStopsRef ref,
    {required String busServiceFilter,
    required Duration minimumRefreshDuration}) async {
  // Wait at least 300ms before refreshing
  final stopwatch = Stopwatch()..start();

  final locationData = await ref
      .watch(userLocationProvider.selectAsync((snapshot) => snapshot.data));

  if (locationData == null) {
    stopwatch.stop();
    return null;
  } else {
    final result = await _database.getNearestBusStops(
        locationData.latitude!, locationData.longitude!, busServiceFilter);

    // Wait at least 300ms before refreshing
    if (stopwatch.elapsed < minimumRefreshDuration) {
      await Future.delayed(minimumRefreshDuration - stopwatch.elapsed);
    }

    stopwatch.stop();

    return result;
  }
}

Future<List<BusStopWithPinnedServices>> _getBusStopsInRouteWithId(
    int routeId) async {
  final busStops = await _database.getBusStopsInRouteWithId(routeId);
  final busStopsWithPinnedServices = <BusStopWithPinnedServices>[];

  for (var busStop in busStops) {
    final pinnedServices =
        await getPinnedServicesInRouteWithId(busStop, routeId);
    busStopsWithPinnedServices
        .add(BusStopWithPinnedServices.fromBusStop(busStop, pinnedServices));
  }

  return busStopsWithPinnedServices;
}

@riverpod
class SavedUserRoutes extends _$SavedUserRoutes {
  @override
  Future<List<StoredUserRoute>> build() async {
    return await _getUserRoutes();
  }

  Future<void> addRoute(UserRoute route) async {
    await _database.addUserRoute(route);
    ref.invalidateSelf();
  }

  Future<void> updateRoute(StoredUserRoute route) async {
    await _database.updateUserRoute(route);
    ref.invalidateSelf();
  }

  Future<void> moveUserRoutePosition(int from, int to) async {
    await _database.moveUserRoutePosition(from, to);
    ref.invalidateSelf();
  }
}

@riverpod
class CustomUserRoutes extends _$CustomUserRoutes {
  @override
  Future<List<StoredUserRoute>> build() async {
    return ref.watch(savedUserRoutesProvider.selectAsync((routes) =>
        routes.where((route) => route.id != kDefaultRouteId).toList()));
  }
}

@riverpod
class SavedUserRoute extends _$SavedUserRoute {
  @override
  Future<StoredUserRoute?> build({required int id}) async {
    final routes = await ref.watch(savedUserRoutesProvider.future);
    return routes.firstWhereOrNull((route) => route.id == id);
  }

  Future<void> addBusStop(BusStop busStop) async {
    await _database.addBusStopToRouteWithId(busStop, id);
    ref.invalidateSelf();
    ref.invalidate(savedUserRoutesProvider);

    /// TODO: SnackBar
//    action: SnackBarAction(
//      label: 'SHOW ME',
//      onPressed: () {
//        Navigator.popUntil(context, ModalRoute.withName('/home'));
//      },
//    ),
    // ));
  }

  Future<void> removeBusStop(BusStop busStop) async {
    await _database.removeBusStopFromRoute(busStop, id);
    ref.invalidateSelf();
    ref.invalidate(savedUserRoutesProvider);

    /// TODO: SnackBar
    // ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    //   content: Text(
    //       'Unpinned ${busStop.displayName} from ${route == StoredUserRoute.home ? "home" : route.name}'),
    //   action: SnackBarAction(
    //     label: 'UNDO',
    //     onPressed: () {
    //       addBusStopToRouteWithId(busStop, routeId, context);
    //     },
    //   ),
    // ));
  }

  Future<void> pinBusService(
      {required BusStop busStop, required BusService busService}) async {
    await _database.pinBusService(
        busStop: busStop, busService: busService, routeId: id);
    ref.invalidateSelf();
    ref.invalidate(savedUserRoutesProvider);
  }

  Future<void> unpinBusService(
      {required BusStop busStop, required BusService busService}) async {
    await _database.unpinBusService(
        busStop: busStop, busService: busService, routeId: id);
    ref.invalidateSelf();
    ref.invalidate(savedUserRoutesProvider);
  }

  Future<void> delete(StoredUserRoute userRoute) async {
    await _database.deleteUserRoute(id: id);
    ref.invalidateSelf();
    ref.invalidate(savedUserRoutesProvider);
  }

  Future<void> moveBusStop(int from, int to) async {
    await _database.moveBusStopPositionInRoute(from: from, to: to, routeId: id);
    ref.invalidateSelf();
    ref.invalidate(savedUserRoutesProvider);
  }
}

@riverpod
Future<bool> isBusServicePinned(IsBusServicePinnedRef ref,
    {required BusStop busStop,
    required BusService busService,
    required int routeId}) async {
  return await ref.watch(savedUserRouteProvider(id: routeId).selectAsync(
      (data) => (data?.busStops ?? [])
          .where((b) => b.code == busStop.code)
          .any((b) => b.pinnedServices.contains(busService))));
}

@riverpod
Future<bool> isBusStopInRoute(IsBusStopInRouteRef ref,
    {required BusStop busStop, required int routeId}) async {
  return await ref.watch(savedUserRouteProvider(id: routeId).selectAsync(
      (data) => (data?.busStops ?? []).any((b) => b.code == busStop.code)));
}

Future<void> followBus(
    {required String stop,
    required String bus,
    required DateTime arrivalTime}) async {
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(_isBusFollowedKey)) {
    prefs.setStringList(_isBusFollowedKey, <String>[]);
  }
  if (!prefs.containsKey(_busTimingsKey)) {
    prefs.setStringList(_busTimingsKey, <String>[]);
  }

  final followedBuses = prefs.getStringList(_isBusFollowedKey)!;
  final followedBusTimings = prefs.getStringList(_busTimingsKey)!;

  assert(followedBuses.length == followedBusTimings.length);

  final key = _followerKey(stop, bus);
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
  final listeners =
      List<BusFollowStatusListener>.from(_busFollowStatusListeners[key]!);

  for (var listener in listeners) {
    listener(stop, bus, true);
  }
}

Future<void> updateFollowedBusesStream() async {
  _followedBusesController.add(await getFollowedBuses());
}

Future<List<Bus>> getFollowedBuses() async {
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(_isBusFollowedKey) ||
      !prefs.containsKey(_busTimingsKey)) {
    return <Bus>[];
  }
  final followedBuses = <Bus>[];
  final followedBusesRaw = prefs.getStringList(_isBusFollowedKey)!;
  final followedBusTimings = prefs.getStringList(_busTimingsKey)!;

  assert(followedBusesRaw.length == followedBusTimings.length);

  final now = DateTime.now();

  for (var i = followedBusesRaw.length - 1; i >= 0; i--) {
    final arrivalTime = DateTime.parse(followedBusTimings[i]);
    if (arrivalTime.isBefore(now)) {
      followedBusesRaw.removeAt(i);
      followedBusTimings.removeAt(i);
    }
  }

  for (var i = 0; i < followedBusesRaw.length; i++) {
    final tokens = followedBusesRaw[i].split(' ');
    final busStop = await _database.getCachedBusStopWithCode(tokens[0]);
    final busService = await _database.getCachedBusService(tokens[1]);
    followedBuses.add(Bus(busStop: busStop, busService: busService));
  }

  prefs.setStringList(_isBusFollowedKey, followedBusesRaw);
  prefs.setStringList(_busTimingsKey, followedBusTimings);

  return followedBuses;
}

Future<void> unfollowBus({required String stop, required String bus}) async {
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(_isBusFollowedKey)) {
    prefs.setStringList(_isBusFollowedKey, <String>[]);
  }
  if (!prefs.containsKey(_busTimingsKey)) {
    prefs.setStringList(_busTimingsKey, <String>[]);
  }

  final followedBuses = prefs.getStringList(_isBusFollowedKey)!;
  final followedBusTimings = prefs.getStringList(_busTimingsKey)!;

  assert(followedBuses.length == followedBusTimings.length);

  final key = _followerKey(stop, bus);
  final index = followedBuses.indexOf(key);

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
  final listeners =
      List<BusFollowStatusListener>.from(_busFollowStatusListeners[key]!);

  for (var listener in listeners) {
    listener(stop, bus, false);
  }
}

Future<List<Map<String, dynamic>>> unfollowAllBuses() async {
  final prefs = await SharedPreferences.getInstance();

  final result = <Map<String, dynamic>>[];
  final followedBuses = prefs.getStringList(_isBusFollowedKey)!;
  final followedBusTimings = prefs.getStringList(_busTimingsKey)!;

  for (var i = 0; i < followedBuses.length; i++) {
    final tokens = followedBuses[i].split(' ');
    final stop = tokens[0];
    final bus = tokens[1];
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

  for (var entry in _busFollowStatusListeners.entries) {
    final tokens = entry.key.split(' ');
    final stop = tokens[0];
    final bus = tokens[1];

    for (var listener in entry.value) {
      listener(stop, bus, false);
    }
  }

  return result;
}

Future<bool> isBusFollowed({required String stop, required String bus}) async {
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey(_isBusFollowedKey)) {
    return false;
  }
  if (!prefs.containsKey(_busTimingsKey)) {
    return false;
  }
  final followedBuses = prefs.getStringList(_isBusFollowedKey)!;
  final followedBusTimings = prefs.getStringList(_busTimingsKey)!;

  if (followedBuses.length != followedBusTimings.length) {
    followedBuses.clear();
    followedBusTimings.clear();

    prefs.setStringList(_isBusFollowedKey, followedBuses);
    prefs.setStringList(_busTimingsKey, followedBusTimings);
  }

  assert(followedBuses.length == followedBusTimings.length);

  final key = _followerKey(stop, bus);
  if (followedBuses.contains(key)) {
    final index = followedBuses.indexOf(key);
    final arrivalTime = DateTime.parse(followedBusTimings[index]);
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
  final key = _followerKey(stop, bus);
  _busFollowStatusListeners.putIfAbsent(key, () => <BusFollowStatusListener>[]);
  _busFollowStatusListeners[key]!.add(listener);
}

void removeBusFollowStatusListener(
    String stop, String bus, BusFollowStatusListener listener) {
  final key = _followerKey(stop, bus);
  if (_busFollowStatusListeners.containsKey(key)) {
    _busFollowStatusListeners[key]!.remove(listener);
  }
}

Future<void> pushHistory(String query) async {
  if (query.isEmpty) return;
  final history = await getHistory();
  history.remove(query);
  history.add(query);
  if (history.length > 3) history.removeAt(0);
  storeHistory(history);
}

Future<void> storeHistory(List<String> history) async {
  assert(history.length <= 3);
  final prefs = await SharedPreferences.getInstance();
  for (var i = 0; i < history.length; i++) {
    await prefs.setString('$_searchHistoryKey $i', history[i]);
  }
}

Future<List<String>> getHistory() async {
  final history = <String>[];
  final prefs = await SharedPreferences.getInstance();
  for (var i = 0; i < 3; i++) {
    if (prefs.containsKey('$_searchHistoryKey $i')) {
      history.add(prefs.getString('$_searchHistoryKey $i')!);
    } else {
      break;
    }
  }
  return history;
}

Future<void> _cacheBusStops(List<BusStop> busStops) async {
  await _database.cacheBusStops(busStops);

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kAreBusStopsCachedKey, true);
}

Future<bool> areBusStopsCached() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(kAreBusStopsCachedKey);
}

Future<void> cacheBusServices(List<BusService> busServices) async {
  await _database.cacheBusServices(busServices);

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kAreBusServicesCachedKey, true);
}

Future<bool> areBusServicesCached() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(kAreBusServicesCachedKey);
}

Future<BusServiceWithRoutes> getCachedBusServiceWithRoutes(
    String serviceNumber) async {
  final service = await _database.getCachedBusService(serviceNumber);
  final routes = await getCachedBusRoutes(service);

  return BusServiceWithRoutes.fromBusService(service, routes);
}

Map<String, dynamic> busServiceRouteStopToJson(dynamic busStop) {
  final serviceNumber = busStop[kBusServiceNumberKey] as String;
  final direction = busStop[kBusServiceDirectionKey] as int;
  final busStopCode = busStop[kBusStopCodeKey] as String;
  final distance = double.parse(busStop[kBusStopDistanceKey].toString());

  final json = <String, dynamic>{
    'serviceNumber': serviceNumber,
    'direction': direction,
    'busStopCode': busStopCode,
    'distance': distance,
  };
  return json;
}

Future<void> cacheBusServiceRoutes(
    List<Map<String, dynamic>> busServiceRoutesRaw) async {
  await _database.cacheBusServiceRoutes(
      busServiceRoutesRaw.map(BusServiceRouteEntry.fromJson).toList());

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_areBusServiceRoutesCachedKey, true);
}

Future<bool> areBusServiceRoutesCached() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(_areBusServiceRoutesCachedKey);
}

Future<List<BusServiceRoute>> getCachedBusRoutes(BusService busService) async {
  return await _database.getCachedBusServiceRoutes(busService);
}

Future<List<BusService>> getPinnedServicesInRouteWithId(
    BusStop busStop, int routeId) async {
  return await _database.getPinnedServicesInRouteWithId(busStop, routeId);
}

@riverpod
Future<List<BusService>> busStopServices(
    BusStopServicesRef ref, BusStop busStop) async {
  return await _database.getServicesIn(busStop);
}
