import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stops_sg/bus_api/models/bus_service.dart';
import 'package:stops_sg/bus_api/models/bus_service_route.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/database/connection/connection.dart' as impl;
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/utils/bus_utils.dart';

part 'stops_database.g.dart';

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
  Set<Column> get primaryKey => {code};
}

@DataClassName('BusServiceEntry')
class BusServices extends Table {
  @override
  String get tableName => 'bus_service';

  TextColumn get number => text().withLength(max: 4)();
  TextColumn get operator => text()();

  @override
  Set<Column> get primaryKey => {number};
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
  Set<Column> get primaryKey => {serviceNumber, direction, busStopCode};
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

  IntColumn get routeId => integer()
      .named('routeId')
      .references(UserRoutes, #id, onDelete: KeyAction.cascade)();
  TextColumn get busStopCode => text()
      .named('busStopCode')
      .withLength(min: 5, max: 5)
      .references(BusStops, #code)();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {routeId, busStopCode};
}

@DataClassName('PinnedBusServiceEntry')
class PinnedBusServices extends Table {
  @override
  String get tableName => 'pinned_bus_service';

  IntColumn get routeId => integer().named('routeId')();
  TextColumn get busStopCode =>
      text().named('busStopCode').withLength(min: 5, max: 5)();
  TextColumn get busServiceNumber => text()
      .named('busServiceNumber')
      .withLength(max: 4)
      .references(BusServices, #number)();

  @override
  List<String> get customConstraints => [
        // Custom constraint to reference composite primary key
        'FOREIGN KEY (routeId, busStopCode) REFERENCES user_route_bus_stop (routeId, busStopCode) ON DELETE CASCADE',
      ];
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
  StopsDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'busstop_database',
      web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
          onResult: (result) {
            if (result.missingFeatures.isNotEmpty) {
              debugPrint(
                  'Using ${result.chosenImplementation} due to unsupported '
                  'browser features: ${result.missingFeatures}');
            }
          }),
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (Migrator m, int from, int to) async {
          // if (from == 1 && to == 2) {
          await m.recreateAllViews();
          await into(userRoutes).insert(const UserRouteEntry(
            id: kDefaultRouteId,
            name: defaultRouteName,
            position: -1,
            color: 0,
          ));
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(kAreBusStopsCachedKey, false);
          // }
        },
        onCreate: (Migrator m) async {
          await m.createAll();
          await into(userRoutes).insert(const UserRouteEntry(
            id: kDefaultRouteId,
            name: defaultRouteName,
            position: -1,
            color: 0,
          ));
        },
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON');

          await impl.validateDatabaseSchema(this);
        },
      );

