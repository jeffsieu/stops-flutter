import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stops_sg/bus_api/models/bus_service.dart';
import 'package:stops_sg/bus_api/models/bus_service_arrival_result.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/database/database.dart';

part 'bus_api.g.dart';

const String _kApiTag = 'AccountKey';

const String _kRootUrl = 'https://datamall2.mytransport.sg/ltaodataservice/';
const String _kGetBusStopsUrl = 'BusStops';
const String _kGetBusStopArrivalUrl = 'v3/BusArrival';
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
const String kBusServiceFeatureKey = 'Feature';
const String kBusServiceFeatureWheelchairAccessible = 'WAB';
const String kBusServiceArrivalTimeKey = 'EstimatedArrival';

const String kBusServiceRouteStopSequenceKey = 'StopSequence';

const int _kRefreshInterval = 30;

enum BusApiError {
  noBusesInService(message: 'No buses in service'),
  noPinnedBusesInService(message: 'No pinned buses in service'),
  noInternet(message: 'No internet connection'),
  cannotReachServer(message: 'Unable to reach data server');

  const BusApiError({required this.message});

  final String message;
}

@riverpod
Future<String> apiKey(ApiKeyRef ref) async {
  final jsonString = await rootBundle.loadString('assets/secrets.json');
  return json.decode(jsonString)['lta_api_key'] as String;
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
Future<List<T>> _busApiListResponse<T>(_BusApiListResponseRef<T> ref,
    String url, T Function(dynamic json) function) async {
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
  final arrivals =
      services.map(BusServiceArrivalResult.fromJson).toList(growable: true);

  ref.cacheFor(const Duration(seconds: _kRefreshInterval));
  ref.refreshIn(const Duration(seconds: _kRefreshInterval));

  return arrivals;
}

extension RefreshRef<T> on Ref<T> {
  void refreshIn(Duration duration) {
    Timer.periodic(duration, (timer) {
      invalidateSelf();
    });
  }
}

extension CacheForExtension<T> on AutoDisposeRef<T> {
  /// Keeps the provider alive for [duration].
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);

    onDispose(timer.cancel);
  }
}

@riverpod
Future<List<BusStop>> apiBusStopList(ApiBusStopListRef ref) async {
  return await ref.watch(
      _busApiListResponseProvider(_kGetBusStopsUrl, BusStop.fromJson).future);
}

@riverpod
Future<List<BusService>> apiBusServiceList(ApiBusServiceListRef ref) async {
  return await ref.watch(
      _busApiListResponseProvider(_kGetBusServicesUrl, BusService.fromJson)
          .future);
}

@riverpod
Future<List<Map<String, dynamic>>> apiBusServiceRouteList(
    ApiBusServiceRouteListRef ref) async {
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
