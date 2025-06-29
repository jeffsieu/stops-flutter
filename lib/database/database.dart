import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stops_sg/bus_api/bus_api.dart';
import 'package:stops_sg/bus_api/models/bus_service.dart';
import 'package:stops_sg/bus_api/models/bus_service_route.dart';
import 'package:stops_sg/bus_api/models/bus_service_with_routes.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/database/stops_database.dart';
import 'package:stops_sg/location/location.dart';

part 'database.g.dart';

/* Called when bus service is pinned/unpinned for a bus stop*/
typedef BusPinStatusListener = void Function(
    String stop, String bus, bool isPinned);

const int kDefaultRouteId = -1;
const String defaultRouteName = 'Saved';
const String _themeModeKey = 'THEME_OPTION';
const String _searchHistoryKey = 'SEARCH_HISTORY';
const String kAreBusStopsCachedKey = 'BUS_STOP_CACHE';
const String kAreBusServicesCachedKey = 'BUS_SERVICE_CACHE';
const String _areBusServiceRoutesCachedKey = 'BUS_ROUTE_CACHE';

final StopsDatabase _database = StopsDatabase();

const kExpectedBusStopListLength = 5160;
const kExpectedBusServiceListLength = 748;
const kExpectedBusServiceRouteListLength = 25977;

Future<ThemeMode> _getThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final themeModeIndex = prefs.getInt(_themeModeKey) ?? ThemeMode.system.index;
  return ThemeMode.values[themeModeIndex];
}

Future<void> _setThemeMode(ThemeMode themeMode) async {
  final prefs = await SharedPreferences.getInstance();
  prefs.setInt(_themeModeKey, themeMode.index);
}

@riverpod
class SelectedThemeMode extends _$SelectedThemeMode {
  @override
  Future<ThemeMode> build() async {
    return await _getThemeMode();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    await _setThemeMode(themeMode);
    ref.invalidateSelf();
  }
}

@Riverpod(keepAlive: true)
class CachedDataProgress extends _$CachedDataProgress {
  @override
  Future<double> build() async {
    var progress = 0.0;
    final cachedBusStops = await areBusStopsCached();
    final cachedBusServices = await areBusServicesCached();
    final cachedBusServiceRoutes = await areBusServiceRoutesCached();

    if (cachedBusStops) {
      progress += 0.25;
    }
    if (cachedBusServices) {
      progress += 0.25;
    }
    if (cachedBusServiceRoutes) {
      progress += 0.5;
    }
    return progress;
  }

  Future<void> fetchDataFromApi(
      {required bool shouldResetCacheProgress}) async {
    if (shouldResetCacheProgress) {
      state = AsyncData(0);
      await resetCacheProgress();
      ref.invalidateSelf();
    }

    final busStopListProgressStream =
        ref.read(busStopListProvider.notifier).fetchFromApi();

    await for (final progress in busStopListProgressStream) {
      state = AsyncValue.data(progress * 0.25);
    }

    final busServiceListProgressStream =
        ref.read(busServiceListProvider.notifier).fetchFromApi();

    await for (final progress in busServiceListProgressStream) {
      state = AsyncValue.data(progress * 0.25 + 0.25);
    }

    final busServiceRouteListProgressStream = ref
        .read(busServiceRouteListProvider(BusService(number: '', operator: ''))
            .notifier)
        .fetchFromApi();

    await for (final progress in busServiceRouteListProgressStream) {
      state = AsyncValue.data(progress * 0.5 + 0.5);
    }

    ref.invalidateSelf();
  }
}

@Riverpod(keepAlive: true)
class BusStopList extends _$BusStopList
    with FetchFromApiMixin<BusStop, BusStop> {
  @override
  ProviderListenable<Raw<Stream<List<BusStop>>>> get apiProvider =>
      apiBusStopListProvider;
  @override
  int get expectedLength => kExpectedBusStopListLength;
  @override
  Future<void> Function(List<BusStop>) get cacheFunction => _cacheBusStops;

  @override
  Future<List<BusStop>> build() async {
    return await _database.getCachedBusStops();
  }

  Future<void> updateBusStop(BusStop newBusStop) async {
    await _database.updateBusStop(newBusStop);

    ref.invalidateSelf();
    await future;
  }
}

