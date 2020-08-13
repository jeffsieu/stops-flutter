import 'dart:async';
import 'dart:math';

import 'package:edit_distance/edit_distance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong/latlong.dart' as latlong;
import 'package:location/location.dart';

import '../main.dart';
import '../models/bus_service.dart';
import '../models/bus_stop.dart';
import '../models/user_route.dart';
import '../utils/bus_api.dart';
import '../utils/bus_utils.dart';
import '../utils/database_utils.dart';
import '../utils/location_utils.dart';
import '../widgets/bus_service_search_item.dart';
import '../widgets/bus_stop_search_item.dart';
import '../widgets/card_app_bar.dart';
import 'bottom_sheet_page.dart';
import 'bus_service_page.dart';


class SearchPage extends BottomSheetPage {
  SearchPage({this.showMap = false}) : isSimpleMode = false;
  SearchPage.onlyBusStops() : showMap = false, isSimpleMode = true;

  final int _furthestBusStopDistanceMeters = 1000;
  final int offsetDistance = 300;
  final double searchDifferenceThreshold = 0.2;
  final bool showMap;
  final bool isSimpleMode;

  @override
  State<StatefulWidget> createState() {
    return _SearchPageState();
  }

  static _SearchPageState of(BuildContext context) =>
      context.findAncestorStateOfType<_SearchPageState>();
}

class _SearchPageState extends BottomSheetPageState<SearchPage> {
  // The number of pixels to offset the FAB by animates out
  // via a fade down
  final double _fabTopOffset = 128;
  final double _resultsSheetCollapsedHeight = 72;

  List<BusService> _busServices = <BusService>[];
  List<BusService> _filteredBusServices;
  List<BusStop> _busStops = <BusStop>[];
  List<BusStop> _filteredBusStops;
  JaroWinkler jw = JaroWinkler();

  String _queryString = '';
  String get _query => _queryString;
  set _query(String query) {
    _queryString = query;
    _textController?.text = _queryString;
  }
  Map<BusStop, dynamic> _queryMetadata = <BusStop, dynamic>{};
  final Map<BusStop, double> _distanceMetadata = <BusStop, double>{};

  List<String> _searchHistory = <String>[];

  LocationData location;
  bool _isDistanceLoaded = false;
  final bool _showServicesOnly = false;
  bool _isMapVisible;

  Animation<double> _clearIconAnimation;
  AnimationController _clearIconAnimationController;
  TextEditingController _textController;

  AnimationController _mapClipperAnimationController;
  Animation<double> _mapClipperAnimation;
  Animation<double> _fabScaleAnimation;

  ScrollController _scrollController;

  GoogleMap _googleMap;
  String _googleMapDarkStyle;

  final Completer<GoogleMapController> _googleMapController = Completer<GoogleMapController>();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _clearIconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _clearIconAnimation = CurvedAnimation(parent: _clearIconAnimationController, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);

