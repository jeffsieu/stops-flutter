// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// **************************************************************************
// MoorGenerator
// **************************************************************************

// ignore_for_file: unnecessary_brace_in_string_interps, unnecessary_this
class BusStopEntry extends DataClass implements Insertable<BusStopEntry> {
  final String code;
  final String displayName;
  final String defaultName;
  final String road;
  final double latitude;
  final double longitude;
  BusStopEntry(
      {required this.code,
      required this.displayName,
      required this.defaultName,
      required this.road,
      required this.latitude,
      required this.longitude});
  factory BusStopEntry.fromData(Map<String, dynamic> data, {String? prefix}) {
    final effectivePrefix = prefix ?? '';
    return BusStopEntry(
      code: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}code'])!,
      displayName: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}displayName'])!,
      defaultName: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}defaultName'])!,
      road: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}road'])!,
      latitude: const RealType()
          .mapFromDatabaseResponse(data['${effectivePrefix}latitude'])!,
      longitude: const RealType()
          .mapFromDatabaseResponse(data['${effectivePrefix}longitude'])!,
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['displayName'] = Variable<String>(displayName);
    map['defaultName'] = Variable<String>(defaultName);
    map['road'] = Variable<String>(road);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    return map;
  }

  BusStopsCompanion toCompanion(bool nullToAbsent) {
    return BusStopsCompanion(
      code: Value(code),
      displayName: Value(displayName),
      defaultName: Value(defaultName),
      road: Value(road),
      latitude: Value(latitude),
      longitude: Value(longitude),
    );
  }

  factory BusStopEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BusStopEntry(
      code: serializer.fromJson<String>(json['code']),
      displayName: serializer.fromJson<String>(json['displayName']),
      defaultName: serializer.fromJson<String>(json['defaultName']),
      road: serializer.fromJson<String>(json['road']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'displayName': serializer.toJson<String>(displayName),
      'defaultName': serializer.toJson<String>(defaultName),
      'road': serializer.toJson<String>(road),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
    };
  }

  BusStopEntry copyWith(
          {String? code,
          String? displayName,
          String? defaultName,
          String? road,
          double? latitude,
          double? longitude}) =>
      BusStopEntry(
        code: code ?? this.code,
        displayName: displayName ?? this.displayName,
        defaultName: defaultName ?? this.defaultName,
        road: road ?? this.road,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );
  @override
  String toString() {
    return (StringBuffer('BusStopEntry(')
          ..write('code: $code, ')
          ..write('displayName: $displayName, ')
          ..write('defaultName: $defaultName, ')
          ..write('road: $road, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(code, displayName, defaultName, road, latitude, longitude);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BusStopEntry &&
          other.code == this.code &&
          other.displayName == this.displayName &&
          other.defaultName == this.defaultName &&
          other.road == this.road &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude);
}

class BusStopsCompanion extends UpdateCompanion<BusStopEntry> {
  final Value<String> code;
  final Value<String> displayName;
  final Value<String> defaultName;
  final Value<String> road;
  final Value<double> latitude;
  final Value<double> longitude;
  const BusStopsCompanion({
    this.code = const Value.absent(),
    this.displayName = const Value.absent(),
    this.defaultName = const Value.absent(),
    this.road = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
  });
  BusStopsCompanion.insert({
    required String code,
    required String displayName,
    required String defaultName,
    required String road,
    required double latitude,
    required double longitude,
  })  : code = Value(code),
        displayName = Value(displayName),
        defaultName = Value(defaultName),
        road = Value(road),
        latitude = Value(latitude),
        longitude = Value(longitude);
  static Insertable<BusStopEntry> custom({
    Expression<String>? code,
    Expression<String>? displayName,
    Expression<String>? defaultName,
    Expression<String>? road,
    Expression<double>? latitude,
    Expression<double>? longitude,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (displayName != null) 'displayName': displayName,
      if (defaultName != null) 'defaultName': defaultName,
      if (road != null) 'road': road,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
  }

  BusStopsCompanion copyWith(
      {Value<String>? code,
      Value<String>? displayName,
      Value<String>? defaultName,
      Value<String>? road,
      Value<double>? latitude,
      Value<double>? longitude}) {
    return BusStopsCompanion(
      code: code ?? this.code,
      displayName: displayName ?? this.displayName,
      defaultName: defaultName ?? this.defaultName,
      road: road ?? this.road,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (displayName.present) {
      map['displayName'] = Variable<String>(displayName.value);
    }
    if (defaultName.present) {
      map['defaultName'] = Variable<String>(defaultName.value);
    }
    if (road.present) {
      map['road'] = Variable<String>(road.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BusStopsCompanion(')
          ..write('code: $code, ')
          ..write('displayName: $displayName, ')
          ..write('defaultName: $defaultName, ')
          ..write('road: $road, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude')
          ..write(')'))
        .toString();
  }
}

class $BusStopsTable extends BusStops
    with TableInfo<$BusStopsTable, BusStopEntry> {
  final GeneratedDatabase _db;
  final String? _alias;
  $BusStopsTable(this._db, [this._alias]);
  final VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String?> code = GeneratedColumn<String?>(
      'code', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 5, maxTextLength: 5),
      type: const StringType(),
      requiredDuringInsert: true);
  final VerificationMeta _displayNameMeta =
      const VerificationMeta('displayName');
  @override
  late final GeneratedColumn<String?> displayName = GeneratedColumn<String?>(
      'displayName', aliasedName, false,
      type: const StringType(), requiredDuringInsert: true);
  final VerificationMeta _defaultNameMeta =
      const VerificationMeta('defaultName');
  @override
  late final GeneratedColumn<String?> defaultName = GeneratedColumn<String?>(
      'defaultName', aliasedName, false,
      type: const StringType(), requiredDuringInsert: true);
  final VerificationMeta _roadMeta = const VerificationMeta('road');
  @override
  late final GeneratedColumn<String?> road = GeneratedColumn<String?>(
      'road', aliasedName, false,
      type: const StringType(), requiredDuringInsert: true);
  final VerificationMeta _latitudeMeta = const VerificationMeta('latitude');
  @override
  late final GeneratedColumn<double?> latitude = GeneratedColumn<double?>(
      'latitude', aliasedName, false,
      type: const RealType(), requiredDuringInsert: true);
  final VerificationMeta _longitudeMeta = const VerificationMeta('longitude');
  @override
  late final GeneratedColumn<double?> longitude = GeneratedColumn<double?>(
      'longitude', aliasedName, false,
      type: const RealType(), requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [code, displayName, defaultName, road, latitude, longitude];
  @override
  String get aliasedName => _alias ?? 'bus_stop';
  @override
  String get actualTableName => 'bus_stop';
  @override
  VerificationContext validateIntegrity(Insertable<BusStopEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('code')) {
      context.handle(
          _codeMeta, code.isAcceptableOrUnknown(data['code']!, _codeMeta));
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('displayName')) {
      context.handle(
          _displayNameMeta,
          displayName.isAcceptableOrUnknown(
              data['displayName']!, _displayNameMeta));
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('defaultName')) {
      context.handle(
          _defaultNameMeta,
          defaultName.isAcceptableOrUnknown(
              data['defaultName']!, _defaultNameMeta));
    } else if (isInserting) {
      context.missing(_defaultNameMeta);
    }
    if (data.containsKey('road')) {
      context.handle(
          _roadMeta, road.isAcceptableOrUnknown(data['road']!, _roadMeta));
    } else if (isInserting) {
      context.missing(_roadMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(_latitudeMeta,
          latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta));
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(_longitudeMeta,
          longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta));
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  BusStopEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    return BusStopEntry.fromData(data,
        prefix: tablePrefix != null ? '$tablePrefix.' : null);
  }

  @override
  $BusStopsTable createAlias(String alias) {
    return $BusStopsTable(_db, alias);
  }
}

class BusServiceEntry extends DataClass implements Insertable<BusServiceEntry> {
  final String number;
  final String operator;
  BusServiceEntry({required this.number, required this.operator});
  factory BusServiceEntry.fromData(Map<String, dynamic> data,
      {String? prefix}) {
    final effectivePrefix = prefix ?? '';
    return BusServiceEntry(
      number: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}number'])!,
      operator: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}operator'])!,
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['number'] = Variable<String>(number);
    map['operator'] = Variable<String>(operator);
    return map;
  }

  BusServicesCompanion toCompanion(bool nullToAbsent) {
    return BusServicesCompanion(
      number: Value(number),
      operator: Value(operator),
    );
  }

  factory BusServiceEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BusServiceEntry(
      number: serializer.fromJson<String>(json['number']),
      operator: serializer.fromJson<String>(json['operator']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'number': serializer.toJson<String>(number),
      'operator': serializer.toJson<String>(operator),
    };
  }

  BusServiceEntry copyWith({String? number, String? operator}) =>
      BusServiceEntry(
        number: number ?? this.number,
        operator: operator ?? this.operator,
      );
  @override
  String toString() {
    return (StringBuffer('BusServiceEntry(')
          ..write('number: $number, ')
          ..write('operator: $operator')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(number, operator);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BusServiceEntry &&
          other.number == this.number &&
          other.operator == this.operator);
}

class BusServicesCompanion extends UpdateCompanion<BusServiceEntry> {
  final Value<String> number;
  final Value<String> operator;
  const BusServicesCompanion({
    this.number = const Value.absent(),
    this.operator = const Value.absent(),
  });
  BusServicesCompanion.insert({
    required String number,
    required String operator,
  })  : number = Value(number),
        operator = Value(operator);
  static Insertable<BusServiceEntry> custom({
    Expression<String>? number,
    Expression<String>? operator,
  }) {
    return RawValuesInsertable({
      if (number != null) 'number': number,
      if (operator != null) 'operator': operator,
    });
  }

  BusServicesCompanion copyWith(
      {Value<String>? number, Value<String>? operator}) {
    return BusServicesCompanion(
      number: number ?? this.number,
      operator: operator ?? this.operator,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (number.present) {
      map['number'] = Variable<String>(number.value);
    }
    if (operator.present) {
      map['operator'] = Variable<String>(operator.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BusServicesCompanion(')
          ..write('number: $number, ')
          ..write('operator: $operator')
          ..write(')'))
        .toString();
  }
}

class $BusServicesTable extends BusServices
    with TableInfo<$BusServicesTable, BusServiceEntry> {
  final GeneratedDatabase _db;
  final String? _alias;
  $BusServicesTable(this._db, [this._alias]);
  final VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<String?> number = GeneratedColumn<String?>(
      'number', aliasedName, false,
      additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 4),
      type: const StringType(),
      requiredDuringInsert: true);
  final VerificationMeta _operatorMeta = const VerificationMeta('operator');
  @override
  late final GeneratedColumn<String?> operator = GeneratedColumn<String?>(
      'operator', aliasedName, false,
      type: const StringType(), requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [number, operator];
  @override
  String get aliasedName => _alias ?? 'bus_service';
  @override
  String get actualTableName => 'bus_service';
  @override
  VerificationContext validateIntegrity(Insertable<BusServiceEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('number')) {
      context.handle(_numberMeta,
          number.isAcceptableOrUnknown(data['number']!, _numberMeta));
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('operator')) {
      context.handle(_operatorMeta,
          operator.isAcceptableOrUnknown(data['operator']!, _operatorMeta));
    } else if (isInserting) {
      context.missing(_operatorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {number};
  @override
  BusServiceEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    return BusServiceEntry.fromData(data,
        prefix: tablePrefix != null ? '$tablePrefix.' : null);
  }

  @override
  $BusServicesTable createAlias(String alias) {
    return $BusServicesTable(_db, alias);
  }
}

class BusServiceRouteEntry extends DataClass
    implements Insertable<BusServiceRouteEntry> {
  final String serviceNumber;
  final int direction;
  final String busStopCode;
  final double distance;
  BusServiceRouteEntry(
      {required this.serviceNumber,
      required this.direction,
      required this.busStopCode,
      required this.distance});
  factory BusServiceRouteEntry.fromData(Map<String, dynamic> data,
      {String? prefix}) {
    final effectivePrefix = prefix ?? '';
    return BusServiceRouteEntry(
      serviceNumber: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}serviceNumber'])!,
      direction: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}direction'])!,
      busStopCode: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}busStopCode'])!,
      distance: const RealType()
          .mapFromDatabaseResponse(data['${effectivePrefix}distance'])!,
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['serviceNumber'] = Variable<String>(serviceNumber);
    map['direction'] = Variable<int>(direction);
    map['busStopCode'] = Variable<String>(busStopCode);
    map['distance'] = Variable<double>(distance);
    return map;
  }

  BusRoutesCompanion toCompanion(bool nullToAbsent) {
    return BusRoutesCompanion(
      serviceNumber: Value(serviceNumber),
      direction: Value(direction),
      busStopCode: Value(busStopCode),
      distance: Value(distance),
    );
  }

  factory BusServiceRouteEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BusServiceRouteEntry(
      serviceNumber: serializer.fromJson<String>(json['serviceNumber']),
      direction: serializer.fromJson<int>(json['direction']),
      busStopCode: serializer.fromJson<String>(json['busStopCode']),
      distance: serializer.fromJson<double>(json['distance']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serviceNumber': serializer.toJson<String>(serviceNumber),
      'direction': serializer.toJson<int>(direction),
      'busStopCode': serializer.toJson<String>(busStopCode),
      'distance': serializer.toJson<double>(distance),
    };
  }

  BusServiceRouteEntry copyWith(
          {String? serviceNumber,
          int? direction,
          String? busStopCode,
          double? distance}) =>
      BusServiceRouteEntry(
        serviceNumber: serviceNumber ?? this.serviceNumber,
        direction: direction ?? this.direction,
        busStopCode: busStopCode ?? this.busStopCode,
        distance: distance ?? this.distance,
      );
  @override
  String toString() {
    return (StringBuffer('BusServiceRouteEntry(')
          ..write('serviceNumber: $serviceNumber, ')
          ..write('direction: $direction, ')
          ..write('busStopCode: $busStopCode, ')
          ..write('distance: $distance')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(serviceNumber, direction, busStopCode, distance);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BusServiceRouteEntry &&
          other.serviceNumber == this.serviceNumber &&
          other.direction == this.direction &&
          other.busStopCode == this.busStopCode &&
          other.distance == this.distance);
}

class BusRoutesCompanion extends UpdateCompanion<BusServiceRouteEntry> {
  final Value<String> serviceNumber;
  final Value<int> direction;
  final Value<String> busStopCode;
  final Value<double> distance;
  const BusRoutesCompanion({
    this.serviceNumber = const Value.absent(),
    this.direction = const Value.absent(),
    this.busStopCode = const Value.absent(),
    this.distance = const Value.absent(),
  });
  BusRoutesCompanion.insert({
    required String serviceNumber,
    required int direction,
    required String busStopCode,
    required double distance,
  })  : serviceNumber = Value(serviceNumber),
        direction = Value(direction),
        busStopCode = Value(busStopCode),
        distance = Value(distance);
  static Insertable<BusServiceRouteEntry> custom({
    Expression<String>? serviceNumber,
    Expression<int>? direction,
    Expression<String>? busStopCode,
    Expression<double>? distance,
  }) {
    return RawValuesInsertable({
      if (serviceNumber != null) 'serviceNumber': serviceNumber,
      if (direction != null) 'direction': direction,
      if (busStopCode != null) 'busStopCode': busStopCode,
      if (distance != null) 'distance': distance,
    });
  }

  BusRoutesCompanion copyWith(
      {Value<String>? serviceNumber,
      Value<int>? direction,
      Value<String>? busStopCode,
      Value<double>? distance}) {
    return BusRoutesCompanion(
      serviceNumber: serviceNumber ?? this.serviceNumber,
      direction: direction ?? this.direction,
      busStopCode: busStopCode ?? this.busStopCode,
      distance: distance ?? this.distance,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serviceNumber.present) {
      map['serviceNumber'] = Variable<String>(serviceNumber.value);
    }
    if (direction.present) {
      map['direction'] = Variable<int>(direction.value);
    }
    if (busStopCode.present) {
      map['busStopCode'] = Variable<String>(busStopCode.value);
    }
    if (distance.present) {
      map['distance'] = Variable<double>(distance.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BusRoutesCompanion(')
          ..write('serviceNumber: $serviceNumber, ')
          ..write('direction: $direction, ')
          ..write('busStopCode: $busStopCode, ')
          ..write('distance: $distance')
          ..write(')'))
        .toString();
  }
}

class $BusRoutesTable extends BusRoutes
    with TableInfo<$BusRoutesTable, BusServiceRouteEntry> {
  final GeneratedDatabase _db;
  final String? _alias;
  $BusRoutesTable(this._db, [this._alias]);
  final VerificationMeta _serviceNumberMeta =
      const VerificationMeta('serviceNumber');
  @override
  late final GeneratedColumn<String?> serviceNumber = GeneratedColumn<String?>(
      'serviceNumber', aliasedName, false,
      additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 4),
      type: const StringType(),
      requiredDuringInsert: true,
      defaultConstraints: 'REFERENCES bus_service (number)');
  final VerificationMeta _directionMeta = const VerificationMeta('direction');
  @override
  late final GeneratedColumn<int?> direction = GeneratedColumn<int?>(
      'direction', aliasedName, false,
      type: const IntType(), requiredDuringInsert: true);
  final VerificationMeta _busStopCodeMeta =
      const VerificationMeta('busStopCode');
  @override
  late final GeneratedColumn<String?> busStopCode = GeneratedColumn<String?>(
      'busStopCode', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 5, maxTextLength: 5),
      type: const StringType(),
      requiredDuringInsert: true,
      defaultConstraints: 'REFERENCES bus_stop (code)');
  final VerificationMeta _distanceMeta = const VerificationMeta('distance');
  @override
  late final GeneratedColumn<double?> distance = GeneratedColumn<double?>(
      'distance', aliasedName, false,
      type: const RealType(), requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [serviceNumber, direction, busStopCode, distance];
  @override
  String get aliasedName => _alias ?? 'bus_route';
  @override
  String get actualTableName => 'bus_route';
  @override
  VerificationContext validateIntegrity(
      Insertable<BusServiceRouteEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('serviceNumber')) {
      context.handle(
          _serviceNumberMeta,
          serviceNumber.isAcceptableOrUnknown(
              data['serviceNumber']!, _serviceNumberMeta));
    } else if (isInserting) {
      context.missing(_serviceNumberMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(_directionMeta,
          direction.isAcceptableOrUnknown(data['direction']!, _directionMeta));
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('busStopCode')) {
      context.handle(
          _busStopCodeMeta,
          busStopCode.isAcceptableOrUnknown(
              data['busStopCode']!, _busStopCodeMeta));
    } else if (isInserting) {
      context.missing(_busStopCodeMeta);
    }
    if (data.containsKey('distance')) {
      context.handle(_distanceMeta,
          distance.isAcceptableOrUnknown(data['distance']!, _distanceMeta));
    } else if (isInserting) {
      context.missing(_distanceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey =>
      {serviceNumber, direction, busStopCode};
  @override
  BusServiceRouteEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    return BusServiceRouteEntry.fromData(data,
        prefix: tablePrefix != null ? '$tablePrefix.' : null);
  }

  @override
  $BusRoutesTable createAlias(String alias) {
    return $BusRoutesTable(_db, alias);
  }
}

class UserRouteEntry extends DataClass implements Insertable<UserRouteEntry> {
  final int id;
  final String name;
  final int color;
  final int position;
  UserRouteEntry(
      {required this.id,
      required this.name,
      required this.color,
      required this.position});
  factory UserRouteEntry.fromData(Map<String, dynamic> data, {String? prefix}) {
    final effectivePrefix = prefix ?? '';
    return UserRouteEntry(
      id: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}id'])!,
      name: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}name'])!,
      color: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}color'])!,
      position: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}position'])!,
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<int>(color);
    map['position'] = Variable<int>(position);
    return map;
  }

  UserRoutesCompanion toCompanion(bool nullToAbsent) {
    return UserRoutesCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      position: Value(position),
    );
  }

  factory UserRouteEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserRouteEntry(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int>(json['color']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int>(color),
      'position': serializer.toJson<int>(position),
    };
  }

  UserRouteEntry copyWith({int? id, String? name, int? color, int? position}) =>
      UserRouteEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
        position: position ?? this.position,
      );
  @override
  String toString() {
    return (StringBuffer('UserRouteEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserRouteEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.position == this.position);
}

class UserRoutesCompanion extends UpdateCompanion<UserRouteEntry> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> color;
  final Value<int> position;
  const UserRoutesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.position = const Value.absent(),
  });
  UserRoutesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int color,
    required int position,
  })  : name = Value(name),
        color = Value(color),
        position = Value(position);
  static Insertable<UserRouteEntry> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? color,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (position != null) 'position': position,
    });
  }

  UserRoutesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<int>? color,
      Value<int>? position}) {
    return UserRoutesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserRoutesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

class $UserRoutesTable extends UserRoutes
    with TableInfo<$UserRoutesTable, UserRouteEntry> {
  final GeneratedDatabase _db;
  final String? _alias;
  $UserRoutesTable(this._db, [this._alias]);
  final VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int?> id = GeneratedColumn<int?>(
      'id', aliasedName, false,
      type: const IntType(),
      requiredDuringInsert: false,
      defaultConstraints: 'PRIMARY KEY AUTOINCREMENT');
  final VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String?> name = GeneratedColumn<String?>(
      'name', aliasedName, false,
      type: const StringType(), requiredDuringInsert: true);
  final VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int?> color = GeneratedColumn<int?>(
      'color', aliasedName, false,
      type: const IntType(), requiredDuringInsert: true);
  final VerificationMeta _positionMeta = const VerificationMeta('position');
  @override
  late final GeneratedColumn<int?> position = GeneratedColumn<int?>(
      'position', aliasedName, false,
      type: const IntType(), requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name, color, position];
  @override
  String get aliasedName => _alias ?? 'user_route';
  @override
  String get actualTableName => 'user_route';
  @override
  VerificationContext validateIntegrity(Insertable<UserRouteEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserRouteEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    return UserRouteEntry.fromData(data,
        prefix: tablePrefix != null ? '$tablePrefix.' : null);
  }

  @override
  $UserRoutesTable createAlias(String alias) {
    return $UserRoutesTable(_db, alias);
  }
}

class UserRouteBusStopEntry extends DataClass
    implements Insertable<UserRouteBusStopEntry> {
  final int routeId;
  final String busStopCode;
  final int position;
  UserRouteBusStopEntry(
      {required this.routeId,
      required this.busStopCode,
      required this.position});
  factory UserRouteBusStopEntry.fromData(Map<String, dynamic> data,
      {String? prefix}) {
    final effectivePrefix = prefix ?? '';
    return UserRouteBusStopEntry(
      routeId: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}routeId'])!,
      busStopCode: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}busStopCode'])!,
      position: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}position'])!,
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['routeId'] = Variable<int>(routeId);
    map['busStopCode'] = Variable<String>(busStopCode);
    map['position'] = Variable<int>(position);
    return map;
  }

  UserRouteBusStopsCompanion toCompanion(bool nullToAbsent) {
    return UserRouteBusStopsCompanion(
      routeId: Value(routeId),
      busStopCode: Value(busStopCode),
      position: Value(position),
    );
  }

  factory UserRouteBusStopEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserRouteBusStopEntry(
      routeId: serializer.fromJson<int>(json['routeId']),
      busStopCode: serializer.fromJson<String>(json['busStopCode']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'routeId': serializer.toJson<int>(routeId),
      'busStopCode': serializer.toJson<String>(busStopCode),
      'position': serializer.toJson<int>(position),
    };
  }

  UserRouteBusStopEntry copyWith(
          {int? routeId, String? busStopCode, int? position}) =>
      UserRouteBusStopEntry(
        routeId: routeId ?? this.routeId,
        busStopCode: busStopCode ?? this.busStopCode,
        position: position ?? this.position,
      );
  @override
  String toString() {
    return (StringBuffer('UserRouteBusStopEntry(')
          ..write('routeId: $routeId, ')
          ..write('busStopCode: $busStopCode, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(routeId, busStopCode, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserRouteBusStopEntry &&
          other.routeId == this.routeId &&
          other.busStopCode == this.busStopCode &&
          other.position == this.position);
}

class UserRouteBusStopsCompanion
    extends UpdateCompanion<UserRouteBusStopEntry> {
  final Value<int> routeId;
  final Value<String> busStopCode;
  final Value<int> position;
  const UserRouteBusStopsCompanion({
    this.routeId = const Value.absent(),
    this.busStopCode = const Value.absent(),
    this.position = const Value.absent(),
  });
  UserRouteBusStopsCompanion.insert({
    required int routeId,
    required String busStopCode,
    required int position,
  })  : routeId = Value(routeId),
        busStopCode = Value(busStopCode),
        position = Value(position);
  static Insertable<UserRouteBusStopEntry> custom({
    Expression<int>? routeId,
    Expression<String>? busStopCode,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (routeId != null) 'routeId': routeId,
      if (busStopCode != null) 'busStopCode': busStopCode,
      if (position != null) 'position': position,
    });
  }

  UserRouteBusStopsCompanion copyWith(
      {Value<int>? routeId, Value<String>? busStopCode, Value<int>? position}) {
    return UserRouteBusStopsCompanion(
      routeId: routeId ?? this.routeId,
      busStopCode: busStopCode ?? this.busStopCode,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (routeId.present) {
      map['routeId'] = Variable<int>(routeId.value);
    }
    if (busStopCode.present) {
      map['busStopCode'] = Variable<String>(busStopCode.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserRouteBusStopsCompanion(')
          ..write('routeId: $routeId, ')
          ..write('busStopCode: $busStopCode, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

class $UserRouteBusStopsTable extends UserRouteBusStops
    with TableInfo<$UserRouteBusStopsTable, UserRouteBusStopEntry> {
  final GeneratedDatabase _db;
  final String? _alias;
  $UserRouteBusStopsTable(this._db, [this._alias]);
  final VerificationMeta _routeIdMeta = const VerificationMeta('routeId');
  @override
  late final GeneratedColumn<int?> routeId = GeneratedColumn<int?>(
      'routeId', aliasedName, false,
      type: const IntType(),
      requiredDuringInsert: true,
      defaultConstraints: 'REFERENCES user_route (id)');
  final VerificationMeta _busStopCodeMeta =
      const VerificationMeta('busStopCode');
  @override
  late final GeneratedColumn<String?> busStopCode = GeneratedColumn<String?>(
      'busStopCode', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 5, maxTextLength: 5),
      type: const StringType(),
      requiredDuringInsert: true,
      defaultConstraints: 'REFERENCES bus_stop (code)');
  final VerificationMeta _positionMeta = const VerificationMeta('position');
  @override
  late final GeneratedColumn<int?> position = GeneratedColumn<int?>(
      'position', aliasedName, false,
      type: const IntType(), requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [routeId, busStopCode, position];
  @override
  String get aliasedName => _alias ?? 'user_route_bus_stop';
  @override
  String get actualTableName => 'user_route_bus_stop';
  @override
  VerificationContext validateIntegrity(
      Insertable<UserRouteBusStopEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('routeId')) {
      context.handle(_routeIdMeta,
          routeId.isAcceptableOrUnknown(data['routeId']!, _routeIdMeta));
    } else if (isInserting) {
      context.missing(_routeIdMeta);
    }
    if (data.containsKey('busStopCode')) {
      context.handle(
          _busStopCodeMeta,
          busStopCode.isAcceptableOrUnknown(
              data['busStopCode']!, _busStopCodeMeta));
    } else if (isInserting) {
      context.missing(_busStopCodeMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {routeId, busStopCode};
  @override
  UserRouteBusStopEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    return UserRouteBusStopEntry.fromData(data,
        prefix: tablePrefix != null ? '$tablePrefix.' : null);
  }

  @override
  $UserRouteBusStopsTable createAlias(String alias) {
    return $UserRouteBusStopsTable(_db, alias);
  }
}

class PinnedBusServiceEntry extends DataClass
    implements Insertable<PinnedBusServiceEntry> {
  final int routeId;
  final String busStopCode;
  final String busServiceNumber;
  PinnedBusServiceEntry(
      {required this.routeId,
      required this.busStopCode,
      required this.busServiceNumber});
  factory PinnedBusServiceEntry.fromData(Map<String, dynamic> data,
      {String? prefix}) {
    final effectivePrefix = prefix ?? '';
    return PinnedBusServiceEntry(
      routeId: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}routeId'])!,
      busStopCode: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}busStopCode'])!,
      busServiceNumber: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}busServiceNumber'])!,
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['routeId'] = Variable<int>(routeId);
    map['busStopCode'] = Variable<String>(busStopCode);
    map['busServiceNumber'] = Variable<String>(busServiceNumber);
    return map;
  }

  PinnedBusServicesCompanion toCompanion(bool nullToAbsent) {
    return PinnedBusServicesCompanion(
      routeId: Value(routeId),
      busStopCode: Value(busStopCode),
      busServiceNumber: Value(busServiceNumber),
    );
  }

  factory PinnedBusServiceEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PinnedBusServiceEntry(
      routeId: serializer.fromJson<int>(json['routeId']),
      busStopCode: serializer.fromJson<String>(json['busStopCode']),
      busServiceNumber: serializer.fromJson<String>(json['busServiceNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'routeId': serializer.toJson<int>(routeId),
      'busStopCode': serializer.toJson<String>(busStopCode),
      'busServiceNumber': serializer.toJson<String>(busServiceNumber),
    };
  }

  PinnedBusServiceEntry copyWith(
          {int? routeId, String? busStopCode, String? busServiceNumber}) =>
      PinnedBusServiceEntry(
        routeId: routeId ?? this.routeId,
        busStopCode: busStopCode ?? this.busStopCode,
        busServiceNumber: busServiceNumber ?? this.busServiceNumber,
      );
  @override
  String toString() {
    return (StringBuffer('PinnedBusServiceEntry(')
          ..write('routeId: $routeId, ')
          ..write('busStopCode: $busStopCode, ')
          ..write('busServiceNumber: $busServiceNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(routeId, busStopCode, busServiceNumber);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PinnedBusServiceEntry &&
          other.routeId == this.routeId &&
          other.busStopCode == this.busStopCode &&
          other.busServiceNumber == this.busServiceNumber);
}

class PinnedBusServicesCompanion
    extends UpdateCompanion<PinnedBusServiceEntry> {
  final Value<int> routeId;
  final Value<String> busStopCode;
  final Value<String> busServiceNumber;
  const PinnedBusServicesCompanion({
    this.routeId = const Value.absent(),
    this.busStopCode = const Value.absent(),
    this.busServiceNumber = const Value.absent(),
  });
  PinnedBusServicesCompanion.insert({
    required int routeId,
    required String busStopCode,
    required String busServiceNumber,
  })  : routeId = Value(routeId),
        busStopCode = Value(busStopCode),
        busServiceNumber = Value(busServiceNumber);
  static Insertable<PinnedBusServiceEntry> custom({
    Expression<int>? routeId,
    Expression<String>? busStopCode,
    Expression<String>? busServiceNumber,
  }) {
    return RawValuesInsertable({
      if (routeId != null) 'routeId': routeId,
      if (busStopCode != null) 'busStopCode': busStopCode,
      if (busServiceNumber != null) 'busServiceNumber': busServiceNumber,
    });
  }

  PinnedBusServicesCompanion copyWith(
      {Value<int>? routeId,
      Value<String>? busStopCode,
      Value<String>? busServiceNumber}) {
    return PinnedBusServicesCompanion(
      routeId: routeId ?? this.routeId,
      busStopCode: busStopCode ?? this.busStopCode,
      busServiceNumber: busServiceNumber ?? this.busServiceNumber,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (routeId.present) {
      map['routeId'] = Variable<int>(routeId.value);
    }
    if (busStopCode.present) {
      map['busStopCode'] = Variable<String>(busStopCode.value);
    }
    if (busServiceNumber.present) {
      map['busServiceNumber'] = Variable<String>(busServiceNumber.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PinnedBusServicesCompanion(')
          ..write('routeId: $routeId, ')
          ..write('busStopCode: $busStopCode, ')
          ..write('busServiceNumber: $busServiceNumber')
          ..write(')'))
        .toString();
  }
}

class $PinnedBusServicesTable extends PinnedBusServices
    with TableInfo<$PinnedBusServicesTable, PinnedBusServiceEntry> {
  final GeneratedDatabase _db;
  final String? _alias;
  $PinnedBusServicesTable(this._db, [this._alias]);
  final VerificationMeta _routeIdMeta = const VerificationMeta('routeId');
  @override
  late final GeneratedColumn<int?> routeId = GeneratedColumn<int?>(
      'routeId', aliasedName, false,
      type: const IntType(),
      requiredDuringInsert: true,
      defaultConstraints: 'REFERENCES user_route_bus_stop (routeId)');
  final VerificationMeta _busStopCodeMeta =
      const VerificationMeta('busStopCode');
  @override
  late final GeneratedColumn<String?> busStopCode = GeneratedColumn<String?>(
      'busStopCode', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 5, maxTextLength: 5),
      type: const StringType(),
      requiredDuringInsert: true,
      defaultConstraints: 'REFERENCES user_route_bus_stop (busStopCode)');
  final VerificationMeta _busServiceNumberMeta =
      const VerificationMeta('busServiceNumber');
  @override
  late final GeneratedColumn<String?> busServiceNumber =
      GeneratedColumn<String?>('busServiceNumber', aliasedName, false,
          additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 4),
          type: const StringType(),
          requiredDuringInsert: true,
          defaultConstraints: 'REFERENCES bus_service (number)');
  @override
  List<GeneratedColumn> get $columns =>
      [routeId, busStopCode, busServiceNumber];
  @override
  String get aliasedName => _alias ?? 'pinned_bus_service';
  @override
  String get actualTableName => 'pinned_bus_service';
  @override
  VerificationContext validateIntegrity(
      Insertable<PinnedBusServiceEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('routeId')) {
      context.handle(_routeIdMeta,
          routeId.isAcceptableOrUnknown(data['routeId']!, _routeIdMeta));
    } else if (isInserting) {
      context.missing(_routeIdMeta);
    }
    if (data.containsKey('busStopCode')) {
      context.handle(
          _busStopCodeMeta,
          busStopCode.isAcceptableOrUnknown(
              data['busStopCode']!, _busStopCodeMeta));
    } else if (isInserting) {
      context.missing(_busStopCodeMeta);
    }
    if (data.containsKey('busServiceNumber')) {
      context.handle(
          _busServiceNumberMeta,
          busServiceNumber.isAcceptableOrUnknown(
              data['busServiceNumber']!, _busServiceNumberMeta));
    } else if (isInserting) {
      context.missing(_busServiceNumberMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => <GeneratedColumn>{};
  @override
  PinnedBusServiceEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    return PinnedBusServiceEntry.fromData(data,
        prefix: tablePrefix != null ? '$tablePrefix.' : null);
  }

  @override
  $PinnedBusServicesTable createAlias(String alias) {
    return $PinnedBusServicesTable(_db, alias);
  }
}

abstract class _$StopsDatabase extends GeneratedDatabase {
  _$StopsDatabase(QueryExecutor e) : super(SqlTypeSystem.defaultInstance, e);
  late final $BusStopsTable busStops = $BusStopsTable(this);
  late final $BusServicesTable busServices = $BusServicesTable(this);
  late final $BusRoutesTable busRoutes = $BusRoutesTable(this);
  late final $UserRoutesTable userRoutes = $UserRoutesTable(this);
  late final $UserRouteBusStopsTable userRouteBusStops =
      $UserRouteBusStopsTable(this);
  late final $PinnedBusServicesTable pinnedBusServices =
      $PinnedBusServicesTable(this);
  @override
  Iterable<TableInfo> get allTables => allSchemaEntities.whereType<TableInfo>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        busStops,
        busServices,
        busRoutes,
        userRoutes,
        userRouteBusStops,
        pinnedBusServices
      ];
}
