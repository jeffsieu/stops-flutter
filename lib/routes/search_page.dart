import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:latlong/latlong.dart' as latlong;

import '../utils/bus_api.dart';
import '../utils/bus_service.dart';
import '../utils/bus_stop.dart';
import '../utils/bus_utils.dart';
import '../utils/database_utils.dart';
import '../utils/location_utils.dart';
import '../widgets/bus_stop_search_item.dart';
import 'bottom_sheet_page.dart';
import 'bus_service_page.dart';
import 'home_page.dart';


class SearchPage extends BottomSheetPage {
  final double _mapHeight = 300.0;
  final int _furthestBusStopDistanceMeters = 1000;
  final int offsetDistance = 300;

  @override
  State<StatefulWidget> createState() {
    return _SearchPageState();
  }

  static _SearchPageState of(BuildContext context) =>
      context.ancestorStateOfType(const TypeMatcher<_SearchPageState>());
}

class _SearchPageState extends BottomSheetPageState<SearchPage> {
  // The number of pixels to offset the FAB by animates out
  // via a fade down
  final double _fabTopOffset = 128;

  List<BusService> _busServices = <BusService>[];
  List<BusService> _filteredBusServices;
  List<BusStop> _busStops = <BusStop>[];
  List<BusStop> _filteredBusStops;

  String _query = '';
  Map<BusStop, dynamic> _queryMetadata = <BusStop, dynamic>{};
  final Map<BusStop, double> _distanceMetadata = <BusStop, double>{};

  List<String> _searchHistory = <String>[];

  LocationData location;
  bool _isDistanceLoaded = false;
  bool _showServicesOnly = false;
  bool _isMapVisible = false;
  bool _isMapCreated = false;

  Animation<double> _clearIconAnimation;
  AnimationController _clearIconAnimationController;
  TextEditingController _textController;

  AnimationController _mapClipperAnimationController;
  Animation<double> _mapClipperAnimation;

  ScrollController _scrollController;

  GoogleMap _googleMap;

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
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _mapClipperAnimation = CurvedAnimation(
      parent: _mapClipperAnimationController,
      curve: Curves.easeInOutQuart,
      reverseCurve: Curves.easeInToLinear,
    );

    /* Retrieve user location then sort bus stops accordingly */
    location = LocationUtils.getLatestLocation();
    if (location != null) {
      if (_filteredBusStops != null)
        _updateBusStopDistances(location);
    } else {
      LocationUtils
          .getLocation()
          .then((LocationData location) {
        this.location = location;
        if (location != null && _filteredBusStops != null)
          _updateBusStopDistances(location);
      });
    }

    _fetchBusStops();
    _fetchBusServices();
    areBusServiceRoutesCached().then((bool stored) {
      if (!stored)
        BusAPI().fetchAndStoreBusServiceRoutes();
    });

    _scrollController = ScrollController();
    _scrollController.addListener(() {
      FocusScope.of(context).requestFocus(FocusNode());
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _clearIconAnimationController.dispose();
    _mapClipperAnimationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleWithBrightness(MediaQuery.of(context).platformBrightness));
    buildSheet(hasAppBar: false);
    _isMapCreated = false;
    if (_query.isEmpty)
      _clearIconAnimationController.reverse();
    else
      _clearIconAnimationController.forward();

    /* Initialize google map */
    CameraPosition _initialCameraPosition = const CameraPosition(
        bearing: 192.8334901395799,
        target: LatLng(37.43296265331129, -122.08832357078792),
        tilt: 59.440717697143555,
        zoom: 19.151926040649414);

    if (location != null)
      _initialCameraPosition = CameraPosition(
          bearing: 192.8334901395799,
          target: LatLng(location.latitude, location.longitude),
          tilt: 59.440717697143555,
          zoom: 19.151926040649414);

    _googleMap = GoogleMap(
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{}
        ..add(Factory<PanGestureRecognizer>(() => PanGestureRecognizer()))
        ..add(Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()))
        ..add(Factory<VerticalDragGestureRecognizer>(() => VerticalDragGestureRecognizer())),
      initialCameraPosition: _initialCameraPosition,
      onMapCreated: (GoogleMapController controller ) {
        if (!_googleMapController.isCompleted)
          _googleMapController.complete(controller);
        _isMapCreated = true;
        if (_isDistanceLoaded)
          initializeGoogleMapCameraPosition();
      },
      markers: _buildMapMarkers(location),
    );