  Future<List<BusStop>> getNearestBusStops(
      ({double latitude, double longitude}) location,
      String busServiceFilter) async {
    final latitude = location.latitude;
    final longitude = location.longitude;

    if (busServiceFilter.isNotEmpty) {
      // Make sure that bus service is an integer
      final busService = int.tryParse(busServiceFilter);
      if (busService == null && busServiceFilter.isNotEmpty) {
        return [];
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

    return Future.wait(result.map((TypedResult row) async {
      final busStopEntry = row.readTable(busStops);
      final busStop = busStopEntry.toModel();

      return busStop;
    }));
  }

  Future<void> updateBusStop(BusStop busStop) async {
    final entry = busStop.toEntry();
    await update(busStops).replace(entry);
  }

  Future<UserRouteEntry> getRouteEntryWithId(int routeId) async {
    final query = select(userRoutes)
      ..where((ur) => ur.id.equals(routeId))
      ..orderBy([(ur) => OrderingTerm(expression: ur.position)]);
    final results = await query.get();

    final entry = results.first;

    if (entry.id == kDefaultRouteId) {
      return entry.copyWith(name: defaultRouteName);
    }

    return entry;
  }

  Future<List<BusStop>> getBusStopsInRouteWithId(int routeId) async {
    final query = select(busStops).join([
      innerJoin(userRouteBusStops,
          busStops.code.equalsExp(userRouteBusStops.busStopCode))
    ])
      ..where(userRouteBusStops.routeId.equals(routeId))
      ..orderBy([OrderingTerm(expression: userRouteBusStops.position)]);
    final results = await query.get();
    return results.map((e) => e.readTable(busStops).toModel()).toList();
  }

  Future<void> addBusStopToRouteWithId(BusStop busStop, int routeId) async {
    final newBusStopPositionColumn = userRouteBusStops.position.count();
    final newBusStopPositionQuery = selectOnly(userRouteBusStops)
      ..addColumns([newBusStopPositionColumn])
      ..where(userRouteBusStops.routeId.equals(routeId));
    final newBusStopPosition = (await newBusStopPositionQuery.getSingle())
        .read(newBusStopPositionColumn)!;
    await into(userRouteBusStops).insert(UserRouteBusStopEntry(
      routeId: routeId,
      busStopCode: busStop.code,
      position: newBusStopPosition,
    ));
  }

  Future<void> removeBusStopFromRoute(BusStop busStop, int routeId) async {
    final removedPosition = (await (select(userRouteBusStops)
              ..where((u) => u.routeId.equals(routeId))
              ..where((u) => u.busStopCode.equals(busStop.code)))
            .getSingle())
        .position;
    await (delete(userRouteBusStops)
          ..where((u) => u.routeId.equals(routeId))
          ..where((u) => u.busStopCode.equals(busStop.code)))
        .go();
    final incrementPosition = UserRouteBusStopsCompanion.custom(
        position: coalesce([
      userRouteBusStops.position + const Constant(1),
      const Constant(0)
    ]));
    await (update(userRouteBusStops)
          ..where((u) => u.routeId.equals(routeId))
          ..where((u) => u.position.isBiggerThanValue(removedPosition)))
        .write(incrementPosition);
  }

  Future<bool> isBusStopInRouteWithId(BusStop busStop, int routeId) async {
    final query = select(userRouteBusStops)
      ..where((u) => u.routeId.equals(routeId))
      ..where((u) => u.busStopCode.equals(busStop.code));
    return await query.getSingleOrNull() != null;
  }

  Future<void> addUserRoute(UserRoute route) async {
    // Select number of rows from user route
    final newRoutePositionQuery = selectOnly(userRoutes)
      ..addColumns([userRoutes.id.count()]);
    final newRoutePosition =
        (await newRoutePositionQuery.getSingle()).read(userRoutes.id.count())! -
            1;

    // Insert new route
    final newRouteId = await into(userRoutes)
        .insert(route.toInsertCompanion(newRoutePosition));

    // Insert new bus stops
    for (var position = 0; position < route.busStops.length; position++) {
      final busStop = route.busStops[position];
      await into(userRouteBusStops).insert(UserRouteBusStopEntry(
        routeId: newRouteId,
        busStopCode: busStop.code,
        position: position,
      ));
    }
    // });
  }

  Future<void> updateUserRoute(StoredUserRoute route) async {
    await transaction(() async {
      await (update(userRoutes)..where((ur) => ur.id.equals(route.id)))
          .write(route.toCompanion());

      // TODO: handle the case when bus stops are pinned: foreign key constraint

      // Remove all bus stops from route
      await (delete(userRouteBusStops)
            ..where((u) => u.routeId.equals(route.id)))
          .go();

      // Insert new bus stops
      for (var position = 0; position < route.busStops.length; position++) {
        final busStop = route.busStops[position];
        await into(userRouteBusStops).insert(UserRouteBusStopEntry(
          routeId: route.id,
          busStopCode: busStop.code,
          position: position,
        ));
      }
    });
  }

  Future<void> deleteUserRoute({required int id}) async {
    final position =
        (await (select(userRoutes)..where((u) => u.id.equals(id))).getSingle())
            .position;

    await transaction(() async {
      await (delete(pinnedBusServices)..where((p) => p.routeId.equals(id)))
          .go();
      await (delete(userRouteBusStops)..where((u) => u.routeId.equals(id)))
          .go();
      await (delete(userRoutes)..where((u) => u.id.equals(id))).go();

      // Shift all positions down by 1
      final decrementPosition = UserRoutesCompanion.custom(
          position: coalesce([
        userRoutes.position - const Constant<int>(1),
        const Constant<int>(0)
      ]));
      await (update(userRoutes)
            ..where((u) => u.position.isBiggerThanValue(position)))
          .write(decrementPosition);
    });
  }

  Future<List<UserRouteEntry>> getStoredUserRoutes() async {
    final query = select(userRoutes)
      ..orderBy([(ur) => OrderingTerm(expression: ur.position)]);
    final results = await query.get();

    return results.map((entry) {
      if (entry.id == kDefaultRouteId) {
        return entry.copyWith(name: defaultRouteName);
      }

      return entry;
    }).toList();
  }

  Future<void> moveUserRoutePosition(int from, int to) async {
    final direction = (to - from).sign;
    await transaction(() async {
      // Change from's position to -2
      await (update(userRoutes)..where((u) => u.position.equals(from)))
          .write(UserRoutesCompanion.custom(position: const Constant(-2)));

      // Shift everything after 'from' one step closer to 'from'
      final shiftPosition = UserRoutesCompanion.custom(
          position: coalesce(
              [userRoutes.position + Variable(direction), const Constant(0)]));

      for (var i = from; i != to; i += direction) {
        await (update(userRoutes)..where((u) => u.position.equals(i)))
            .write(shiftPosition);
      }

      // Change from's position ot to
      await (update(userRoutes)..where((u) => u.position.equals(-2)))
          .write(UserRoutesCompanion.custom(position: Variable(to)));
    });
  }

  Future<void> moveBusStopPositionInRoute(
      {required int from, required int to, required int routeId}) async {
    final direction = (to - from).sign;
    await transaction(() async {
      // Change from's position to -2
      await (update(userRouteBusStops)
            ..where((u) => u.routeId.equals(routeId))
            ..where((u) => u.position.equals(from)))
          .write(
              UserRouteBusStopsCompanion.custom(position: const Constant(-2)));

      // Shift everything after 'from' one step closer to 'from'
      final shiftPosition = UserRouteBusStopsCompanion.custom(
          position: coalesce([
        userRouteBusStops.position + Variable(direction),
        const Constant(0)
      ]));

      for (var i = from; i != to; i += direction) {
        await (update(userRouteBusStops)
              ..where((u) => u.routeId.equals(routeId))
              ..where((u) => u.position.equals(i)))
            .write(shiftPosition);
      }

      // Change from's position ot to
      await (update(userRouteBusStops)
            ..where((u) => u.routeId.equals(routeId))
            ..where((u) => u.position.equals(-2)))
          .write(UserRouteBusStopsCompanion.custom(position: Variable(to)));
    });
  }

  Future<void> cacheBusStops(List<BusStop> busStopList) async {
    await transaction(() async {
      for (var busStop in busStopList) {
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
      for (var busService in busServiceList) {
        await into(busServices)
            .insert(busService.toEntry(), mode: InsertMode.replace);
      }
    });
  }

  Future<List<BusService>> getCachedBusServices() async {
    final result = await (select(busServices)).get();
    return result
        .map((e) => e.toModel())
        .sorted((a, b) => compareBusNumber(a.number, b.number))
        .toList();
  }

  Future<BusService> getCachedBusService(String serviceNumber) async {
    assert(await areBusServicesCached());
    final result = await (select(busServices)
          ..where((b) => b.number.equals(serviceNumber)))
        .getSingle();
    return result.toModel();
  }

  Future<void> cacheBusServiceRoutes(
      List<BusServiceRouteEntry> busServiceRouteEntries) async {
    await transaction(() async {
      for (var busServiceRouteEntry in busServiceRouteEntries) {
        await into(busRoutes)
            .insert(busServiceRouteEntry, mode: InsertMode.replace);
      }
    });
  }

  Future<List<BusServiceRoute>> getCachedBusServiceRoutes(
      BusService busService) async {
    assert(await areBusServiceRoutesCached());
    final result = await (select(busRoutes)
          ..where((b) => b.serviceNumber.equals(busService.number))
          ..orderBy([
            (busRoute) => OrderingTerm(expression: busRoute.distance),
          ]))
        .get();
    final routeBusStops = <int, List<({BusStop busStop, double distance})>>{};

    for (var entry in result) {
      final direction = entry.direction;
      final busStop = await getCachedBusStopWithCode(entry.busStopCode);
      final busStopWithDistance = (busStop: busStop, distance: entry.distance);

      routeBusStops.putIfAbsent(direction, () => []);
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
      {required BusStop busStop,
      required BusService busService,
      required int routeId}) async {
    await into(pinnedBusServices).insert(
      PinnedBusServiceEntry(
          routeId: routeId,
          busStopCode: busStop.code,
          busServiceNumber: busService.number),
    );
  }

  Future<void> unpinBusService(
      {required BusStop busStop,
      required BusService busService,
      required int routeId}) async {
    await (delete(pinnedBusServices)
          ..where((p) => p.routeId.equals(routeId))
          ..where((p) => p.busStopCode.equals(busStop.code))
          ..where((p) => p.busServiceNumber.equals(busService.number)))
        .go();
  }

  Future<List<BusService>> getPinnedServicesInRouteWithId(
      BusStop busStop, int routeId) async {
    final result = await (select(pinnedBusServices).join([
      innerJoin(busServices,
          pinnedBusServices.busServiceNumber.equalsExp(busServices.number)),
    ])
          ..where(pinnedBusServices.routeId.equals(routeId))
          ..where(pinnedBusServices.busStopCode.equals(busStop.code))
          ..orderBy([
            OrderingTerm(expression: pinnedBusServices.busServiceNumber),
          ]))
        .get();

    return result.map((e) => e.readTable(busServices).toModel()).toList();
  }

  Future<List<BusService>> getServicesIn(BusStop busStop) async {
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
  UserRoutesCompanion toInsertCompanion(int position) {
    return UserRoutesCompanion.insert(
      name: name,
      color: color.value,
      position: position,
    );
  }
}

extension on StoredUserRoute {
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
  StoredUserRoute toModel(List<BusStop> busStops) {
    return StoredUserRoute(
      id: id,
      name: name,
      color: Color(color),
      busStops: busStops,
    );
  }
}
