import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/bus_service.dart';
import '../models/bus_stop.dart';
import '../utils/bus_service_arrival_result.dart';
import '../utils/database_utils.dart';

class BusAPI {
  factory BusAPI() {
    _singleton._loadAPIKey();
    return _singleton;
  }

  BusAPI._internal();

  static const String _kApiTag = 'AccountKey';
  late final String _kApiKey;

  static const String _kRootUrl =
      'http://datamall2.mytransport.sg/ltaodataservice/';
  static const String _kGetBusStopsUrl = 'BusStops';
  static const String _kGetBusStopArrivalUrl = 'BusArrivalv2';
  static const String _kGetBusServicesUrl = 'BusServices';
  static const String _kGetBusRoutesUrl = 'BusRoutes';

  static const String kBusStopCodeKey = 'BusStopCode';
  static const String kBusStopNameKey = 'Description';
  static const String kBusStopRoadKey = 'RoadName';
  static const String kBusStopLatitudeKey = 'Latitude';
  static const String kBusStopLongitudeKey = 'Longitude';
  static const String kBusStopDistanceKey = 'Distance';
  static const String kBusStopServicesKey = 'Services';

  static const String kBusServiceNumberKey = 'ServiceNo';
  static const String kBusServiceOperatorKey = 'Operator';
  static const String kBusServiceDirectionKey = 'Direction';
  static const String kBusServiceLatitudeKey = 'Latitude';
  static const String kBusServiceLongitudeKey = 'Longitude';
  static const String kBusServiceOriginKey = 'OriginCode';
  static const String kBusServiceDestinationKey = 'DestinationCode';
  static const String kBusServiceTypeKey = 'Type';
  static const String kBusServiceTypeSingle = 'SD';
  static const String kBusServiceTypeDouble = 'DD';
  static const String kBusServiceTypeBendy = 'BD';
  static const String kBusServiceLoadKey = 'Load';
  static const String kBusServiceLoadLow = 'SEA';
  static const String kBusServiceLoadMedium = 'SDA';
  static const String kBusServiceLoadHigh = 'LSD';
  static const String kBusServiceArrivalTimeKey = 'EstimatedArrival';

  static const String kBusServiceRouteStopSequenceKey = 'StopSequence';

  static const int _kRefreshInterval = 30;

  static const String kNoBusesError = 'No buses in service';
  static const String kNoPinnedBusesError = 'No pinned buses in service';
  static const String kNoInternetError = 'No internet connection';
  static const String kLoadingMessage = 'Loading buses...';

  static final BusAPI _singleton = BusAPI._internal();

  final List<BusService> _busServices = <BusService>[];
  final List<BusStop> _busStops = <BusStop>[];
  final Map<BusStop, StreamController<List<BusServiceArrivalResult>>>
      _arrivalControllers =
      <BusStop, StreamController<List<BusServiceArrivalResult>>>{};
  final Map<BusStop, List<BusServiceArrivalResult>> _arrivalCache =
      <BusStop, List<BusServiceArrivalResult>>{};

  bool _areBusStopsLoaded = false;
  bool _areBusServicesLoaded = false;

  /*
   * Load LTA API key from secrets.json file in root directory
   * and store in memory
   */
  Future<void> _loadAPIKey() async {
    final String jsonString =
        await rootBundle.loadString('assets/secrets.json');
    _kApiKey = json.decode(jsonString)['lta_api_key'] as String;
  }

  late final StreamController<List<BusStop>> busStopStreamController =
      StreamController<List<BusStop>>(onListen: () async {
    if (!_areBusStopsLoaded) {
      _busStops.addAll(await getCachedBusStops());
      _areBusStopsLoaded = true;
    }
    busStopStreamController.add(_busStops);
  });

  late final StreamController<List<BusService>> busServiceStreamController =
      StreamController<List<BusService>>(onListen: () async {
    if (!_areBusServicesLoaded) {
      _busServices.addAll(await getCachedBusServices());
      _areBusServicesLoaded = true;
    }
    busServiceStreamController.add(_busServices);
  });

  /*
   * A stream that returns a list of bus stops.
   *
   * Every time the stream will return 500 more
   * bus stops until the whole list is loaded,
   * after which any subsequent listens to the
   * stream will return the full list of stops.
   */
  Stream<List<BusStop>> busStopsStream() => busStopStreamController.stream;

  Stream<List<BusService>> busServicesStream() =>
      busServiceStreamController.stream;

  List<BusServiceArrivalResult>? getLatestArrival(BusStop busStop) {
    return _arrivalCache[busStop];
  }