    final Widget bottomSheetContainer = bottomSheet(child: _buildBody());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(child: bottomSheetContainer),
      floatingActionButton: Opacity(
        opacity: _isMapVisible || rubberAnimationController.value > rubberAnimationController.lowerBound ? 0 : 1,
        child: AnimatedBuilder(
          builder: (BuildContext context, Widget child) {
            return Transform.translate(
              offset: Offset(0, _fabTopOffset * min(rubberAnimationController.value, 0.5)),
              child: FloatingActionButton.extended(
                  onPressed: () => setState(() {
                    if (_isMapVisible) {
                      _mapClipperAnimationController.reverse();
                    }
                    else {
                      _mapClipperAnimationController.forward();
                      _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
                    }
                    _isMapVisible = !_isMapVisible;
                  }),
                  label: const Text('Choose on map'),
                  icon: const Icon(Icons.map)
              ),
            );
          }, animation: rubberAnimationController,
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    final TextField searchField = TextField(
      autofocus: true,
      controller: _textController,
      onChanged: (String newText) {
        setState(() {
          _query = newText;
        });
      },
      onTap: () {
        rubberAnimationController.animateTo(to: rubberAnimationController.lowerBound);
      },
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.all(16.0),
        border: InputBorder.none,
        hintText: 'Search for bus stops and buses',
      ),
    );

    return Hero(
      tag: 'searchField',
      child: Material(
        clipBehavior: Clip.none,
        type: MaterialType.card,
        elevation: 2.0,
        borderRadius: BorderRadius.circular(8.0),
        child: Row(
          children: <Widget>[
           IconButton(
            color: Theme.of(context).hintColor,
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.of(context).pop();
            }),
            Expanded(child: searchField),
            ScaleTransition(
              scale: _clearIconAnimation,
              child: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _textController.clear();
                  setState(() {
                    _query = '';
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    _filterLists();
    final List<Widget> slivers = <Widget>[
      SliverAppBar(
        brightness: MediaQuery.of(context).platformBrightness,
        backgroundColor: Colors.transparent,
        leading: null,
        automaticallyImplyLeading: false,
        titleSpacing: 8.0,
        elevation: 0.0,
        title: _buildSearchCard(),
        bottom: _showServicesOnly ? PreferredSize(
            preferredSize: AppBar().preferredSize,
            child: Row(
              children: <Widget>[
                const Padding(padding: EdgeInsets.all(16.0), child: Icon(Icons.filter_list)),
                Chip(label: const Text('Services'), onDeleted: () => _toggleShowServicesOnly()),
              ],
            )
        ) : null,
      ),

      if (_query.isEmpty)
          _buildHistory(),
      SliverToBoxAdapter(child: _buildMapWidget()),
      if (!_showServicesOnly && _filteredBusServices.isNotEmpty)
        _buildBusServicesSliverHeader(),
      _buildBusServiceList(),

      if (!_showServicesOnly) ... <Widget> {
        if (_filteredBusStops.isNotEmpty)
          _buildBusStopsSliverHeader(),
        _buildBusStopList(),
      },
    ];

    final Widget body = CustomScrollView(
        controller: _scrollController,
        slivers: slivers,
    );

    return body;
  }

  Widget _buildMapWidget() {
    return AnimatedBuilder(
      animation: _mapClipperAnimation,
      builder: (BuildContext context, Widget child) {
        return SizedOverflowBox(
          alignment: Alignment.topCenter,
          size: Size.fromHeight(_mapClipperAnimation.value * widget._mapHeight),
          child: ClipRect(
            clipper: _MapClipper(_mapClipperAnimation.value),
            child: child,
          ),
        );
      },
      child: Container(
        height: widget._mapHeight,
        child: _googleMap,
      ),
    );
  }

  Set<Marker> _buildMapMarkers(LocationData location) {
    final Set<Marker> markers = <Marker>{};

    if (location == null) {
      return markers;
    }

    markers.add(Marker(
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
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
        markerId: MarkerId('${busStop.code}'),
        position: LatLng(
            busStop.latitude,
            busStop.longitude
        ),
        infoWindow: InfoWindow(title: busStop.displayName, snippet: busStop.road),
        onTap: () {
          showBusDetailSheet(busStop);
        },
      ));
    }

    return markers;
  }

  void _filterLists() {
    if (_query.isEmpty && !_showServicesOnly) {
      _filteredBusServices = <BusService>[];
    } else {
      _filteredBusServices = _filterBusServices(_busServices, _query).toList();
      _filteredBusServices.sort((BusService a, BusService b) =>
          compareBusNumber(a.number, b.number));
    }

    _filteredBusStops = _filterBusStops(_busStops, _query).toList();
    final Iterable<dynamic> metadataIterable = _filteredBusStops.map<dynamic>((BusStop busStop) => <dynamic>[busStop, _calculateQueryMetadata(busStop, _query)]);
    _queryMetadata = Map<BusStop, dynamic>.fromIterable(metadataIterable, key: (dynamic item) => item[0], value: (dynamic item) => item[1]);


    if (location != null && !_isDistanceLoaded)
      _updateBusStopDistances(location);
  }

  Widget _buildHistory() {
    return SliverToBoxAdapter(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        margin: const EdgeInsets.all(8.0),
        child: InkWell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_searchHistory.isNotEmpty) ... <Widget> {
                Padding(
                  padding: const EdgeInsets.only(
                      left: 16.0, top: 16.0, bottom: 8.0),
                  child: Text.rich(
                      const TextSpan(text: 'Past searches'), style: Theme.of(context).textTheme.display1),
                ),
              },
              FutureBuilder<List<String>>(
                future: getHistory(),
                initialData: _searchHistory,
                builder: (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
                  if (snapshot.data != null)
                    _searchHistory = snapshot.data;
                  return ListView.builder(
                    padding: const EdgeInsets.all(0.0),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (BuildContext context, int position) {
                      return ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(snapshot.data[position]),
                          onTap: () => setState(() {
                            _query = snapshot.data[position];
                            _textController.text = _query;
                            _textController.selection = TextSelection(baseOffset: _query.length, extentOffset: _query.length);
                          }),
                      );
                    },
                    itemCount: snapshot.data != null ? snapshot.data.length : 0,
                  );
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusServicesSliverHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, left: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('Services', style: Theme.of(context).textTheme.display1),
            FlatButton(
              onPressed: _toggleShowServicesOnly,
              child: const Text('See all'),
              textColor: Theme.of(context).accentColor,)
          ],
        ),
      ),
    );
  }

  Widget _buildBusStopsSliverHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, left: 16.0),
        child:
        Text('Bus stops', style: Theme.of(context).textTheme.display1),
      ),
    );
  }

  Widget _buildBusServiceList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int position) {
          final BusService busService = _filteredBusServices[position];
          return ListTile(
            onTap: () => _pushBusServiceRoute(busService),
            title: Text(busService.number),
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
          );
        },
        childCount: _showServicesOnly ? 0 : _filteredBusStops.length,
      )
    );
  }


  @override
  void showBusDetailSheet(BusStop busStop) {
    super.showBusDetailSheet(busStop);
    pushHistory(_query);
  }

  void _toggleShowServicesOnly() {
    setState(() {
      _showServicesOnly = !_showServicesOnly;
    });
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
    if (_isMapCreated)
      initializeGoogleMapCameraPosition();
  }

  Future<void> initializeGoogleMapCameraPosition() async {
    final GoogleMapController controller = await _googleMapController.future;
    final latlong.LatLng latLng =  latlong.LatLng(location.latitude, location.longitude);
    final latlong.LatLng northeast = const latlong.Distance().offset(latLng, widget.offsetDistance, 45);
    final latlong.LatLng southwest = const latlong.Distance().offset(latLng, widget.offsetDistance, 225);

    final LatLng ne = LatLng(northeast.latitude, northeast.longitude);
    final LatLng sw = LatLng(southwest.latitude, southwest.longitude);

    controller.moveCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 10.0));
  }

  Future<void> _fetchBusStops() async {
    BusAPI().busStopsStream().listen((List<BusStop> busStops) {
      if (mounted)
        setState(() {
          _busStops = List<BusStop>.from(busStops);
        });
      if (location != null && _filteredBusStops != null)
        _updateBusStopDistances(location);
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

  static Iterable<BusStop> _filterBusStops(List<BusStop> list, String query) => list.where((BusStop busStop) => _matchesQuery(busStop, query));

  static bool _matchesQuery(BusStop busStop, String query) {
    final String queryLowercase = query.toLowerCase();
    final String busStopCodeLowercase = busStop.code.toLowerCase();
    final String busStopDisplayNameLowercase = busStop.displayName.toLowerCase();
    final String busStopDefaultNameLowercase = busStop.defaultName.toLowerCase();

    return busStopCodeLowercase.contains(queryLowercase) || busStopDisplayNameLowercase.contains(queryLowercase) || busStopDefaultNameLowercase.contains(queryLowercase);
  }

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
    final Route<void> route = MaterialPageRoute<void>(builder: (BuildContext context) => BusServicePage(busService.number));
    pushHistory(_query); // add query to history
    Navigator.push(context, route);
  }
}

class _MapClipper extends CustomClipper<Rect> {
  _MapClipper(this.heightFactor);

  final double heightFactor;

  @override
  Rect getClip(Size size) {
    return const Offset(0, 0) & Size(size.width, size.height * heightFactor);
  }

  @override
  bool shouldReclip(_MapClipper oldClipper) {
    return oldClipper.heightFactor != heightFactor;
  }

}