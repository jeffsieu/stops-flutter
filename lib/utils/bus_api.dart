import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../utils/bus_service.dart';
import '../utils/bus_stop.dart';
import '../utils/shared_preferences_utils.dart';

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

  final List<BusServiceRoute> _busServices = <BusServiceRoute>[];
  final List<BusStop> _busStops = <BusStop>[];
  final Map<BusStop, StreamController<String>> _arrivalControllers = <BusStop, StreamController<String>>{};
  final Map<BusStop, String> _arrivalCache = <BusStop, String>{};

  bool _isBusStopsLoaded = false;
  bool _isBusServicesLoaded = false;
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
        while (!_isBusStopsLoaded) {
          final String result = await _fetchBusStopList(_arrivalSkip);
          final List<dynamic> resultList = jsonDecode(result)['value'];
          _busStops.addAll(resultList.map((dynamic busStopJson) =>
              BusStop.fromJson(busStopJson)));

          if (resultList.length != 500) {
            _isBusStopsLoaded = true;
          } else {
            controller.add(_busStops);
            _arrivalSkip += 500;
          }
        }
        cacheBusStops(_busStops);
      } else if (!_isBusStopsLoaded){
        _busStops.addAll(await getCachedBusStops());
        _isBusStopsLoaded = true;
      }
      controller.add(_busStops);
    }

    controller = StreamController<List<BusStop>>(onListen: onListen);

    return controller.stream;
  }

  Stream<List<BusServiceRoute>> busServicesStream() {
    StreamController<List<BusServiceRoute>> controller;

    Future<void> onListen() async {
      while (!_isBusServicesLoaded) {
        final String result = await _fetchBusServiceList(_servicesSkip);
        final List<dynamic> resultList = jsonDecode(result)['value'];
        _busServices.addAll(resultList.map((dynamic busServiceRouteJson) => BusServiceRoute.fromJson(busServiceRouteJson)));

        if (resultList.length != 500) {
          _isBusServicesLoaded = true;
        } else {
          controller.add(_busServices);
          _servicesSkip += 500;
        }
      }
      controller.add(_busServices);
    }

    controller = StreamController<List<BusServiceRoute>>(onListen: onListen);
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

  Future<void> fetchAndStoreBusServiceSkips() async {
    int skip = 0;

    while (true) {
      final String result = await BusAPI()._fetchAsString(_kGetBusRoutesUrl, skip);
      final List<dynamic> resultList = jsonDecode(result)['value'];
      for (int i in Iterable<int>.generate(resultList.length, (int index) => index)) {
        final int busServiceSkip = skip + i;
        final dynamic busServiceRouteJson = resultList[i];
        if (busServiceRouteJson[kBusServiceRouteStopSequenceKey] == 1 && busServiceRouteJson[kBusServiceDirectionKey] == 1) {
          final String serviceNumber = busServiceRouteJson[kBusServiceNumberKey];
          storeBusServiceSkip(serviceNumber, busServiceSkip);
        }
      }

      if (resultList.length != 500)
        break;

      skip += 500;
    }

    setBusServiceSkipsStored();
  }

  Future<Map<String, List<dynamic>>> getBusStopsInService(String serviceNumber) async {
    int skip = await getBusServiceSkip(serviceNumber);

    // if skip was not previously found, manually find it
    if (skip == -1) {
      skip = await _findBusServiceSkip(serviceNumber);
      storeBusServiceSkip(serviceNumber, skip);
    }

    String result = await _fetchAsString(_kGetBusRoutesUrl, skip);
    List<dynamic> resultList = jsonDecode(result)['value'];

    final dynamic firstBusStopJson = resultList[0];
    if (firstBusStopJson[kBusServiceDirectionKey] != 1 || firstBusStopJson[kBusServiceRouteStopSequenceKey] != 1) {
      // Skip value is invalid
      skip = await _findBusServiceSkip(serviceNumber, skip);
      storeBusServiceSkip(serviceNumber, skip);

      result = await _fetchAsString(_kGetBusRoutesUrl, skip);
      resultList = jsonDecode(result)['value'];
    }

    final Iterable<dynamic> serviceList = resultList.where((dynamic busStop) => busStop[kBusServiceNumberKey] == serviceNumber);
    final List<dynamic> direction1 = serviceList.where((dynamic busStop) => busStop[kBusServiceDirectionKey] == 1).toList();
    final List<dynamic> direction2 = serviceList.where((dynamic busStop) => busStop[kBusServiceDirectionKey] == 2).toList();

    direction1.sort((dynamic a, dynamic b) => a[kBusServiceRouteStopSequenceKey] - b[kBusServiceRouteStopSequenceKey]);
    direction2.sort((dynamic a, dynamic b) => a[kBusServiceRouteStopSequenceKey] - b[kBusServiceRouteStopSequenceKey]);

    final List<BusStop> busStops1 = <BusStop>[];
    final List<BusStop> busStops2 = <BusStop>[];

    for (dynamic json in direction1) {
      final BusStop busStop = await getCachedBusStopWithCode(json[kBusStopCodeKey]);
      busStops1.add(busStop);
    }

    for (dynamic json in direction2) {
      final BusStop busStop = await getCachedBusStopWithCode(json[kBusStopCodeKey]);
      busStops2.add(busStop);
    }

    final List<double> distances1 = direction1.map<double>((dynamic json) => double.tryParse(json[kBusStopDistanceKey].toString())).toList();
    final List<double> distances2 = direction2.map<double>((dynamic json) => double.tryParse(json[kBusStopDistanceKey].toString())).toList();

    assert(busStops1.isNotEmpty);
    assert(distances1.isNotEmpty);
    final List<List<BusStop>> busStopList = <List<BusStop>>[];
    final List<List<double>> distanceList = <List<double>>[];
    busStopList.add(busStops1);
    distanceList.add(distances1);
    if (busStops2.isNotEmpty) {
      busStopList.add(busStops2);
      distanceList.add(distances2);
    }

    return <String, List<dynamic>>{'routes': busStopList, 'distances': distanceList};
  }

  // finds the busService in log n time
  // Since n is around 27000, log2(n) is 14.7.
  // and the function will find the result within 15 tries
  Future<int> _findBusServiceSkip(String serviceNumber, [int initialSkip]) async {
    const int approxTotalSkips = 26353;

    int totalTries = 15;
    int lowerBound = 0, upperBound = approxTotalSkips;
    int adjustmentFactor = 1;
    int prevDirection = 0;
    int nextSkip = initialSkip ?? ((lowerBound + upperBound)/2).floor();
    int nextValue;
    while (totalTries > 0) {
      final String result = await _fetchAsString(_kGetBusRoutesUrl, nextSkip);

      final List<dynamic> resultList = jsonDecode(result)['value'];
      final String firstServiceNumber = resultList[0][kBusServiceNumberKey];
      final int firstDirection = resultList[0][kBusServiceDirectionKey];
      final int firstStopSequence = resultList[0][kBusServiceRouteStopSequenceKey];

      // We use compareTo instead of of BusUtils.compareBusNumber
      // because this is how the API sorts the bus service numbers

      //1.compareTo(2) returns -1 so if difference < 0, serviceNumber < firstServiceNumber
      final int firstDifference = serviceNumber.compareTo(firstServiceNumber);

      if (prevDirection == firstDifference.sign) {
        adjustmentFactor *= 2;
      } else {
        adjustmentFactor = 1;
      }

      prevDirection = firstDifference.sign;

      // if the adjustment factor is 1, we move to 1/2
      // if the adjustment factor is 2, we move to 1/4 or 3/4

      // weight is either 1/2, 1/4, 1/8, ...
      final double weight = 1/(adjustmentFactor*2);

      // factor is either 1/4 or 3/4, 1/8 or 7/8
      final double factor = (-firstDifference.sign * weight) % 1;


      if (firstDifference < 0) {
        upperBound = nextSkip;
        nextSkip = (lowerBound + (upperBound - lowerBound).roundToDouble() * factor).round();
      } else if (firstDifference > 0) {
        lowerBound = nextSkip;
        nextSkip = (lowerBound + (upperBound - lowerBound).roundToDouble() * factor).round();
      } else {
        // Service number has been found;
        if (firstDirection != 1) {
          // Landed somewhere in direction 2
          nextValue = nextSkip - firstStopSequence - 1;
          nextSkip = nextValue;
        } else if (firstStopSequence != 0) {
          // Landed in direction 1 but the stop sequence is too large
          nextValue = nextSkip - firstStopSequence;
          nextSkip = nextValue;
          break;
        } else {
          // Landed just right on direction 1 and stop sequence 1
          return nextSkip;
        }
      }

      totalTries -= 1;
    }
    throw Exception('Invalid bus service');
  }
}