  Future<DateTime?> getArrivalTime(
      BusStop busStop, String busServiceNumber) async {
    List<BusServiceArrivalResult> arrivalResults =
        getLatestArrival(busStop) ?? await busStopArrivalStream(busStop).first;
    for (BusServiceArrivalResult arrivalResult in arrivalResults) {
      if (arrivalResult.busService.number == busServiceNumber) {
        return arrivalResult.buses[0].arrivalTime;
      }
    }
    return null;
  }

  Stream<List<BusServiceArrivalResult>> busStopArrivalStream(BusStop busStop) {
    void updateArrivalStream() {
      _fetchBusStopArrivalList(busStop.code).then((String result) {
        final List<dynamic> services =
            jsonDecode(result)[kBusStopServicesKey] as List<dynamic>;
        final List<BusServiceArrivalResult> arrivalResults = services
            .map(BusServiceArrivalResult.fromJson)
            .toList(growable: true);
        _arrivalCache[busStop] = arrivalResults;
        _arrivalControllers[busStop]!.add(arrivalResults);
      });
    }

    if (_arrivalControllers.containsKey(busStop)) {
      updateArrivalStream();
      return _arrivalControllers[busStop]!.stream;
    } else {
      Timer? timer;
      StreamController<List<BusServiceArrivalResult>> controller;

      void fetchBusStops(Timer? timer) {
        updateArrivalStream();
      }

      void startTimer() {
        fetchBusStops(null);
        timer = Timer.periodic(
            const Duration(seconds: _kRefreshInterval), fetchBusStops);
      }

      void onCancel() {
        timer?.cancel();
        timer = null;
      }

      controller = StreamController<List<BusServiceArrivalResult>>.broadcast(
        onListen: startTimer,
        onCancel: onCancel,
      );

      _arrivalControllers.putIfAbsent(busStop, () => controller);

      updateArrivalStream();
      return controller.stream;
    }
  }

  Future<String> _fetchAsString(String url, int skip,
      [String extraParams = '']) async {
    final HttpClientRequest request = await HttpClient()
        .getUrl(Uri.parse('$_kRootUrl$url?\$skip=$skip$extraParams'));
    request.headers.set(_kApiTag, _kApiKey);
    request.headers.set('Content-Type', 'application/json');

    final HttpClientResponse response = await request.close();
    final Future<String> content = utf8.decodeStream(response);
    return content;
  }

  Future<List<T>> _fetchAsList<T>(
      String url, T Function(dynamic json) function) async {
    int skip = 0;
    const int concurrentCount = 6;
    final List<T> resultList = <T>[];
    bool atEndOfList = false;
    while (!atEndOfList) {
      final List<Future<String>> futures = <Future<String>>[];
      for (int i = 0; i < concurrentCount; i++) {
        futures.add(_fetchAsString(url, skip));
        skip += 500;
      }
      final List<String> results = await Future.wait(futures);
      for (String result in results) {
        try {
          final List<dynamic> rawList =
              jsonDecode(result)['value'] as List<dynamic>;
          if (rawList == null || rawList.isEmpty) break;
          resultList.addAll(rawList.map<T>(function));
          if (rawList.length < 500) {
            atEndOfList = true;
            break;
          }
        } on FormatException {
          continue;
        }
      }
    }
    return resultList;
  }

  Future<List<BusStop>> _fetchBusStopList() async {
    return _fetchAsList(_kGetBusStopsUrl, BusStop.fromJson);
  }

  Future<String> _fetchBusStopArrivalList(String busStopCode) async {
    return _fetchAsString(
        _kGetBusStopArrivalUrl, 0, '&BusStopCode=' + busStopCode);
  }

  Future<List<BusService>> _fetchBusServiceList() async {
    return _fetchAsList(_kGetBusServicesUrl, BusService.fromJson);
  }

  Future<List<Map<String, dynamic>>> _fetchBusServiceRouteList() async {
    return _fetchAsList(_kGetBusRoutesUrl, busServiceRouteStopToJson);
  }

  Future<void> fetchAndStoreBusStops() async {
    final List<BusStop> busStops = await _fetchBusStopList();
    cacheBusStops(busStops);
  }

  Future<void> fetchAndStoreBusServices() async {
    final List<BusService> busServices = await _fetchBusServiceList();
    cacheBusServices(busServices);
  }

  Future<void> fetchAndStoreBusServiceRoutes() async {
    final List<Map<String, dynamic>> busServiceRoutesRaw =
        await _fetchBusServiceRouteList();
    cacheBusServiceRoutes(busServiceRoutesRaw);
  }
}
