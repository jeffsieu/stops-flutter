import 'dart:async';

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
const String _busServiceSkipNumberKey = 'BUS_SERVICE_SKIP';
const String _searchHistoryKey = 'SEARCH_HISTORY';
const String kAreBusStopsCachedKey = 'BUS_STOP_CACHE';
const String kAreBusServicesCachedKey = 'BUS_SERVICE_CACHE';
const String _areBusServiceRoutesCachedKey = 'BUS_ROUTE_CACHE';

final StopsDatabase _database = StopsDatabase();

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

  // TODO: Show 0% progress when re-fetching
  Future<void> fetchDataFromApi() async {
    await ref.read(busStopListProvider.notifier).fetchFromApi();

    ref.invalidateSelf();

    await ref.read(busServiceListProvider.notifier).fetchFromApi();

    ref.invalidateSelf();

    await ref
        .read(busServiceRouteListProvider(BusService(number: '', operator: ''))
            .notifier)
        .fetchFromApi();

    ref.invalidateSelf();
  }
}

@riverpod
class BusStopList extends _$BusStopList {
  @override
  Future<List<BusStop>> build() async {
    return await _database.getCachedBusStops();
  }

  Future<void> fetchFromApi() async {
    final busStopList = await ref.refresh(apiBusStopListProvider.future);

    await _cacheBusStops(busStopList);

    // TODO: Figure out why the following line breaks fetching
    // ref.invalidateSelf();
    // await future;
  }

  Future<void> updateBusStop(BusStop newBusStop) async {
    await _database.updateBusStop(newBusStop);

    ref.invalidateSelf();
    await future;
  }
}

@riverpod
Future<BusStop?> busStopWithCode(BusStopWithCodeRef ref, String code) async {
  final busStop = await ref.watch(busStopListProvider.selectAsync((busStops) =>
      busStops.firstWhereOrNull((busStop) => busStop.code == code)));
  return busStop;
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

    // TODO: Figure out why the following line breaks fetching
    // ref.invalidateSelf();
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

    // TODO: Figure out why the following line breaks fetching
    // ref.invalidateSelf();
  }
}

Future<List<StoredUserRoute>> _getUserRoutes() async {
  final routeEntries = await _database.getStoredUserRoutes();
  final routes = <StoredUserRoute>[];
  for (var routeEntry in routeEntries) {
    final busStops = await _getBusStopsInRouteWithId(routeEntry.id);

    routes.add(StoredUserRoute(
        id: routeEntry.id,
        name: routeEntry.name,
        color: Color(routeEntry.color),
        busStops: busStops));
  }
  return routes;
}

@riverpod
Future<List<BusStop>?> nearestBusStops(NearestBusStopsRef ref,
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
}

Future<List<BusStop>> _getBusStopsInRouteWithId(int routeId) async {
  return await _database.getBusStopsInRouteWithId(routeId);
}

@riverpod
Future<List<BusService>> pinnedServices(
    PinnedServicesRef ref, BusStop busStop, int routeId) async {
  final pinnedServices = await getPinnedServicesInRouteWithId(busStop, routeId);
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
  }
}

@riverpod
Future<bool> isBusServicePinned(IsBusServicePinnedRef ref,
    {required BusStop busStop,
    required BusService busService,
    required int routeId}) async {
  final pinnedServices =
      await ref.watch(pinnedServicesProvider(busStop, routeId).future);
  return pinnedServices.contains(busService);
}

@riverpod
Future<bool> isBusStopInRoute(IsBusStopInRouteRef ref,
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

Future<void> cacheBusServices(List<BusService> busServices) async {
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
    CachedBusServiceWithRoutesRef ref, String serviceNumber) async {
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
