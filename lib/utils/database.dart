// ignore_for_file: always_specify_types

import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bus_service.dart';
import '../models/bus_service_route.dart';
import '../models/bus_stop.dart';
import '../models/bus_stop_with_distance.dart';
import '../models/user_route.dart';
import 'database/shared.dart';
import 'database_utils.dart';
import 'distance_utils.dart';

part 'database.g.dart';

const int defaultRouteId = -1;
const String defaultRouteName = 'Home';
const String _areBusStopsCachedKey = 'BUS_STOP_CACHE';

@DataClassName('BusStopEntry')
class BusStops extends Table {
  @override
  String get tableName => 'bus_stop';

  TextColumn get code => text().withLength(min: 5, max: 5)();
  TextColumn get displayName => text().named('displayName')();
  TextColumn get defaultName => text().named('defaultName')();
  TextColumn get road => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  @override
  Set<Column<dynamic>> get primaryKey => {code};
}

@DataClassName('BusServiceEntry')
class BusServices extends Table {
  @override
  String get tableName => 'bus_service';

  TextColumn get number => text().withLength(max: 4)();
  TextColumn get operator => text()();

  @override
  Set<Column<dynamic>> get primaryKey => {number};
}

@DataClassName('BusServiceRouteEntry')
class BusRoutes extends Table {
  @override
  String get tableName => 'bus_route';

