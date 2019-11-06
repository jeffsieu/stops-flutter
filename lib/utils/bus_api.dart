import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/bus_service.dart';
import '../utils/bus_stop.dart';
import '../utils/database_utils.dart';

class BusAPI {
  factory BusAPI() {
    _singleton.loadAPIKey();
    return _singleton;
  }

  BusAPI._internal();

  static const String _kApiTag = 'AccountKey';
  String _kApiKey;

  static const String _kRootUrl = 'http://datamall2.mytransport.sg/ltaodataservice/';
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

  static const String kBusServiceNumberKey = 'ServiceNo';
  static const String kBusServiceOperatorKey = 'Operator';
  static const String kBusServiceDirectionKey = 'Direction';
  static const String kBusServiceOriginKey = 'OriginCode';
  static const String kBusServiceDestinationKey = 'DestinationCode';

  static const String kBusServiceRouteStopSequenceKey = 'StopSequence';

  static const int _kRefreshInterval = 30;

  static const String kNoBusesError = 'No buses in service';
  static const String kNoInternetError = 'No internet connection';
  static const String kLoadingMessage = 'Loading buses...';

  static final BusAPI _singleton = BusAPI._internal();

  final List<BusService> _busServices = <BusService>[];
  final List<BusStop> _busStops = <BusStop>[];
  final Map<BusStop, StreamController<String>> _arrivalControllers = <BusStop, StreamController<String>>{};
  final Map<BusStop, String> _arrivalCache = <BusStop, String>{};

  bool _areBusStopsLoaded = false;
  bool _areBusServicesLoaded = false;
  int _arrivalSkip = 0;
  int _servicesSkip = 0;

  /*
   * Load LTA API key from secrets.json file in root directory
   * and store in memory
   */
  Future<void> loadAPIKey() async {
    final String jsonString = await rootBundle.loadString('assets/secrets.json');
    _kApiKey = json.decode(jsonString)['lta_api_key'];
  }

  /*
   * A stream that returns a list of bus stops.
   *
   * Every time the stream will return 500 more
   * bus stops until the whole list is loaded,
   * after which any subsequent listens to the
   * stream will return the full list of stops.
   */
  Stream<List<BusStop>> busStopsStream() {
    StreamController<List<BusStop>> controller;
    Future<void> onListen() async {
      if (!await areBusStopsCached()) {
        while (!_areBusStopsLoaded) {
          final String result = await _fetchBusStopList(_arrivalSkip);
          final List<dynamic> resultList = jsonDecode(result)['value'];
          _busStops.addAll(resultList.map((dynamic busStopJson) =>
              BusStop.fromJson(busStopJson)));

          if (resultList.length != 500) {
            _areBusStopsLoaded = true;
          } else {
            controller.add(_busStops);
            _arrivalSkip += 500;
          }
        }
        cacheBusStops(_busStops);
      } else if (!_areBusStopsLoaded){
        _busStops.addAll(await getCachedBusStops());
        _areBusStopsLoaded = true;
      }
      controller.add(_busStops);
    }

    controller = StreamController<List<BusStop>>(onListen: onListen);
    return controller.stream;
  }

  Stream<List<BusService>> busServicesStream() {
    StreamController<List<BusService>> controller;
    Future<void> onListen() async {
      if (!await areBusServicesCached()) {
        while (!_areBusServicesLoaded) {
          final String result = await _fetchBusServiceList(_servicesSkip);
          final List<dynamic> resultList = jsonDecode(result)['value'];
          _busServices.addAll(resultList.map((dynamic busServiceJson) =>
              BusService.fromJson(busServiceJson)));

          if (resultList.length != 500) {
            _areBusServicesLoaded = true;
          } else {
            controller.add(_busServices);
            _servicesSkip += 500;
          }
        }
        cacheBusServices(_busServices);
      } else if (!_areBusServicesLoaded){
        _busServices.addAll(await getCachedBusServices());
        _areBusServicesLoaded = true;
      }
      controller.add(_busServices);
    }

    controller = StreamController<List<BusService>>(onListen: onListen);
    return controller.stream;
  }

  String busStopArrivalLatest(BusStop busStop) {
    return _arrivalCache[busStop];
  }

  Stream<String> busStopArrivalStream(BusStop busStop)  {
    if (busStop == null) {
      return null;
    } else if (_arrivalControllers.containsKey(busStop)) {
      return _arrivalControllers[busStop].stream;
    } else {
      Timer timer;
      StreamController<String> controller;

      void fetchBusStops(Timer timer){
        _fetchBusStopArrivalList(busStop.code).then((String result) {
          _arrivalCache[busStop] = result;
          controller.add(result);
        });
      }

      void startTimer() {
        fetchBusStops(null);
        timer = Timer.periodic(const Duration(seconds: _kRefreshInterval), fetchBusStops);
      }

      void onCancel() {
        if (timer != null)
          timer.cancel();
        timer = null;
      }

      controller = StreamController<String>.broadcast(
        onListen: startTimer,
        onCancel: onCancel,
      );

      _arrivalControllers.putIfAbsent(busStop, () => controller);
      return controller.stream;
    }
  }

  Future<String> _fetchAsString(String url, int skip, [String extraParams = '']) async {
    final HttpClientRequest request = await HttpClient().getUrl(Uri.parse('$_kRootUrl$url?\$skip=$skip$extraParams'));
    request.headers.set(_kApiTag, _kApiKey);
    request.headers.set('Content-Type', 'application/json');

    final HttpClientResponse response = await request.close();
    final Future<String> content = utf8.decodeStream(response);

    return content;
  }

  Future<String> _fetchBusStopList(int skip) async {
    return _fetchAsString(_kGetBusStopsUrl, skip);
  }

  Future<String> _fetchBusStopArrivalList(String busStopCode) async {
    return _fetchAsString(_kGetBusStopArrivalUrl, 0, '&BusStopCode=' + busStopCode);
  }

  Future<String> _fetchBusServiceList(int skip) async {
    return _fetchAsString(_kGetBusServicesUrl, skip);
  }

  Future<String> _fetchBusServiceRouteList(int skip) async {
    return _fetchAsString(_kGetBusRoutesUrl, skip);
  }

  Future<void> fetchAndStoreBusServiceRoutes() async {
    int skip = 0;
    List<dynamic> resultList;

    final Batch batch = await beginBatchTransaction();

    do {
      final String result = await _fetchBusServiceRouteList(skip);
      resultList = jsonDecode(result)['value'];
      for (dynamic busStop in resultList) {
        cacheBusServiceRouteStop(busStop, batch);
      }
      skip += 500;
    } while (resultList.isNotEmpty);
    await batch.commit(noResult: true);
    await setBusServiceRoutesCached();
  }
}