    _mapClipperAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _mapClipperAnimation = CurvedAnimation(
      parent: _mapClipperAnimationController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    final Animation<double> fabScaleAnimationNoCurve = CurvedAnimation(parent: _mapClipperAnimationController, curve: const Interval(0, 0.7), reverseCurve: const Interval(0.3, 1))
        .drive(Tween<double>(begin: 1.0, end: 0.0));

    _fabScaleAnimation = CurvedAnimation(
      parent: fabScaleAnimationNoCurve,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );

    _scrollController = ScrollController();
    _isMapVisible = widget.showMap;

    /* Retrieve user location then sort bus stops accordingly */
    location = LocationUtils.getLatestLocation();
    if (location != null && LocationUtils.isLocationCurrent()) {
      if (_filteredBusStops != null)
        _updateBusStopDistances(location);
    } else {
      LocationUtils.getLocation().then((LocationData location) {
        setState(() {
          this.location = location;
        });
        if (location != null && _filteredBusStops != null)
          _updateBusStopDistances(location);
      });
    }

    _fetchBusStops();

    // If normal mode, perform bus service and map-related functions
    if (widget.isSimpleMode)
      return;

    _fetchBusServices();
    areBusServiceRoutesCached().then((bool stored) {
      if (!stored)
        BusAPI().fetchAndStoreBusServiceRoutes();
    });

    rootBundle.loadString('assets/maps/map_style_dark.json').then((String style) {
      _googleMapDarkStyle = style;
    });

    if (_isMapVisible) {
      _mapClipperAnimationController.value = 1;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _clearIconAnimationController.dispose();
    _mapClipperAnimationController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    // Clear query if not empty
    if (_query.isNotEmpty) {
      setState(() {
        _query = '';
      });
      return false;
    }

    // If launched as list view, return to list view first
    // If launched as map view, return to map view first
    if (widget.showMap != _isMapVisible) {
      setState(() {
        _isMapVisible = widget.showMap;
      });
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleOf(context));
    buildSheet(hasAppBar: false);
    if (_query.isEmpty)
      _clearIconAnimationController.reverse();
    else
      _clearIconAnimationController.forward();

    if (_isMapVisible) {
      _mapClipperAnimationController.forward();
    }
    else {
      _mapClipperAnimationController.reverse();
    }
    final Widget bottomSheetContainer = bottomSheet(child: _buildBody());

    final Widget floatingActionButton = ScaleTransition(
      scale: _fabScaleAnimation,
      child: AnimatedBuilder(
        animation: rubberAnimationController,
        builder: (BuildContext context, Widget child) {
          return Transform.translate(
            offset: Offset(0, _fabTopOffset * rubberAnimationController.value.clamp(0.0, 0.5)),
            child: child,
          );
        },
        child: FloatingActionButton.extended(
            onPressed: () => setState(() {
              _isMapVisible = !_isMapVisible;
              if (_isMapVisible)
                _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
              _hideKeyboard();
            }),
            label: const Text('Choose on map'),
            icon: const Icon(Icons.map)
        ),
      ),
    );

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Material(child: bottomSheetContainer),
        floatingActionButton: widget.isSimpleMode ? null : floatingActionButton,
      ),
    );
  }

  Widget _buildSearchCard() {
    final TextField searchField = TextField(
      autofocus: !widget.showMap,
      controller: _textController,
      onChanged: (String newText) {
        setState(() {
          _queryString = newText;
        });
        _scrollController.jumpTo(0);
      },
      onTap: () {
        hideBusDetailSheet();
        if (_isMapVisible)
          setState(() {
            _isMapVisible = false;
          });
      },
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0, bottom: 16.0),
        border: InputBorder.none,
        hintText: widget.isSimpleMode ? 'Search for stops' : 'Search for stops, services',
      ),
    );
    return Hero(
      tag: 'searchField',
      child: CardAppBar(
        elevation: 2.0,
        leading: IconButton(
          color: Theme.of(context).hintColor,
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: searchField,
        actions: <Widget>[
          ScaleTransition(
            scale: _clearIconAnimation,
            child: IconButton(
              color: Theme.of(context).hintColor,
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _query = '';
                });
              },
            )
          ),
        ],
      )
    );
  }

  Widget _buildBody() {
    _generateQueryResults();
    final List<Widget> slivers = <Widget>[
      SliverToBoxAdapter(
        child: Container(
          alignment: Alignment.topCenter,
          height: 64.0 + MediaQuery.of(context).padding.top,
          child: InkWell(
            onTap: () {
              setState(() {
                _isMapVisible = false;
              });
            },
            child: Container(
              height: _resultsSheetCollapsedHeight,
              child: FadeTransition(
                opacity: _mapClipperAnimation,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Icon(Icons.keyboard_arrow_up, color: Theme.of(context).accentColor,),
                    ),
                    Text(
                      'Hide map',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.subtitle1.copyWith(color: Theme.of(context).accentColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
      ),
      SliverToBoxAdapter(
        child: Container(
          height: 8.0,
        ),
      ),
      if (_query.isEmpty)
          _buildHistory(),

      if (!_showServicesOnly && _filteredBusServices.isNotEmpty)
        _buildBusServicesSliverHeader(),
      _buildBusServiceList(),

      if (!_showServicesOnly) ... <Widget> {
        if (_filteredBusStops.isNotEmpty && (_filteredBusServices.isNotEmpty || _query.isEmpty))
          _buildBusStopsSliverHeader(),
        _buildBusStopList(),
      },
      SliverToBoxAdapter(
        child: Container(
          height: 80.0,
        ),
      ),
    ];

    final Widget body = Stack(
      children: <Widget>[
        _buildMapWidget(),
        Stack(
          children: <Widget>[
            AnimatedBuilder(
              animation: _mapClipperAnimation,
              builder: (BuildContext context, Widget child) {
                return Transform.translate(offset: Offset(0, (MediaQuery.of(context).size.height - _resultsSheetCollapsedHeight) * _mapClipperAnimation.value), child: child);
              },
              child: Material(
                elevation: 4.0,
                color: Theme.of(context).scaffoldBackgroundColor,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification notification) {
                    if (notification is ScrollStartNotification && notification.dragDetails != null) {
                      _hideKeyboard();
                      return true;
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    physics: _isMapVisible ? const NeverScrollableScrollPhysics() : const ScrollPhysics(),
                    controller: _scrollController,
                    slivers: slivers,
                  ),
                ),
              ),
            ),
            // Hide the overscroll contents from the status bar, only when map not visible
            AnimatedBuilder(
              animation: _scrollController,
              builder: (BuildContext context, Widget child) {
                final bool showBackground = _scrollController.offset - kToolbarHeight / 2 - MediaQuery.of(context).padding.top >= 0 && !_isMapVisible;
                return Opacity(
                  opacity: showBackground ? 1 : 0,
                  child: child,
                );
              },
              child: Container(
                height: kToolbarHeight / 2 + MediaQuery.of(context).padding.top,
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
          ],
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: AppBar(
            brightness: Theme.of(context).brightness,
            backgroundColor: Colors.transparent,
            leading: null,
            automaticallyImplyLeading: false,
            titleSpacing: 16.0,
            elevation: 0.0,
            title: _buildSearchCard(),
          ),
        ),
      ],
    );

    return body;
  }

  Widget _buildMapWidget() {
    /* Initialize google map */
    final CameraPosition initialCameraPosition = _getCameraPositionFromLocation();

    _googleMap = GoogleMap(
      padding: EdgeInsets.only(top: 100 + MediaQuery.of(context).padding.top),
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      initialCameraPosition: initialCameraPosition,
      onMapCreated: (GoogleMapController controller) {
        if (!_googleMapController.isCompleted)
          _googleMapController.complete(controller);
        if (_isDistanceLoaded)
          controller.moveCamera(CameraUpdate.newCameraPosition(_getCameraPositionFromLocation()));
        if (MediaQuery.of(context).platformBrightness == Brightness.dark)
          controller.setMapStyle(_googleMapDarkStyle);
      },
      markers: _buildMapMarkers(location),
    );
    return Container(
      padding: EdgeInsets.only(bottom: _resultsSheetCollapsedHeight),
      child: _googleMap,
    );
  }

  CameraPosition _getCameraPositionFromLocation() {
    return CameraPosition(
      target: LatLng(location?.latitude ?? 1.3521, location?.longitude ?? 103.8198),
      zoom: 18,
    );
  }

  Set<Marker> _buildMapMarkers(LocationData location) {
    final Set<Marker> markers = <Marker>{};

    if (location == null) {
      return markers;
    }

    markers.add(Marker(
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      markerId: MarkerId('you_are_here'),
      position: LatLng(
          location.latitude,
          location.longitude
      ),
      infoWindow: const InfoWindow(title: 'You are here', snippet: ''),
    ));

    for (BusStop busStop in _busStops) {
      if (_distanceMetadata[busStop] > widget._furthestBusStopDistanceMeters)
        break;
      markers.add(Marker(
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        markerId: MarkerId('${busStop.code}'),
        position: LatLng(
            busStop.latitude,
            busStop.longitude
        ),
        infoWindow: InfoWindow(title: busStop.displayName, snippet: busStop.road),
        onTap: () {
          showBusDetailSheet(busStop, UserRoute.home);
        },
      ));
    }

    return markers;
  }

  void _generateQueryResults() {
    if (_query.isEmpty && !_showServicesOnly) {
      _filteredBusServices = <BusService>[];
    } else {
      _filteredBusServices =
          _filterBusServices(_busServices, _query).toList(growable: false);
      _filteredBusServices.sort((BusService a, BusService b) =>
          compareBusNumber(a.number, b.number));
    }

    final double maxDistance = _distanceMetadata.isNotEmpty ? _distanceMetadata.values.toList().reduce(max) : 0;

    if (_query.isNotEmpty) {
      final bool isQueryAllNumbers = num.tryParse(_queryString) != null;
      final num Function(BusStop) distanceFunction = (BusStop busStop) {
        final String busStopName = busStop.displayName.toLowerCase();
        final String queryLengthBusStopName = busStopName.length > _query.length ? busStopName.substring(0, _query.length) : busStopName;
        final List<String> busStopNameParts = busStopName.split(RegExp(r'( |/)'));
        double minTokenDifference = double.maxFinite;

        for (String part in busStopNameParts) {
          if (part.isEmpty)
            continue;
          if (_query.length < part.length)
            part = part.substring(0, _query.length);
          minTokenDifference = min(minTokenDifference, jw.normalizedDistance(part, _query.toLowerCase()));
        }

        double distance = jw.normalizedDistance(queryLengthBusStopName, _query.toLowerCase()) - 0.01;

        if (minTokenDifference < distance) {
          distance = minTokenDifference - 0.01 * (_query.length / busStopName.length);
        }

        if (isQueryAllNumbers) {
          final double codeDistance = busStop.code.startsWith(_queryString) ? -1 : 1;
          distance = min(distance, codeDistance);
        }

        // Add a small bit of distance to sort secondly by distance
        if (_distanceMetadata.isNotEmpty)
          distance += 0.0001 * _distanceMetadata[busStop] / maxDistance;

        return distance;
      };

      final List<List<dynamic>> sets = _busStops.map((BusStop busStop) => <dynamic>[distanceFunction(busStop), busStop]).
      where((List<dynamic> set) => set[0] < widget.searchDifferenceThreshold).toList();
      sets.sort((List<dynamic> set1, List<dynamic> set2) => set1[0].compareTo(set2[0]));
      _filteredBusStops = sets.map<BusStop>((List<dynamic> set) => set[1]).toList();
    } else {
      _filteredBusStops = _busStops;
    }
    final Iterable<dynamic> metadataIterable = _filteredBusStops.map<dynamic>((BusStop busStop) => <dynamic>[busStop, _calculateQueryMetadata(busStop, _query)]);
    _queryMetadata = Map<BusStop, dynamic>.fromIterable(metadataIterable, key: (dynamic item) => item[0], value: (dynamic item) => item[1]);


    if (location != null && !_isDistanceLoaded)
      _updateBusStopDistances(location);
  }

  Widget _buildHistory() {
    return FutureBuilder<List<String>>(
      future: getHistory(),
      initialData: _searchHistory,
      builder: (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
        if (snapshot.data == null || snapshot.data.isEmpty)
          return SliverToBoxAdapter(child: Container());
        _searchHistory = snapshot.data;
        return SliverToBoxAdapter(
          child: InkWell(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (BuildContext context, int position) {
                position = snapshot.data.length - 1 - position;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                  leading: Container(
                    width: 32.0,
                    alignment: Alignment.center,
                    child: Icon(Icons.history, color: Theme.of(context).hintColor),
                  ),
                  title: Text(snapshot.data[position], style: Theme.of(context).textTheme.headline6),
                  onTap: () => setState(() {
                    _query = snapshot.data[position];
                    _textController.text = _query;
                    _textController.selection = TextSelection(baseOffset: _query.length, extentOffset: _query.length);
                  }),
                );
              },
              itemCount: snapshot.data != null ? snapshot.data.length : 0,
            ),
          ),
        );
      }
    );
  }

  Widget _buildBusServicesSliverHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24.0, left: 80.0, bottom: 8.0),
        child: Text(
          'Services',
          style: Theme.of(context).textTheme.headline4.copyWith(
            color: BusService.listColor(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBusStopsSliverHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24.0, left: 80.0, bottom: 8.0),
        child:
        Text('Bus stops', style: Theme.of(context).textTheme.headline4),
      ),
    );
  }

  Widget _buildBusServiceList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int position) {
          final BusService busService = _filteredBusServices[position];
          return BusServiceSearchItem(
            onTap: () => _pushBusServiceRoute(busService),
            busService: busService,
          );
        },
        childCount: _showServicesOnly ? _filteredBusServices.length :  min(_filteredBusServices.length, 3),
      ),
    );
  }

  Widget _buildBusStopList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (BuildContext context, int position) {
          final BusStop busStop = _filteredBusStops[position];
          final Map<String, dynamic> metadata = _queryMetadata[busStop];

          final String distance = _distanceMetadata.containsKey(busStop) ? getDistanceVerboseFromMeters(_distanceMetadata[busStop]) : '';

          final String name = busStop.displayName;
          final String busStopCode = busStop.code;

          final String nameStart =
          name.substring(0, metadata['DescriptionStart']);
          final String nameBold = name.substring(
              metadata['DescriptionStart'], metadata['DescriptionEnd']);
          final String nameEnd = name.substring(
              metadata['DescriptionEnd'], name.length);

          final String busStopCodeStart =
          busStopCode.substring(0, metadata['BusStopCodeStart']);
          final String busStopCodeBold = busStopCode.substring(
              metadata['BusStopCodeStart'], metadata['BusStopCodeEnd']);
          final String busStopCodeEnd = busStopCode.substring(
              metadata['BusStopCodeEnd'], busStopCode.length);
          return BusStopSearchItem(
            key: Key(busStopCode),
            // necessary to let Flutter rebuild component when search is performed
            // (otherwise the filter works but clicking the item will show information for a different bus stop
            codeStart: busStopCodeStart,
            codeBold: busStopCodeBold,
            codeEnd: busStopCodeEnd,
            nameStart: nameStart,
            nameBold: nameBold,
            nameEnd: nameEnd,
            distance: distance,
            busStop: busStop,
            onTap: () => _onBusStopSearchItemTapped(busStop),
          );
        },
        childCount: _showServicesOnly ? 0 : _filteredBusStops.length,
      )
    );
  }

  void _hideKeyboard() {
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _onBusStopSearchItemTapped(BusStop busStop) {
    if (widget.isSimpleMode) {
      // Return result
      Navigator.pop(context, busStop);
    } else {
      // Show bus detail sheet
      FocusScope.of(context).unfocus();
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        showBusDetailSheet(busStop, UserRoute.home);
      });
    }
  }

  @override
  void showBusDetailSheet(BusStop busStop, UserRoute route) {
    super.showBusDetailSheet(busStop, route);
    pushHistory(_query.trim());
  }

  Future<void> _updateBusStopDistances(LocationData location) async {
    for (BusStop busStop in _busStops) {
      final double distanceMeters = const latlong.Distance().as(
          latlong.LengthUnit.Meter,
          latlong.LatLng(location.latitude, location.longitude),
          latlong.LatLng(busStop.latitude, busStop.longitude));
      _distanceMetadata[busStop] = distanceMeters;
    }

    /* Sort stops by distance */
    _busStops.sort((BusStop a, BusStop b) {
      final double distanceA = _distanceMetadata[a];
      final double distanceB = _distanceMetadata[b];
      if (distanceA == null || distanceB == null) {
        return 0;
      }
      return (distanceA - distanceB).floor();
    });

    if (mounted)
      setState(() {
        _isDistanceLoaded = true;
      });
  }

  Future<void> _fetchBusStops() async {
    BusAPI().busStopsStream().listen((List<BusStop> busStops) {
      if (mounted)
        setState(() {
          _busStops = List<BusStop>.from(busStops);
        });
      if (location != null && _filteredBusStops != null) {
        _updateBusStopDistances(location);
      }
    });
  }

  void _fetchBusServices() {
    BusAPI().busServicesStream().listen((List<BusService> busServices) {
      if (mounted)
        setState(() {
          _busServices = busServices;
        });
    });
  }

  static Iterable<BusService> _filterBusServices(List<BusService> list, String query) => list.where((BusService busService) =>
      busService.number.toLowerCase().startsWith(query.toLowerCase()));

  static Map<String, dynamic> _calculateQueryMetadata(BusStop busStop, String query) {
    final String queryLowercase = query.toLowerCase();
    final String busStopCodeLowercase = busStop.code.toLowerCase();
    final String busStopDisplayNameLowercase = busStop.displayName.toLowerCase();
//    final String busStopDefaultNameLowercase = busStop.defaultName.toLowerCase();
    // TODO(jeffsieu): Enable search by default name as well.

    int index = busStopCodeLowercase.indexOf(queryLowercase);

    final Map<String, dynamic> metadata = <String, dynamic>{};

    if (index != -1) {
      metadata['BusStopCodeStart'] = index;
      metadata['BusStopCodeEnd'] = index + query.length;
    } else {
      metadata['BusStopCodeStart'] = 0;
      metadata['BusStopCodeEnd'] = 0;
    }

    index = busStopDisplayNameLowercase.indexOf(queryLowercase);

    if (index != -1) {
      metadata['DescriptionStart'] = index;
      metadata['DescriptionEnd'] = index + query.length;
    } else {
      metadata['DescriptionStart'] = 0;
      metadata['DescriptionEnd'] = 0;
    }

    return metadata;
  }

  void _pushBusServiceRoute(BusService busService) {
    final Widget page = BusServicePage(busService.number);
    final Route<void> route = MaterialPageRoute<void>(builder: (BuildContext context) => page);
    pushHistory(_query); // add query to history
    Navigator.push(context, route);
  }
}