  TextColumn get serviceNumber => text()
      .named('serviceNumber')
      .withLength(max: 4)
      .references(BusServices, #number)();
  IntColumn get direction => integer()();
  TextColumn get busStopCode => text()
      .named('busStopCode')
      .withLength(min: 5, max: 5)
      .references(BusStops, #code)();
  RealColumn get distance => real()();

  @override
  Set<Column<dynamic>> get primaryKey =>
      {serviceNumber, direction, busStopCode};
}

@DataClassName('UserRouteEntry')
class UserRoutes extends Table {
  @override
  String get tableName => 'user_route';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  IntColumn get position => integer()();
}

@DataClassName('UserRouteBusStopEntry')
class UserRouteBusStops extends Table {
  @override
  String get tableName => 'user_route_bus_stop';

  IntColumn get routeId =>
      integer().named('routeId').references(UserRoutes, #id)();
  TextColumn get busStopCode => text()
      .named('busStopCode')
      .withLength(min: 5, max: 5)
      .references(BusStops, #code)();
  IntColumn get position => integer()();

  @override
  Set<Column<dynamic>> get primaryKey => {routeId, busStopCode};
}

@DataClassName('PinnedBusServiceEntry')
class PinnedBusServices extends Table {
  @override
  String get tableName => 'pinned_bus_service';

  IntColumn get routeId =>
      integer().named('routeId').references(UserRouteBusStops, #routeId)();
  TextColumn get busStopCode => text()
      .named('busStopCode')
      .withLength(min: 5, max: 5)
      .references(UserRouteBusStops, #busStopCode)();
  TextColumn get busServiceNumber => text()
      .named('busServiceNumber')
      .withLength(max: 4)
      .references(BusServices, #number)();
}

@DriftDatabase(
  tables: [
    BusStops,
    BusServices,
    BusRoutes,
    UserRoutes,
    UserRouteBusStops,
    PinnedBusServices,
  ],
)
class StopsDatabase extends _$StopsDatabase {
  StopsDatabase(QueryExecutor e) : super(e);

  static StopsDatabase create() {
    return constructDatabase(logStatements: true);
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (Migrator m, int from, int to) async {
          // if (from == 1 && to == 2) {
          await m.recreateAllViews();
          await into(userRoutes).insert(UserRouteEntry(
            id: defaultRouteId,
            name: defaultRouteName,
            position: -1,
            color: 0,
          ));
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_areBusStopsCachedKey, false);
          // }
        },
        onCreate: (Migrator m) async {
          await m.createAll();
          await into(userRoutes).insert(UserRouteEntry(
            id: defaultRouteId,
            name: defaultRouteName,
            position: -1,
            color: 0,
          ));
        },
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<List<BusStopWithDistance>> getNearestBusStops(
      double latitude, double longitude, String busServiceFilter) async {
    if (busServiceFilter.isNotEmpty) {
      // Make sure that bus service is an integer
      final int? busService = int.tryParse(busServiceFilter);
      if (busService == null && busServiceFilter.isNotEmpty) {
        return <BusStopWithDistance>[];
      }
    }

    final latitudeDifference = busStops.latitude - Variable(latitude);
    final longitudeDifference = busStops.longitude - Variable(longitude);
    final distance = latitudeDifference * latitudeDifference +
        longitudeDifference * longitudeDifference;

    final query = select(busStops).addColumns([distance])
      ..orderBy([OrderingTerm(expression: distance)]);

    if (busServiceFilter.isNotEmpty) {
      query.where(busStops.code.isInQuery(
          selectOnly(busRoutes)..addColumns([busRoutes.busStopCode])));
    }

    final result = await query.get();

    return result.map((TypedResult row) {
      final BusStopEntry busStopEntry = row.readTable(busStops);
      final double distanceMeters = metersBetween(
          latitude, longitude, busStopEntry.latitude, busStopEntry.longitude);
      return BusStopWithDistance(busStopEntry.toModel(), distanceMeters);
    }).toList();
  }

  Future<void> updateBusStop(BusStop busStop) async {
    final BusStopEntry entry = busStop.toEntry();
    await update(busStops).replace(entry);
  }

  Future<List<BusStop>> getBusStopsInRoute(UserRoute route) async {
    final query = select(busStops).join([
      innerJoin(userRouteBusStops,
          busStops.code.equalsExp(userRouteBusStops.busStopCode))
    ])
      ..where(userRouteBusStops.routeId.equals(route.id))
      ..orderBy([OrderingTerm(expression: userRouteBusStops.position)]);
    final results = await query.get();
    return results.map((e) => e.readTable(busStops).toModel()).toList();
  }

  Future<void> addBusStopToRoute(BusStop busStop, UserRoute route) async {
    final newBusStopPositionColumn = userRouteBusStops.position.count();
    final newBusStopPositionQuery = selectOnly(userRouteBusStops)
      ..addColumns([])
      ..where(userRouteBusStops.routeId.equals(route.id));
    final int newBusStopPosition = (await newBusStopPositionQuery.getSingle())
        .read(newBusStopPositionColumn);
    await into(userRouteBusStops).insert(UserRouteBusStopEntry(
      routeId: route.id!,
      busStopCode: busStop.code,
      position: newBusStopPosition,
    ));
  }

  Future<void> removeBusStopFromRoute(BusStop busStop, UserRoute route) async {
    final int removedPosition = (await (select(userRouteBusStops)
              ..where((u) => u.routeId.equals(route.id))
              ..where((u) => u.busStopCode.equals(busStop.code)))
            .getSingle())
        .position;
    await (delete(userRouteBusStops)
          ..where((u) => u.routeId.equals(route.id))
          ..where((u) => u.busStopCode.equals(busStop.code)))
        .go();
    final incrementPosition = UserRouteBusStopsCompanion.custom(
        position: coalesce([
      userRouteBusStops.position + const Constant(1),
      const Constant(0)
    ]));
    await (update(userRouteBusStops)
          ..where((u) => u.routeId.equals(route.id))
          ..where((u) => u.position.isBiggerThanValue(removedPosition)))
        .write(incrementPosition);
  }

  Future<bool> isBusStopInRoute(BusStop busStop, UserRoute route) async {
    final query = select(userRouteBusStops)
      ..where((u) => u.routeId.equals(route.id))
      ..where((u) => u.busStopCode.equals(busStop.code));
    return await query.getSingleOrNull() != null;
  }

  Future<void> storeUserRoute(UserRoute route) async {
    // Select number of rows from user route
    final newRoutePositionQuery = selectOnly(userRoutes)
      ..addColumns([userRoutes.id.count()]);
    final int newRoutePosition =
        (await newRoutePositionQuery.getSingle()).read(userRoutes.id.count()) -
            1;

    await transaction(() async {
      // Insert new route
      final int newRouteId =
          await into(userRoutes).insert(route.toEntry(newRoutePosition));

      // Insert new bus stops
      for (int position = 0; position < route.busStops.length; position++) {
        final BusStop busStop = route.busStops[position];
        await into(userRouteBusStops).insert(UserRouteBusStopEntry(
          routeId: newRouteId,
          busStopCode: busStop.code,
          position: position,
        ));
      }
    });
  }

  Future<void> updateUserRoute(UserRoute route) async {
    assert(route.id != null);
    await transaction(() async {
      await update(userRoutes).replace(route.toCompanion());

      // Remove all bus stops from route
      await (delete(userRouteBusStops)
            ..where((u) => u.routeId.equals(route.id!)))
          .go();

      // Insert new bus stops
      for (int position = 0; position < route.busStops.length; position++) {
        final BusStop busStop = route.busStops[position];
        await into(userRouteBusStops).insert(UserRouteBusStopEntry(
          routeId: route.id!,
          busStopCode: busStop.code,
          position: position,
        ));
      }
    });
  }

  Future<void> deleteUserRoute(UserRoute route) async {
    final int position = (await (select(userRoutes)
              ..where((u) => u.id.equals(route.id!)))
            .getSingle())
        .position;

    await transaction(() async {
      await (delete(userRoutes)..where((u) => u.id.equals(route.id))).go();

      // Shift all positions down by 1
      final Insertable<UserRouteEntry> decrementPosition =
          UserRoutesCompanion.custom(
              position: coalesce([
        userRoutes.position - const Constant<int>(1),
        const Constant<int>(0)
      ]));
      await (update(userRoutes)
            ..where((u) => u.position.isBiggerThanValue(position)))
          .write(decrementPosition);
    });
  }

  Future<List<UserRoute>> getUserRoutes() async {
    final query = select(userRoutes)
      ..where((ur) => ur.id.equals(defaultRouteId).not())
      ..orderBy([(ur) => OrderingTerm(expression: ur.position)]);
    final results = await query.get();
    final List<UserRoute> routes = results.map((e) => e.toModel()).toList();
    return routes;
  }

  Future<void> moveUserRoutePosition(int from, int to) async {
    final int direction = (to - from).sign;
    await transaction(() async {
      // Change from's position to -2
      await (update(userRoutes)..where((u) => u.position.equals(from)))
          .write(UserRoutesCompanion.custom(position: const Constant(-2)));

      // Shift everything after 'from' one step closer to 'from'
      final shiftPosition = UserRoutesCompanion.custom(
          position: coalesce(
              [userRoutes.position + Variable(direction), const Constant(0)]));

      for (int i = from; i != to; i += direction) {
        await (update(userRoutes)..where((u) => u.position.equals(i)))
            .write(shiftPosition);
      }

      // Change from's position ot to
      await (update(userRoutes)..where((u) => u.position.equals(-2)))
          .write(UserRoutesCompanion.custom(position: Variable(to)));
    });
  }

  Future<void> moveBusStopPositionInRoute(
      int from, int to, UserRoute route) async {
    final int direction = (to - from).sign;
    await transaction(() async {
      // Change from's position to -2
      await (update(userRouteBusStops)
            ..where((u) => u.routeId.equals(route.id))
            ..where((u) => u.position.equals(from)))
          .write(
              UserRouteBusStopsCompanion.custom(position: const Constant(-2)));

      // Shift everything after 'from' one step closer to 'from'
      final shiftPosition = UserRouteBusStopsCompanion.custom(
          position: coalesce([
        userRouteBusStops.position + Variable(direction),
        const Constant(0)
      ]));

      for (int i = from; i != to; i += direction) {
        await (update(userRouteBusStops)
              ..where((u) => u.routeId.equals(route.id))
              ..where((u) => u.position.equals(i)))
            .write(shiftPosition);
      }

      // Change from's position ot to
      await (update(userRouteBusStops)
            ..where((u) => u.routeId.equals(route.id))
            ..where((u) => u.position.equals(-2)))
          .write(UserRouteBusStopsCompanion.custom(position: Variable(to)));
    });
  }

  Future<void> cacheBusStops(List<BusStop> busStopList) async {
    await transaction(() async {
      for (BusStop busStop in busStopList) {
        await into(busStops)
            .insert(busStop.toEntry(), mode: InsertMode.replace);
      }
    });
  }

  Future<List<BusStop>> getCachedBusStops() async {
    final result = await (select(busStops)).get();
    return result.map((e) => e.toModel()).toList();
  }

  Future<BusStop> getCachedBusStopWithCode(String code) async {
    assert(await areBusStopsCached());
    final result =
        await (select(busStops)..where((b) => b.code.equals(code))).getSingle();
    return result.toModel();
  }

  Future<void> cacheBusServices(List<BusService> busServiceList) async {
    await transaction(() async {
      for (BusService busService in busServiceList) {
        await into(busServices)
            .insert(busService.toEntry(), mode: InsertMode.replace);
      }
    });
  }

  Future<List<BusService>> getCachedBusServices() async {
    final result = await (select(busServices)).get();
    return result.map((e) => e.toModel()).toList();
  }

  Future<BusService> getCachedBusService(String serviceNumber) async {
    assert(await areBusServicesCached());
    final result = await (select(busServices)
          ..where((b) => b.number.equals(serviceNumber)))
        .getSingle();
    return result.toModel();
  }

  Future<void> cacheBusServiceRoutes(
      List<Map<String, dynamic>> busServiceRoutesRaw) async {
    await transaction(() async {
      for (Map<String, dynamic> busServiceRouteRaw in busServiceRoutesRaw) {
        await into(busRoutes).insert(
            BusServiceRouteEntry.fromJson(busServiceRouteRaw),
            mode: InsertMode.replace);
      }
    });
  }

  Future<List<BusServiceRoute>> getCachedBusRoutes(
      BusService busService) async {
    assert(await areBusServiceRoutesCached());
    final result = await (select(busRoutes)
          ..where((b) => b.serviceNumber.equals(busService.number))
          ..orderBy([
            (busRoute) => OrderingTerm(expression: busRoute.distance),
          ]))
        .get();
    final Map<int, List<BusStopWithDistance>> routeBusStops =
        <int, List<BusStopWithDistance>>{};

    for (BusServiceRouteEntry entry in result) {
      final int direction = entry.direction;
      final BusStop busStop = await getCachedBusStopWithCode(entry.busStopCode);
      final BusStopWithDistance busStopWithDistance =
          BusStopWithDistance(busStop, entry.distance);

      routeBusStops.putIfAbsent(direction, () => <BusStopWithDistance>[]);
      routeBusStops[direction]!.add(busStopWithDistance);
    }

    return routeBusStops.entries.map((entry) {
      return BusServiceRoute(
        service: busService,
        direction: entry.key,
        busStops: entry.value,
      );
    }).toList();
  }

  Future<void> pinBusService(
      BusStop busStop, BusService busService, UserRoute route) async {
    await into(pinnedBusServices).insert(
      PinnedBusServiceEntry(
          routeId: route.id!,
          busStopCode: busStop.code,
          busServiceNumber: busService.number),
    );
  }

  Future<void> unpinBusService(
      BusStop busStop, BusService busService, UserRoute route) async {
    await (delete(pinnedBusServices)
          ..where((p) => p.routeId.equals(route.id))
          ..where((p) => p.busStopCode.equals(busStop.code))
          ..where((p) => p.busServiceNumber.equals(busService.number)))
        .go();
  }

  Future<bool> isBusServicePinned(
      BusStop busStop, BusService busService, UserRoute route) async {
    final result = await (select(pinnedBusServices)
          ..where((p) => p.routeId.equals(route.id ?? defaultRouteId))
          ..where((p) => p.busStopCode.equals(busStop.code))
          ..where((p) => p.busServiceNumber.equals(busService.number)))
        .getSingleOrNull();
    return result != null;
  }

  Future<List<BusService>> getPinnedServicesIn(
      BusStop busStop, UserRoute route) async {
    //  'SELECT * FROM pinned_bus_service INNER JOIN bus_service '
    // 'ON pinned_bus_service.busServiceNumber = bus_service.number '
    // 'WHERE routeId = ? and pinned_bus_service.busStopCode = ?',

    final result = await (select(pinnedBusServices).join([
      innerJoin(busServices,
          pinnedBusServices.busServiceNumber.equalsExp(busServices.number)),
    ])
          ..where(pinnedBusServices.routeId.equals(route.id))
          ..where(pinnedBusServices.busStopCode.equals(busStop.code))
          ..orderBy([
            OrderingTerm(expression: pinnedBusServices.busServiceNumber),
          ]))
        .get();

    return result.map((e) => e.readTable(busServices).toModel()).toList();
  }

  Future<List<BusService>> getServicesIn(BusStop busStop) async {
    //   final List<Map<String, dynamic>> result = await database.rawQuery(
    //   'SELECT * FROM (SELECT DISTINCT(serviceNumber) FROM bus_route WHERE busStopCode = ?) INNER JOIN bus_service '
    //   'ON serviceNumber = bus_service.number',
    //   <String>[busStop.code],
    // );

    final result = await (select(busServices)
          ..where((bs) => bs.number.isInQuery(selectOnly(busRoutes)
            ..where(busRoutes.busStopCode.equals(busStop.code))
            ..addColumns([busRoutes.serviceNumber])))
          ..orderBy([
            (busService) => OrderingTerm(expression: busService.number),
          ]))
        .get();

    return result.map((e) => e.toModel()).toList();
  }
}

extension on BusStop {
  BusStopEntry toEntry() {
    return BusStopEntry(
      code: code,
      displayName: displayName,
      defaultName: defaultName,
      road: road,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

extension on BusService {
  BusServiceEntry toEntry() {
    return BusServiceEntry(
      number: number,
      operator: operator,
    );
  }
}

extension on UserRoute {
  UserRouteEntry toEntry(int position) {
    return UserRouteEntry(
      id: id!,
      name: name,
      color: color.value,
      position: position,
    );
  }

  UserRoutesCompanion toCompanion() {
    return UserRoutesCompanion(
      name: Value<String>(name),
      color: Value<int>(color.value),
    );
  }
}

extension on BusStopEntry {
  BusStop toModel() {
    return BusStop(
      code: code,
      displayName: displayName,
      defaultName: defaultName,
      road: road,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

extension on BusServiceEntry {
  BusService toModel() {
    return BusService(
      number: number,
      operator: operator,
    );
  }
}

extension on UserRouteEntry {
  UserRoute toModel() {
    return UserRoute(
      id: id,
      name: name,
      color: Color(color),
    );
  }
}