mixin FetchFromApiMixin<T, U> on AnyNotifier<AsyncValue<List<T>>, List<T>> {
  ProviderListenable<Raw<Stream<List<U>>>> get apiProvider;
  int get expectedLength;
  Future<void> Function(List<U>) get cacheFunction;

  Stream<double> fetchFromApi() async* {
    final stream = ref.read(apiProvider);

    var last = <U>[];
    await for (final items in stream) {
      yield min(items.length / expectedLength, 1.0);
      last = items;
    }

    // Cache the last value
    await cacheFunction(last);
    ref.invalidateSelf();
  }
}

@riverpod
Future<BusStop?> busStopWithCode(Ref ref, String code) async {
  final busStop = await ref.watch(busStopListProvider.selectAsync((busStops) =>
      busStops.firstWhereOrNull((busStop) => busStop.code == code)));
  return busStop;
}

@Riverpod(keepAlive: true)
class BusServiceList extends _$BusServiceList
    with FetchFromApiMixin<BusService, BusService> {
  @override
  ProviderListenable<Raw<Stream<List<BusService>>>> get apiProvider =>
      apiBusServiceListProvider;

  @override
  int get expectedLength => kExpectedBusServiceListLength;

  @override
  Future<void> Function(List<BusService>) get cacheFunction =>
      _cacheBusServices;

  @override
  Future<List<BusService>> build() async {
    return await _database.getCachedBusServices();
  }
}

@Riverpod(keepAlive: true)
class BusServiceRouteList extends _$BusServiceRouteList
    with FetchFromApiMixin<BusServiceRoute, BusServiceRouteEntry> {
  @override
  ProviderListenable<Raw<Stream<List<BusServiceRouteEntry>>>> get apiProvider =>
      apiBusServiceRouteListProvider;

  @override
  int get expectedLength => kExpectedBusServiceRouteListLength;

  @override
  Future<void> Function(List<BusServiceRouteEntry>) get cacheFunction =>
      _cacheBusServiceRoutes;

  @override
  Future<List<BusServiceRoute>> build(BusService busService) async {
    return await getCachedBusRoutes(busService);
  }
}

Future<List<StoredUserRoute>> _getUserRoutes() async {
  final routeEntries = await _database.getStoredUserRoutes();

  return await Future.wait(routeEntries.map((routeEntry) async {
    final busStops = await _getBusStopsInRouteWithId(routeEntry.id);

    return StoredUserRoute(
      id: routeEntry.id,
      name: routeEntry.name,
      color: Color(routeEntry.color),
      busStops: busStops,
    );
  }));
}

@riverpod
Future<List<BusStop>?> nearestBusStops(Ref ref,
    {required String busServiceFilter,
    required Duration minimumRefreshDuration}) async {
  // Wait at least 300ms before refreshing
  final stopwatch = Stopwatch()..start();

  final locationData = await ref
      .watch(userLocationProvider.selectAsync((snapshot) => snapshot.data));

  if (locationData == null) {
    stopwatch.stop();
    return null;
  }

  final result = await _database.getNearestBusStops((
    latitude: locationData.latitude!,
    longitude: locationData.longitude!,
  ), busServiceFilter);

  // Wait at least 300ms before refreshing
  if (stopwatch.elapsed < minimumRefreshDuration) {
    await Future.delayed(minimumRefreshDuration - stopwatch.elapsed);
  }

  stopwatch.stop();

  return result;
}

Future<List<BusStop>> _getBusStopsInRouteWithId(int routeId) async {
  return await _database.getBusStopsInRouteWithId(routeId);
}

