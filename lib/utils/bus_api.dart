import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/bus_service.dart';
import '../models/bus_service_route.dart';
import '../models/bus_stop.dart';
import '../utils/bus_service_arrival_result.dart';
import '../utils/database_utils.dart';

part 'bus_api.g.dart';

const String _kApiTag = 'AccountKey';
String? _kApiKey;

const String _kRootUrl = 'http://datamall2.mytransport.sg/ltaodataservice/';
const String _kGetBusStopsUrl = 'BusStops';
const String _kGetBusStopArrivalUrl = 'BusArrivalv2';
const String _kGetBusServicesUrl = 'BusServices';
const String _kGetBusRoutesUrl = 'BusRoutes';

const String kBusStopCodeKey = 'BusStopCode';
const String kBusStopNameKey = 'Description';
const String kBusStopRoadKey = 'RoadName';
const String kBusStopLatitudeKey = 'Latitude';
const String kBusStopLongitudeKey = 'Longitude';
const String kBusStopDistanceKey = 'Distance';

const String kBusServiceNumberKey = 'ServiceNo';
const String kBusServiceOperatorKey = 'Operator';
const String kBusServiceDirectionKey = 'Direction';
const String kBusServiceLatitudeKey = 'Latitude';
const String kBusServiceLongitudeKey = 'Longitude';
const String kBusServiceOriginKey = 'OriginCode';
const String kBusServiceDestinationKey = 'DestinationCode';
const String kBusServiceTypeKey = 'Type';
const String kBusServiceTypeSingle = 'SD';
const String kBusServiceTypeDouble = 'DD';
const String kBusServiceTypeBendy = 'BD';
const String kBusServiceLoadKey = 'Load';
const String kBusServiceLoadLow = 'SEA';
const String kBusServiceLoadMedium = 'SDA';
const String kBusServiceLoadHigh = 'LSD';
const String kBusServiceArrivalTimeKey = 'EstimatedArrival';

const String kBusServiceRouteStopSequenceKey = 'StopSequence';

// TODO: Actually refresh data
const int _kRefreshInterval = 30;

enum BusApiError {
  noBusesInService(message: 'No buses in service'),
  noPinnedBusesInService(message: 'No pinned buses in service'),
  noPinnedBuses(message: 'Pin a service'),
  noInternet(message: 'No internet connection'),
  cannotReachServer(message: 'Unable to reach data server'),
  loading(message: 'Loading buses...');

  const BusApiError({required this.message});

  final String message;
}

@riverpod
Future<String> apiKey(ApiKeyRef ref) async {
  final jsonString = await rootBundle.loadString('assets/secrets.json');
  return json.decode(jsonString)['lta_api_key'] as String;
}

@riverpod
class BusStopList extends _$BusStopList {
  @override
  Future<List<BusStop>> build() async {
    return await getCachedBusStops();
  }

  Future<void> fetchFromApi() async {
    final busStopList = await ref.read(_apiBusStopListProvider.future);
    await cacheBusStops(busStopList);
    ref.invalidateSelf();
  }
}

@riverpod
class BusServiceList extends _$BusServiceList {
  @override
  Future<List<BusService>> build() async {
    return await getCachedBusServices();
  }

  Future<void> fetchFromApi() async {
    final busServiceList = await ref.read(_apiBusServiceListProvider.future);
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
        await ref.read(_apiBusServiceRouteListProvider.future);
    await cacheBusServiceRoutes(busServiceRouteList);
    ref.invalidateSelf();
  }
}

Future<bool> hasInternetConnection() async {
  try {
    final result = await InternetAddress.lookup('example.com');
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  }
}

@riverpod
Future<String> busApiStringResponse(BusApiStringResponseRef ref,
    {required String url, required int skip, String? extraParams = ''}) async {
  final apiKey = await ref.watch(apiKeyProvider.future);
  try {
    final response = await http.get(
        Uri.parse('$_kRootUrl$url?\$skip=$skip$extraParams'),
        headers: <String, String>{
          _kApiTag: apiKey,
          'Content-Type': 'application/json',
        });
    return response.body;
  } on SocketException {
    // Try to connect to example.com
    final hasInternet = await hasInternetConnection();
    if (!hasInternet) {
      return Future<String>.error(BusApiError.noInternet, StackTrace.current);
    } else {
      return Future<String>.error(
          BusApiError.cannotReachServer, StackTrace.current);
    }
  }
}

@riverpod
Future<List<T>> _busApiListResponse<T>(_BusApiListResponseRef ref, String url,
    T Function(dynamic json) function) async {
  var skip = 0;
  const concurrentCount = 6;
  final resultList = <T>[];
  var isAtListEnd = false;
  while (!isAtListEnd) {
    final futures = <Future<String>>[];
    for (var i = 0; i < concurrentCount; i++) {
      futures.add(await ref
          .read(busApiStringResponseProvider(url: url, skip: skip).future));
      skip += 500;
    }
    final results = await Future.wait(futures);
    for (var result in results) {
      try {
        final rawList = jsonDecode(result)['value'] as List<dynamic>?;
        if (rawList == null || rawList.isEmpty) break;
        resultList.addAll(rawList.map<T>(function));
        if (rawList.length < 500) {
          isAtListEnd = true;
          break;
        }
      } on FormatException {
        continue;
      }
    }
  }
  return resultList;
}

const String kBusStopServicesKey = 'Services';

@riverpod
Future<String> _busStopArrivalList(
    _BusStopArrivalListRef ref, String busStopCode) async {
  return await ref.watch(busApiStringResponseProvider(
          url: _kGetBusStopArrivalUrl,
          skip: 0,
          extraParams: '&BusStopCode=$busStopCode')
      .future);
}

@riverpod
Future<List<BusServiceArrivalResult>> busStopArrivals(
    BusStopArrivalsRef ref, BusStop busStop) async {
  final result =
      await ref.watch(_busStopArrivalListProvider(busStop.code).future);
  final services = jsonDecode(result)[kBusStopServicesKey] as List<dynamic>;
  return services.map(BusServiceArrivalResult.fromJson).toList(growable: true);
}

@riverpod
Future<List<BusStop>> _apiBusStopList(_ApiBusStopListRef ref) async {
  return await ref.watch(
      _busApiListResponseProvider(_kGetBusStopsUrl, BusStop.fromJson).future);
}

@riverpod
Future<List<BusService>> _apiBusServiceList(_ApiBusServiceListRef ref) async {
  return await ref.watch(
      _busApiListResponseProvider(_kGetBusServicesUrl, BusService.fromJson)
          .future);
}

@riverpod
Future<List<Map<String, dynamic>>> _apiBusServiceRouteList(
    _ApiBusServiceRouteListRef ref) async {
  return await ref.watch(
      _busApiListResponseProvider(_kGetBusRoutesUrl, busServiceRouteStopToJson)
          .future);
}

@riverpod
Future<DateTime?> firstArrivalTime(FirstArrivalTimeRef ref,
    {required BusStop busStop, required String busServiceNumber}) async {
  final arrivalResults =
      await ref.watch(busStopArrivalsProvider(busStop).future);
  for (var arrivalResult in arrivalResults) {
    if (arrivalResult.busService.number == busServiceNumber) {
      return arrivalResult.buses.firstOrNull?.arrivalTime;
    }
  }
  return null;
}

class BusAPIException implements Exception {
  final String message;

  BusAPIException(this.message);

  @override
  String toString() => message;
}
