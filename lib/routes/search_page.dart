import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:edit_distance/edit_distance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:rubber/rubber.dart';
import '../bus_stop_sheet/bloc/bus_stop_sheet_bloc.dart';

import '../main.dart';
import '../models/bus_service.dart';
import '../models/bus_stop.dart';
import '../models/bus_stop_with_distance.dart';
import '../utils/bus_api.dart';
import '../utils/bus_utils.dart';
import '../utils/database_utils.dart';
import '../utils/location_utils.dart';
import '../widgets/bus_service_search_item.dart';
import '../widgets/bus_stop_search_item.dart';
import '../widgets/card_app_bar.dart';
import '../widgets/custom_rubber_bottom_sheet.dart';
import '../widgets/highlighted_icon.dart';
import 'bottom_sheet_page.dart';
import 'bus_service_page.dart';

class SearchPage extends BottomSheetPage {
  SearchPage({Key? key, this.showMap = false})
      : isSimpleMode = false,
        super(key: key);
  SearchPage.onlyBusStops({Key? key})
      : showMap = false,
        isSimpleMode = true,
        super(key: key);

  static const int _furthestBusStopDistanceMeters = 3000;
  static const double _searchDifferenceThreshold = 0.2;
  static const double _launchVelocity = 0.5;

  final bool showMap;
  final bool isSimpleMode;
  final GlobalKey _resultsSheetKey = GlobalKey();

  @override
  State<StatefulWidget> createState() {
    return _SearchPageState();
  }

  static _SearchPageState? of(BuildContext context) =>
      context.findAncestorStateOfType<_SearchPageState>();
}