@riverpod
Future<List<BusService>> pinnedServices(
    Ref ref, BusStop busStop, int routeId) async {
  final pinnedServices = await getPinnedServicesInRouteWithId(busStop, routeId);

  ref.cacheFor(const Duration(hours: 1));

  return pinnedServices;
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
    await future;
  }

  Future<void> updateRoute(StoredUserRoute route) async {
    final currentValue = await future;
    // Optimistic update
    final newRoutes = currentValue.map((oldRoute) {
      if (oldRoute.id == route.id) {
        return route;
      }

      return oldRoute;
    }).toList();
    state = AsyncValue.data(newRoutes);

    await _database.updateUserRoute(route);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteRoute(StoredUserRoute route) async {
    await _database.deleteUserRoute(id: route.id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> moveUserRoutePosition(int from, int to) async {
    await _database.moveUserRoutePosition(from, to);
    ref.invalidateSelf();
    await future;
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

    await future;
  }

  Future<void> removeBusStop(BusStop busStop) async {
    await _database.removeBusStopFromRoute(busStop, id);
    ref.invalidateSelf();
    ref.invalidate(savedUserRoutesProvider);

    await future;
  }

  Future<void> pinBusService(
      {required BusStop busStop, required BusService busService}) async {
    await _database.pinBusService(
        busStop: busStop, busService: busService, routeId: id);
    ref.invalidateSelf();
    ref.invalidate(savedUserRoutesProvider);

    await future;
  }

  Future<void> unpinBusService(
      {required BusStop busStop, required BusService busService}) async {
    await _database.unpinBusService(
        busStop: busStop, busService: busService, routeId: id);
    ref.invalidateSelf();
    ref.invalidate(savedUserRoutesProvider);

    await future;
  }

  Future<void> delete(StoredUserRoute userRoute) async {
    await _database.deleteUserRoute(id: id);
    ref.invalidateSelf();
    ref.invalidate(savedUserRoutesProvider);

    await future;
  }

  Future<void> moveBusStop(int from, int to) async {
    final currentValue = await future;
    // Optimistic update
    if (currentValue != null) {
      final newBusStops = [...currentValue.busStops];
      final busStop = newBusStops.removeAt(from);
      newBusStops.insert(to, busStop);
      state = AsyncValue.data(currentValue.copyWith(busStops: newBusStops));
    }

    await _database.moveBusStopPositionInRoute(from: from, to: to, routeId: id);
    ref.invalidateSelf();
    ref.invalidate(savedUserRoutesProvider);

    await future;
  }
}

@riverpod
Future<bool> isBusServicePinned(Ref ref,
    {required BusStop busStop,
    required BusService busService,
    required int routeId}) async {
  final pinnedServices =
      await ref.watch(pinnedServicesProvider(busStop, routeId).future);
  return pinnedServices.contains(busService);
}

@riverpod
Future<bool> isBusStopInRoute(Ref ref,
    {required BusStop busStop, required int routeId}) async {
  return await ref.watch(savedUserRouteProvider(id: routeId).selectAsync(
      (data) => (data?.busStops ?? []).any((b) => b.code == busStop.code)));
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

Future<void> _cacheBusServices(List<BusService> busServices) async {
  await _database.cacheBusServices(busServices);

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kAreBusServicesCachedKey, true);
}

Future<bool> areBusServicesCached() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.containsKey(kAreBusServicesCachedKey);
}

@riverpod
Future<BusServiceWithRoutes> cachedBusServiceWithRoutes(
    Ref ref, String serviceNumber) async {
  final service = await _database.getCachedBusService(serviceNumber);
  final routes = await getCachedBusRoutes(service);

  return BusServiceWithRoutes.fromBusService(service, routes);
}

Future<void> resetCacheProgress() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kAreBusStopsCachedKey);
  await prefs.remove(kAreBusServicesCachedKey);
  await prefs.remove(_areBusServiceRoutesCachedKey);
}

BusServiceRouteEntry parseBusServiceRouteStop(dynamic busStop) {
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

  return BusServiceRouteEntry.fromJson(json);
}

Future<void> _cacheBusServiceRoutes(
    List<BusServiceRouteEntry> busServiceRoutes) async {
  await _database.cacheBusServiceRoutes(busServiceRoutes);

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
Future<List<BusService>> busStopServices(Ref ref, BusStop busStop) async {
  return await _database.getServicesIn(busStop);
}