class _SearchPageState extends BottomSheetPageState<SearchPage>
    with WidgetsBindingObserver {
  _SearchPageState() : super(hasAppBar: false);

  // The number of pixels to offset the FAB by animates out
  // via a fade down
  final double _resultsSheetCollapsedHeight = 124;
  final LatLng _defaultCameraPosition = const LatLng(1.3521, 103.8198);

  List<BusService> _busServices = <BusService>[];
  late List<BusService> _filteredBusServices;
  List<BusStop> _busStops = <BusStop>[];
  late List<BusStop> _filteredBusStops;
  JaroWinkler jw = JaroWinkler();

  String _queryString = '';
  String get _query => _queryString;
  set _query(String query) {
    _queryString = query;
    _textController.text = _queryString;
  }

  Map<BusStop, _QueryMetadata> _queryMetadata = <BusStop, _QueryMetadata>{};
  final Map<BusStop, double> _distanceMetadata = <BusStop, double>{};

  List<String> _searchHistory = <String>[];

  LocationData? location;
  bool _isDistanceLoaded = false;
  final bool _showServicesOnly = false;
  late bool _isMapVisible = widget.showMap;
  bool _isRefocusButtonVisible = true;
  BusStop? _focusedBusStop;
  LatLng? _focusedLocation;

  BusStop? get _displayedBusStop =>
      _focusedBusStop ?? _filteredBusStops.firstOrNull;

  LatLng get _markerOrigin =>
      _focusedLocation ??
      (location != null
          ? LatLng(location!.latitude!, location!.longitude!)
          : _defaultCameraPosition);

  late final AnimationController _clearIconAnimationController =
      AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  late final Animation<double> _clearIconAnimation = CurvedAnimation(
      parent: _clearIconAnimationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic);

  // Controlelrs
  final TextEditingController _textController = TextEditingController();
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
  late final AnimationController _mapClipperAnimationController =
      AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final RubberAnimationController _resultsSheetAnimationController =
      RubberAnimationController(
    vsync: this,
    // initialValue: widget.showMap
    //     ? AnimationControllerValue(pixel: _resultsSheetCollapsedHeight)
    //         .percentage
    //     : 1.0,
    lowerBoundValue: AnimationControllerValue(
        pixel: _resultsSheetCollapsedHeight, percentage: 0),
    upperBoundValue: AnimationControllerValue(percentage: 1.0),
    duration: const Duration(milliseconds: 300),
    springDescription: SpringDescription.withDampingRatio(
        mass: 1, ratio: DampingRatio.NO_BOUNCY, stiffness: Stiffness.LOW),
  );
  final ScrollController _scrollController = ScrollController();
  final Completer<GoogleMapController> _googleMapController =
      Completer<GoogleMapController>();

  late GoogleMap _googleMap;
  String? _googleMapDarkStyle;

  double get sheetLowerBound =>
      _resultsSheetAnimationController.lowerBoundValue.pixel! /
      MediaQuery.of(context).size.height;

  @override
  void initState() {
    super.initState();

    _resultsSheetAnimationController.value = widget.showMap
        ? _resultsSheetAnimationController.upperBound!
        : _resultsSheetAnimationController.upperBound!;

    if (widget.showMap) {
      WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
        _resultsSheetAnimationController.value = sheetLowerBound;
      });
    }

    _tabController.index = widget.showMap ? 1 : 0;
    _resultsSheetAnimationController.addListener(() {
      final visibilityBound = lerpDouble(
          _resultsSheetAnimationController.upperBound!, sheetLowerBound, 0.9)!;

      final shouldMapBeVisible =
          _resultsSheetAnimationController.value < visibilityBound;

      void updateMapVisibility() {
        if (_isMapVisible != shouldMapBeVisible) {
          setState(() {
            _isMapVisible = shouldMapBeVisible;
          });
        }
      }

      // Update map visibility wwhen bottom sheet has finish animating
      // or when it has been fully closed.
      if (_resultsSheetAnimationController.value >=
          _resultsSheetAnimationController.upperBound!) {
        updateMapVisibility();
      }

      late void Function(AnimationStatus) statusListener;
      statusListener = (AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          updateMapVisibility();
          _resultsSheetAnimationController.removeStatusListener(statusListener);
        }
      };

      _resultsSheetAnimationController.addStatusListener(statusListener);

      // Hide bottom sheet the moment we start to transition to the other layout
      const threshold = 0.05;

      if (_resultsSheetAnimationController.value > threshold &&
          _resultsSheetAnimationController.value < 1.0 - threshold) {
        hideBusStopDetailSheet();
      }
      // if (!_resultsSheetAnimationController.isAnimating) {
      // }
    });

    /* Retrieve user location then sort bus stops accordingly */
    location = LocationUtils.getLatestLocation();

    // Update distances to latest location
    if (location != null) {
      _updateBusStopDistances(location!);
      _isRefocusButtonVisible = false;
      if (!LocationUtils.isLocationCurrent()) {}
    }

    // Refresh location if necessary
    if (location == null || !LocationUtils.isLocationCurrent()) {
      LocationUtils.getLocation().then((LocationData? location) {
        setState(() {
          this.location = location;
        });
        if (location != null) {
          _updateBusStopDistances(location);
          setState(() {
            _isRefocusButtonVisible = false;
          });
        }
      });
    }

    _fetchBusStops();

    // If normal mode, perform bus service and map-related functions
    if (widget.isSimpleMode) return;

    _fetchBusServices();
    areBusServiceRoutesCached().then((bool stored) {
      if (!stored) BusAPI().fetchAndStoreBusServiceRoutes();
    });

    rootBundle
        .loadString('assets/maps/map_style_dark.json')
        .then((String style) {
      setState(() {
        _googleMapDarkStyle = style;
      });
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _textController.dispose();
    _clearIconAnimationController.dispose();
    _mapClipperAnimationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      if (location == null || !LocationUtils.isLocationCurrent()) {
        LocationUtils.getLocation().then((LocationData? location) {
          setState(() {
            this.location = location;
          });
          if (location != null) {
            _updateBusStopDistances(location);
          }
        });
      }
    }
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

      _resultsSheetAnimationController.launchTo(
        _resultsSheetAnimationController.value,
        _isMapVisible
            ? _resultsSheetAnimationController.lowerBound
            : _resultsSheetAnimationController.upperBound,
        velocity: SearchPage._launchVelocity,
      );
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleOf(context));
    if (_query.isEmpty) {
      _clearIconAnimationController.reverse();
    } else {
      _clearIconAnimationController.forward();
    }

    if (_isMapVisible) {
      _mapClipperAnimationController.forward();
    } else {
      _mapClipperAnimationController.reverse();
    }
    final bottomSheetContainer = bottomSheet(child: _buildBody());

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Material(child: bottomSheetContainer),
      ),
    );
  }

  Widget _buildSearchCard() {
    final searchField = TextField(
      autofocus: false,
      controller: _textController,
      onChanged: (String newText) {
        setState(() {
          _queryString = newText;
        });
        _scrollController.jumpTo(0);
      },
      onTap: () {
        hideBusStopDetailSheet();
        if (_isMapVisible) {
          setState(() {
            _isMapVisible = false;
          });
        }
      },
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.only(
            left: 16.0, top: 16.0, right: 16.0, bottom: 16.0),
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        enabledBorder: InputBorder.none,
        hintText: widget.isSimpleMode
            ? 'Search for stops'
            : 'Search for stops, services',
      ),
    );
    return Hero(
      tag: 'searchField',
      child: CardAppBar(
        elevation: 2.0,
        leading: IconButton(
          color: Theme.of(context).hintColor,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: searchField,
        bottom: TabBar(
          controller: _tabController,
          onTap: _onTabTap,
          tabs: [
            Tab(
              icon: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.list_rounded),
                  SizedBox(width: 8.0),
                  Text('List'),
                ],
              ),
            ),
            Tab(
              icon: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.map_rounded),
                  SizedBox(width: 8.0),
                  Text('Map'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ScaleTransition(
              scale: _clearIconAnimation,
              child: IconButton(
                color: Theme.of(context).hintColor,
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  setState(() {
                    _query = '';
                  });
                },
              )),
        ],
      ),
    );
  }

  // Returns a TickerFuture that resolves when the animation is complete
  TickerFuture _onTabTap(int index) {
    final shouldMapBeVisible = _tabController.index == 1;

    if (_isMapVisible == shouldMapBeVisible) {
      return TickerFuture.complete();
    }

    setState(() {
      _isMapVisible = shouldMapBeVisible;
    });

    if (index == 0) {
      return _resultsSheetAnimationController.launchTo(
        _resultsSheetAnimationController.value,
        _resultsSheetAnimationController.upperBound,
        velocity: SearchPage._launchVelocity,
      );
    } else {
      _hideKeyboard();
      _scrollController.jumpTo(0);
      // ignore: avoid_as
      (widget._resultsSheetKey.currentState as CustomRubberBottomSheetState)
          .setScrolling(false);

      return _resultsSheetAnimationController.fling(
        _resultsSheetAnimationController.value,
        _resultsSheetAnimationController.lowerBound,
        velocity: SearchPage._launchVelocity,
      );
    }
  }

  double get _resultsSheetExpandedPercentage {
    try {
      final expanded = _resultsSheetAnimationController.upperBound!;
      final dismissed = _resultsSheetAnimationController.lowerBound!;
      final animationRange = expanded - dismissed;
      final collapsedPercentage =
          ((_resultsSheetAnimationController.value - dismissed) /
                  animationRange)
              .clamp(0.0, 1.0)
              .toDouble();
      return collapsedPercentage;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildBody() {
    _generateQueryResults();
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: AnimatedBuilder(
            animation: _resultsSheetAnimationController,
            builder: (BuildContext context, Widget? child) {
              return ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: _resultsSheetExpandedPercentage,
                  child: Container(
                    padding: EdgeInsets.only(
                      top: kToolbarHeight * 2 +
                          MediaQuery.of(context).padding.top +
                          16.0,
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_query.isEmpty) _buildHistory(),
              if (!_showServicesOnly && _filteredBusServices.isNotEmpty)
                _buildBusServicesSliverHeader(),
              _buildBusServiceList(),
            ])),
      ),
      if (!_showServicesOnly) ...<Widget>{
        _buildBusStopsSliverHeader(),
        _buildBusStopList(),
      },
      if (_query.isNotEmpty &&
          _filteredBusStops.isEmpty &&
          _filteredBusServices.isEmpty)
        SliverToBoxAdapter(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            leading: SizedBox(
              width: 48.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HighlightedIcon(
                    child: const Icon(Icons.search_off_rounded),
                    iconColor: Theme.of(context).hintColor,
                  ),
                ],
              ),
            ),
            title: Text(
              'Nothing found for "$_query"',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.normal),
            ),
          ),
        ),
    ];

    final Widget body = Stack(
      children: [
        CustomRubberBottomSheet(
          key: widget._resultsSheetKey,
          animationController: _resultsSheetAnimationController,
          scrollController: _scrollController,
          lowerLayer: Stack(
            alignment: Alignment.topCenter,
            children: [
              Builder(builder: (context) {
                return _buildMapWidget(context);
              }),
              if (LocationUtils.isLocationAllowed())
                Positioned(
                  bottom: _resultsSheetCollapsedHeight + 16.0,
                  child: FloatingActionButton.extended(
                      label: const Text('Focus on my location'),
                      icon: const Icon(Icons.my_location_rounded),
                      onPressed: () async {
                        final controller = await _googleMapController.future;
                        final currentZoom = await controller.getZoomLevel();
                        controller.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: LatLng(
                                  location!.latitude!, location!.longitude!),
                              zoom: currentZoom,
                            ),
                          ),
                        );
                      }),
                ),
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight * 2,
                  left: 16.0,
                  right: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      curve: _query.isEmpty
                          ? const Interval(0.5, 1.0)
                          : const Interval(0.0, 0.5),
                      opacity: _query.isEmpty ? 0.0 : 1.0,
                      child: AnimatedSlide(
                        offset: _query.isEmpty
                            ? const Offset(0, -0.5)
                            : Offset.zero,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
                        child: Material(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          elevation: 2,
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(8.0)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 8.0, horizontal: 12.0),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    color: Theme.of(context).hintColor,
                                    size: 20.0),
                                const SizedBox(width: 8.0),
                                Text(
                                  'Showing only "$_query"',
                                  style: TextStyle(
                                      color: Theme.of(context).hintColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Opacity(
                        opacity: _isRefocusButtonVisible ? 1.0 : 0.0,
                        child: ElevatedButton(
                          onPressed: () async {
                            final controller =
                                await _googleMapController.future;
                            final visibleRegion =
                                await controller.getVisibleRegion();
                            final centerLatitude =
                                (visibleRegion.northeast.latitude +
                                        visibleRegion.southwest.latitude) /
                                    2;
                            final centerLongitude =
                                (visibleRegion.northeast.longitude +
                                        visibleRegion.southwest.longitude) /
                                    2;
                            setState(() {
                              _focusedLocation =
                                  LatLng(centerLatitude, centerLongitude);
                            });
                          },
                          child: Text(
                              'Search this area for ${_query.isEmpty ? 'stops' : '"$_query"'}',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.secondary)),
                          style: ElevatedButton.styleFrom(
                            primary: Theme.of(context).cardColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          upperLayer: Material(
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
            elevation: 4.0,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (notification is ScrollStartNotification &&
                    notification.dragDetails != null) {
                  _hideKeyboard();
                  return true;
                }
                return false;
              },
              child: CustomScrollView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _scrollController,
                slivers: slivers,
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Column(
            children: [
              AppBar(
                surfaceTintColor: Colors.transparent,
                scrolledUnderElevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarBrightness: Theme.of(context).brightness,
                ),
                backgroundColor: Colors.transparent,
                leading: null,
                automaticallyImplyLeading: false,
                titleSpacing: 16.0,
                elevation: 0.0,
                title: _buildSearchCard(),
                toolbarHeight: kToolbarHeight * 2,
              ),
            ],
          ),
        ),
      ],
    );

    return body;
  }

  Widget _buildMapWidget(BuildContext context) {
    /* Initialize google map */
    final initialCameraPosition = _getCameraPositionFromLocation();

    _googleMap = GoogleMap(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 128,
        bottom: _resultsSheetCollapsedHeight,
      ),
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      mapToolbarEnabled: true,
      compassEnabled: true,
      zoomControlsEnabled: false,
      myLocationEnabled: _isMapVisible,
      myLocationButtonEnabled: false,
      mapType: MapType.normal,
      initialCameraPosition: initialCameraPosition,
      onMapCreated: (GoogleMapController controller) {
        if (!_googleMapController.isCompleted) {
          _googleMapController.complete(controller);
        }
        if (_isDistanceLoaded) {
          controller.moveCamera(
              CameraUpdate.newCameraPosition(_getCameraPositionFromLocation()));
        }
        if (Theme.of(context).brightness == Brightness.dark &&
            _googleMapDarkStyle != null) {
          controller.setMapStyle(_googleMapDarkStyle);
        }
      },
      onCameraMove: (CameraPosition position) {
        // If the distance to _focusedLocation is greater than the threshold,
        // make the re-focus button visible.
        final distanceMeters = const latlong.Distance().as(
            latlong.LengthUnit.Meter,
            latlong.LatLng(_markerOrigin.latitude, _markerOrigin.longitude),
            latlong.LatLng(
                position.target.latitude, position.target.longitude));
        final shouldShowRefocusButton =
            distanceMeters > SearchPage._furthestBusStopDistanceMeters;
        if (shouldShowRefocusButton != _isRefocusButtonVisible) {
          setState(() {
            _isRefocusButtonVisible = shouldShowRefocusButton;
          });
        }
      },
      onTap: (_) {
        setState(() {
          _focusedBusStop = null;
        });
      },
      markers: _buildMapMarkersAround(_markerOrigin, context),
    );

    return _googleMap;
  }

  CameraPosition _getCameraPositionFromLocation() {
    return CameraPosition(
      target: location != null
          ? LatLng(location!.latitude!, location!.longitude!)
          : _defaultCameraPosition,
      zoom: 18,
    );
  }

  Set<Marker> _buildMapMarkersAround(LatLng? position, BuildContext context) {
    final markers = <Marker>{};

    if (position == null) {
      return markers;
    }

    for (var busStop in _filteredBusStops) {
      if (busStop.getMetersFromLocation(position) >
          SearchPage._furthestBusStopDistanceMeters) continue;
      markers.add(Marker(
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        markerId: MarkerId(busStop.code),
        position: LatLng(busStop.latitude, busStop.longitude),
        infoWindow:
            InfoWindow(title: busStop.displayName, snippet: busStop.road),
        onTap: () {
          if (_focusedBusStop == busStop || super.isBusDetailSheetVisible()) {
            showBusStopDetailSheet(busStop, context);
          } else {
            focusBusStopOnMap(busStop);
          }
        },
      ));
    }

    return markers;
  }

  void focusBusStopOnMap(BusStop busStop) {
    setState(() {
      _focusedBusStop = busStop;
      _focusedLocation = LatLng(busStop.latitude, busStop.longitude);
    });
  }

  void _generateQueryResults() {
    if (_query.isEmpty && !_showServicesOnly) {
      _filteredBusServices = <BusService>[];
    } else {
      _filteredBusServices =
          _filterBusServices(_busServices, _query).toList(growable: false);
      _filteredBusServices.sort(
          (BusService a, BusService b) => compareBusNumber(a.number, b.number));
    }

    final maxDistance = _distanceMetadata.isNotEmpty
        ? _distanceMetadata.values.toList().reduce(max)
        : 0;

    if (_query.isNotEmpty) {
      final isQueryAllNumbers = num.tryParse(_queryString) != null;
      double distanceFunction(BusStop busStop) {
        final busStopName = busStop.displayName.toLowerCase();
        final queryLengthBusStopName = busStopName.length > _query.length
            ? busStopName.substring(0, _query.length)
            : busStopName;
        final busStopNameParts = busStopName.split(RegExp(r'( |/)'));
        var minTokenDifference = double.maxFinite;

        for (var part in busStopNameParts) {
          if (part.isEmpty) continue;
          if (_query.length < part.length) {
            part = part.substring(0, _query.length);
          }
          minTokenDifference = min(minTokenDifference,
              jw.normalizedDistance(part, _query.toLowerCase()));
        }

        var distance = jw.normalizedDistance(
                queryLengthBusStopName, _query.toLowerCase()) -
            0.01;

        if (minTokenDifference < distance) {
          distance =
              minTokenDifference - 0.01 * (_query.length / busStopName.length);
        }

        if (isQueryAllNumbers) {
          final codeDistance =
              busStop.code.startsWith(_queryString) ? -1.0 : 1.0;
          distance = min(distance, codeDistance);
        }

        // Add a small bit of distance to sort secondly by distance
        if (_distanceMetadata.isNotEmpty) {
          distance += 0.0001 * (_distanceMetadata[busStop] ?? 0) / maxDistance;
        }

        return distance;
      }

      final busStopsWithDistance = _busStops
          .map((BusStop busStop) =>
              BusStopWithDistance(busStop, distanceFunction(busStop)))
          .where((BusStopWithDistance busStop) =>
              busStop.distance < SearchPage._searchDifferenceThreshold)
          .toList();
      busStopsWithDistance.sort(
          (BusStopWithDistance b1, BusStopWithDistance b2) =>
              b1.distance.compareTo(b2.distance));
      _filteredBusStops = busStopsWithDistance
          .map((BusStopWithDistance b) => b.busStop)
          .toList();
    } else {
      _filteredBusStops = _busStops;
    }
    _queryMetadata = <BusStop, _QueryMetadata>{
      for (BusStop busStop in _filteredBusStops)
        busStop: _calculateQueryMetadata(busStop, _query)
    };

    if (_focusedBusStop != null) {
      if (!_filteredBusStops.contains(_focusedBusStop)) {
        _focusedBusStop = null;
      }
    }

    if (location != null && !_isDistanceLoaded) {
      _updateBusStopDistances(location!);
    }
  }

  Widget _buildHistory() {
    return FutureBuilder<List<String>>(
        future: getHistory(),
        initialData: _searchHistory,
        builder: (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
          if (snapshot.data?.isEmpty ?? true) {
            return Container();
          }
          _searchHistory = snapshot.data!;
          return InkWell(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (BuildContext context, int position) {
                position = _searchHistory.length - 1 - position;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
                  leading: Container(
                    width: 32.0,
                    alignment: Alignment.center,
                    child: Icon(Icons.history_rounded,
                        color: Theme.of(context).hintColor),
                  ),
                  title: Text(_searchHistory[position],
                      style: Theme.of(context).textTheme.titleMedium),
                  onTap: () => setState(() {
                    _query = _searchHistory[position];
                    _textController.text = _query;
                    _textController.selection = TextSelection(
                        baseOffset: _query.length, extentOffset: _query.length);
                  }),
                );
              },
              itemCount: snapshot.data != null ? _searchHistory.length : 0,
            ),
          );
        });
  }

  Widget _buildBusServicesSliverHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, left: 80.0, bottom: 8.0),
      child: Text(
        'Services',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: BusService.listColor(context),
            ),
      ),
    );
  }

  Widget _buildBusStopsSliverHeader() {
    final dateFormat = MediaQuery.of(context).alwaysUse24HourFormat
        ? DateFormat('HH:mm')
        : DateFormat('hh:mm a');
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _resultsSheetAnimationController,
        builder: (BuildContext context, Widget? child) {
          return _buildVerticalSwitcher(
            expandedChild: ClipRect(
              child: Align(
                alignment: Alignment.bottomLeft,
                heightFactor:
                    (_filteredBusServices.isNotEmpty || _query.isEmpty) ? 1 : 0,
                child: Padding(
                  padding: EdgeInsets.only(
                      top: 24.0,
                      left: 80.0,
                      bottom: _resultsSheetExpandedPercentage * 8.0),
                  child: RichText(
                      text: TextSpan(children: <InlineSpan>[
                    TextSpan(
                        text: 'Bus stops',
                        style: Theme.of(context).textTheme.headlineMedium),
                    if (LocationUtils.currentLocationTimestamp != null)
                      TextSpan(
                        text:
                            ' • as of ${dateFormat.format(LocationUtils.currentLocationTimestamp!)}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: Theme.of(context).hintColor,
                            ),
                      ),
                  ])),
                ),
              ),
            ),
            collapsedChild: Align(
              alignment: Alignment.bottomLeft,
              heightFactor: (_filteredBusServices.isNotEmpty || _query.isEmpty)
                  ? 1
                  : 1 - _resultsSheetExpandedPercentage,
              child: Padding(
                padding: EdgeInsets.only(
                    top: 24.0,
                    left: 80.0,
                    bottom: _resultsSheetExpandedPercentage * 8.0),
                child: Text(
                    _focusedBusStop != null
                        ? 'Selected stop'
                        : (_query.isEmpty
                            ? 'Nearest stop'
                            : 'Nearest matching stop'),
                    style: Theme.of(context).textTheme.headlineMedium),
              ),
            ),
            expandedPercentage: _resultsSheetExpandedPercentage,
          );
        },
      ),
    );
  }

  static Widget _buildVerticalSwitcher(
      {Widget? expandedChild,
      Widget? collapsedChild,
      required double expandedPercentage,
      bool offset = true}) {
    return Stack(
      children: [
        Transform.translate(
          offset: Offset(
              0,
              8.0 *
                  (1 - const Interval(0.33, 1).transform(expandedPercentage)) *
                  (offset ? 1 : 0)),
          child: Opacity(
            opacity: const Interval(0.33, 1).transform(expandedPercentage),
            child: IgnorePointer(
              ignoring: expandedPercentage < 0.5,
              child: expandedChild,
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(
              0,
              -8.0 *
                  const Interval(0, 0.66).transform(expandedPercentage) *
                  (offset ? 1 : 0)),
          child: Opacity(
            opacity: 1 - const Interval(0, 0.66).transform(expandedPercentage),
            child: IgnorePointer(
              ignoring: expandedPercentage >= 0.5,
              child: collapsedChild,
            ),
          ),
        )
      ],
    );
  }

  Widget _buildBusServiceList() {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (BuildContext context, int position) {
          final busService = _filteredBusServices[position];
          return BusServiceSearchItem(
            onTap: () => _pushBusServiceRoute(busService),
            busService: busService,
          );
        },
        itemCount: _showServicesOnly
            ? _filteredBusServices.length
            : min(_filteredBusServices.length, 3),
      ),
    );
  }

  Widget _buildBusStopSearchItem(BusStop busStop, BuildContext context,
      {bool isFocusedBusStopItem = false}) {
    final metadata = _queryMetadata[busStop]!;

    final distance = _distanceMetadata.containsKey(busStop)
        ? getDistanceVerboseFromMeters(_distanceMetadata[busStop]!)
        : '';

    final name = busStop.displayName;
    final busStopCode = busStop.code;

    final nameStart = name.substring(0, metadata.descriptionStart);
    final nameBold =
        name.substring(metadata.descriptionStart, metadata.descriptionEnd);
    final nameEnd = name.substring(metadata.descriptionEnd, name.length);

    final busStopCodeStart =
        busStopCode.substring(0, metadata.busStopCodeStart);
    final busStopCodeBold = busStopCode.substring(
        metadata.busStopCodeStart, metadata.busStopCodeEnd);
    final busStopCodeEnd =
        busStopCode.substring(metadata.busStopCodeEnd, busStopCode.length);
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
      isMapEnabled: isFocusedBusStopItem,
      onShowOnMapTap: () {
        void focusOnBusStop() async {
          final controller = await _googleMapController.future;
          controller
              .animateCamera(CameraUpdate.newLatLng(
                  LatLng(busStop.latitude, busStop.longitude)))
              .whenComplete(() =>
                  controller.showMarkerInfoWindow(MarkerId(busStop.code)));
          setState(() {
            _focusedBusStop = busStop;
            _focusedLocation = LatLng(busStop.latitude, busStop.longitude);
          });
        }

        // Animate to map view first, then animate to bus stop
        _tabController.animateTo(1);
        final animation = _onTabTap(1);
        animation.whenCompleteOrCancel(focusOnBusStop);
      },
      busStop: busStop,
      onTap: () => _onBusStopSearchItemTapped(busStop, context),
    );
  }

  Widget _buildBusStopList() {
    return SliverList(
        delegate: SliverChildBuilderDelegate(
      (BuildContext context, int position) {
        final busStop = _filteredBusStops[position];

        final item = _buildBusStopSearchItem(busStop, context);
        return position == 0 ? _buildClosestBusStopItem(context) : item;
      },
      childCount: _showServicesOnly ? 0 : _filteredBusStops.length,
    ));
  }

  Widget _buildClosestBusStopItem(BuildContext context) {
    return AnimatedBuilder(
      animation: _resultsSheetAnimationController,
      builder: (BuildContext context, Widget? child) {
        return _buildVerticalSwitcher(
          expandedChild: child,
          collapsedChild: _buildBusStopSearchItem(
            _displayedBusStop!,
            context,
            isFocusedBusStopItem: true,
          ),
          expandedPercentage: _resultsSheetExpandedPercentage,
          offset: false,
        );
      },
      child: _buildBusStopSearchItem(
        _filteredBusStops[0],
        context,
        isFocusedBusStopItem: false,
      ),
    );
  }

  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _onBusStopSearchItemTapped(BusStop busStop, BuildContext context) {
    if (widget.isSimpleMode) {
      // Return result
      Navigator.pop(context, busStop);
    } else {
      // Show bus detail sheet
      FocusScope.of(context).unfocus();
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        showBusStopDetailSheet(busStop, context);
      });
    }
  }

  // @override
  Future<void> showBusStopDetailSheet(
      BusStop busStop, BuildContext context) async {
    context
        .read<BusStopSheetBloc>()
        .add(SheetRequested(busStop, kDefaultRouteId));
    pushHistory(_query.trim());
  }

  Future<void> _updateBusStopDistances(LocationData location) async {
    for (var busStop in _busStops) {
      final distanceMeters = const latlong.Distance().as(
          latlong.LengthUnit.Meter,
          latlong.LatLng(location.latitude!, location.longitude!),
          latlong.LatLng(busStop.latitude, busStop.longitude));
      _distanceMetadata[busStop] = distanceMeters;
    }

    /* Sort stops by distance */
    _busStops.sort((BusStop a, BusStop b) {
      final distanceA = _distanceMetadata[a];
      final distanceB = _distanceMetadata[b];
      if (distanceA == null || distanceB == null) {
        return 0;
      }
      return (distanceA - distanceB).floor();
    });

    _isDistanceLoaded = true;
  }

  Future<void> _fetchBusStops() async {
    final busStops = await BusAPI().fetchBusStops();

    if (mounted) {
      setState(() {
        _busStops = List<BusStop>.from(busStops);
      });
    }
    if (location != null) {
      _updateBusStopDistances(location!);
    }
  }

  Future<void> _fetchBusServices() async {
    final busServices = await BusAPI().fetchBusServices();
    if (mounted) {
      setState(() {
        _busServices = busServices;
      });
    }
  }

  static Iterable<BusService> _filterBusServices(
          List<BusService> list, String query) =>
      list.where((BusService busService) =>
          busService.number.toLowerCase().startsWith(query.toLowerCase()));

  static _QueryMetadata _calculateQueryMetadata(BusStop busStop, String query) {
    final queryLowercase = query.toLowerCase();
    final busStopCodeLowercase = busStop.code.toLowerCase();
    final busStopDisplayNameLowercase = busStop.displayName.toLowerCase();
//    final String busStopDefaultNameLowercase = busStop.defaultName.toLowerCase();
    // TODO(jeffsieu): Enable search by default name as well.

    var index = busStopCodeLowercase.indexOf(queryLowercase);

    late int busStopCodeStart;
    late int busStopCodeEnd;

    if (index != -1) {
      busStopCodeStart = index;
      busStopCodeEnd = index + query.length;
    } else {
      busStopCodeStart = 0;
      busStopCodeEnd = 0;
    }

    index = busStopDisplayNameLowercase.indexOf(queryLowercase);

    late int descriptionStart;
    late int descriptionEnd;

    if (index != -1) {
      descriptionStart = index;
      descriptionEnd = index + query.length;
    } else {
      descriptionStart = 0;
      descriptionEnd = 0;
    }

    return _QueryMetadata(
      busStopCodeStart: busStopCodeStart,
      busStopCodeEnd: busStopCodeEnd,
      descriptionStart: descriptionStart,
      descriptionEnd: descriptionEnd,
    );
  }

  void _pushBusServiceRoute(BusService busService) {
    final Widget page = BusServicePage(busService.number);
    final Route<void> route =
        MaterialPageRoute<void>(builder: (BuildContext context) => page);
    pushHistory(_query); // add query to history
    Navigator.push(context, route);
  }
}

class _QueryMetadata {
  final int busStopCodeStart;
  final int busStopCodeEnd;
  final int descriptionStart;
  final int descriptionEnd;

  _QueryMetadata({
    required this.busStopCodeStart,
    required this.busStopCodeEnd,
    required this.descriptionStart,
    required this.descriptionEnd,
  });
}

extension BusStopDistance on BusStop {
  double getMetersFromLocation(LatLng coordinates) {
    return const latlong.Distance().as(
        latlong.LengthUnit.Meter,
        latlong.LatLng(latitude, longitude),
        latlong.LatLng(coordinates.latitude, coordinates.longitude));
  }

  double getMetersFromBusStop(BusStop busStop) {
    return const latlong.Distance().as(
        latlong.LengthUnit.Meter,
        latlong.LatLng(latitude, longitude),
        latlong.LatLng(busStop.latitude, busStop.longitude));
  }
}
