import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:edit_distance/edit_distance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart' as provider;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rubber/rubber.dart';
import 'package:shimmer/shimmer.dart';
import 'package:stops_sg/bus_api/models/bus_service.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/location/location.dart';
import 'package:stops_sg/main.dart';
import 'package:stops_sg/pages/search_page/bus_service_filter_sheet.dart';
import 'package:stops_sg/pages/search_page/search_page_map.dart';
import 'package:stops_sg/routes/bus_service_detail_route.dart';
import 'package:stops_sg/routes/routes.dart';
import 'package:stops_sg/utils/bus_stop_distance_utils.dart';
import 'package:stops_sg/utils/bus_utils.dart';
import 'package:stops_sg/widgets/bus_service_search_item.dart';
import 'package:stops_sg/widgets/bus_stop_item.dart';
import 'package:stops_sg/widgets/bus_stop_search_item.dart';
import 'package:stops_sg/widgets/card_app_bar.dart';
import 'package:stops_sg/widgets/edit_model.dart';
import 'package:stops_sg/widgets/highlighted_icon.dart';

part 'search_page.g.dart';

const kRandomSeed = 0x12345678;

@riverpod
Future<List<BusStop>> busStopsByDistance(Ref ref) async {
  final busStops = await ref.watch(busStopListProvider.future);
  final location = await ref.watch(userLocationProvider.future);
  final locationData = location.data;

  if (locationData == null) {
    return busStops;
  }

  final distanceMetadata = <BusStop, double>{};

  for (var busStop in busStops) {
    final distanceMeters =
        busStop.getMetersFromLocation(locationData.toLatLng()!);
    distanceMetadata[busStop] = distanceMeters;
  }

  /* Sort stops by distance */
  return busStops.sorted((BusStop a, BusStop b) {
    final distanceA = distanceMetadata[a];
    final distanceB = distanceMetadata[b];
    if (distanceA == null || distanceB == null) {
      return 0;
    }
    return (distanceA - distanceB).floor();
  });
}

enum BusStopSearchFilter { all, withService }

@riverpod
Future<List<BusStop>> busStopsInServices(
    Ref ref, List<BusService> busServices) async {
  final allBusServiceRoutes = await Future.wait(
    busServices.map((busService) async {
      final service = await ref
          .watch(cachedBusServiceWithRoutesProvider(busService.number).future);
      return service.routes;
    }),
  );

  final allBusServiceStops = allBusServiceRoutes
      .expand((routes) {
        return routes.expand((route) => route.busStops);
      })
      .map(
        (busStopWithDistance) => busStopWithDistance.busStop,
      )
      .toSet()
      .toList();

  return allBusServiceStops;
}

class SearchPage extends StatefulHookConsumerWidget {
  const SearchPage({super.key, this.showMap = false}) : isSimpleMode = false;
  const SearchPage.onlyBusStops({super.key})
      : showMap = false,
        isSimpleMode = true;

  static const double _searchDifferenceThreshold = 0.2;
  static const double _launchVelocity = 0.5;

  final bool showMap;
  final bool isSimpleMode;

  @override
  ConsumerState<SearchPage> createState() {
    return SearchPageState();
  }

  static SearchPageState? of(BuildContext context) =>
      context.findAncestorStateOfType<SearchPageState>();
}

class SearchPageState extends ConsumerState<SearchPage>
    with TickerProviderStateMixin {
  // The number of pixels to offset the FAB by animates out
  // via a fade down
  static const _resultsSheetCollapsedHeight = 124.0;

  List<BusStop>? get _busStops => ref.watch(busStopsByDistanceProvider).value;
  List<BusService> get _busServices =>
      ref.watch(busServiceListProvider).value ?? [];
  bool get areBusStopsLoading =>
      ref.watch(busStopsByDistanceProvider).isLoading ||
      ref.watch(busStopsByDistanceProvider).isRefreshing ||
      ref.watch(busStopsByDistanceProvider).isReloading;
  late List<BusService> _filteredBusServices;
  late List<BusStop>? _filteredBusStops;
  BusStopSearchFilter _searchFilter = BusStopSearchFilter.all;
  List<BusService> _busStopServicesFilter = [];

  static JaroWinkler jw = JaroWinkler();

  String _queryString = '';
  String get _query => _queryString;
  set _query(String query) {
    _queryString = query;
    _textController.text = _queryString;
  }

  List<String> _searchHistory = <String>[];

  UserLocationSnapshot get userLocation =>
      ref.watch(userLocationProvider).value ??
      UserLocationSnapshot.noService(timestamp: DateTime.now());
  final bool _showServicesOnly = false;
  late bool _isMapVisible = widget.showMap;

  BusStop? __focusedBusStop;

  BusStop? get _focusedBusStop {
    return __focusedBusStop;
  }

  set _focusedBusStop(BusStop? busStop) {
    __focusedBusStop = busStop;
    _isFocusedBusStopExpanded = true;
  }

  bool _isFocusedBusStopExpanded = true;
  bool _isNearestBusStopExpanded = false;

  BusStop? get _displayedBusStop =>
      _focusedBusStop ?? _filteredBusStops?.firstOrNull;

  // Controllers
  final TextEditingController _textController = TextEditingController();
  late final TabController _tabController =
      TabController(length: 2, vsync: this);
  late final RubberAnimationController _resultsSheetAnimationController;
  final ScrollController _scrollController = ScrollController();
  final Completer<GoogleMapController> _googleMapController =
      Completer<GoogleMapController>();

  double get sheetLowerBound =>
      _resultsSheetAnimationController.lowerBoundValue.pixel! /
      MediaQuery.of(context).size.height;

  @override
  void initState() {
    super.initState();

    const upperBoundPercentage = 1.0;
    const lowerBoundPixels = _resultsSheetCollapsedHeight;

    _resultsSheetAnimationController = RubberAnimationController(
      vsync: this,
      initialValue: upperBoundPercentage,
      lowerBoundValue:
          AnimationControllerValue(pixel: lowerBoundPixels, percentage: 0),
      upperBoundValue:
          AnimationControllerValue(percentage: upperBoundPercentage),
      duration: const Duration(milliseconds: 300),
      springDescription: SpringDescription.withDampingRatio(
          mass: 1, ratio: DampingRatio.NO_BOUNCY, stiffness: Stiffness.LOW),
    );

    if (widget.showMap) {
      WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
        _resultsSheetAnimationController.value = sheetLowerBound;
      });
    }

    _tabController.index = widget.showMap ? 1 : 0;
    _resultsSheetAnimationController.addListener(() {
      final visibilityBound = lerpDouble(
          _resultsSheetAnimationController.upperBound!, sheetLowerBound, 0.5)!;

      final shouldMapBeVisible =
          _resultsSheetAnimationController.value < visibilityBound;

      void updateMapVisibility() {
        if (_isMapVisible != shouldMapBeVisible) {
          setState(() {
            _isMapVisible = shouldMapBeVisible;
            _tabController.animateTo(shouldMapBeVisible ? 1 : 0);
          });
        }
      }

      updateMapVisibility();

      void statusListener(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          updateMapVisibility();
        }
      }

      _resultsSheetAnimationController.addStatusListener(statusListener);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _resultsSheetAnimationController.dispose();

    super.dispose();
  }

  bool get _canPop {
    if (_query.isNotEmpty) {
      return false;
    }

    if (widget.showMap != _isMapVisible) {
      return false;
    }

    return true;
  }

  void _onPopInvokedWithResult<T>(bool didPop, T? result) {
    if (didPop) {
      return;
    }

    // Clear query if not empty
    if (_query.isNotEmpty) {
      setState(() {
        _query = '';
      });
      return;
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
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleOf(context));

    final homeRoute =
        ref.watch(savedUserRouteProvider(id: kDefaultRouteId)).value;

    useEffect(() {
      _filteredBusServices =
          _getFilteredBusServices(_busServices, _query, _showServicesOnly);
      return null;
    }, [_busServices, _query, _showServicesOnly]);

    useEffect(() {
      if (_busStops == null) {
        _filteredBusStops = null;
      } else {
        _filteredBusStops = _getFilteredBusStops(_busStops!, _query);
      }

      return null;
    }, [_busStops, _query]);

    useEffect(() {
      if (_focusedBusStop != null && _filteredBusStops != null) {
        if (!_filteredBusStops!.contains(_focusedBusStop)) {
          _focusedBusStop = null;
        }
      }
      return null;
    }, [_filteredBusStops]);

    final queryMetadata = useQueryMetadata();

    return provider.MultiProvider(
      providers: [
        provider.Provider(
          create: (_) => const EditModel(isEditing: false),
        ),
        provider.Provider<StoredUserRoute?>(
          create: (_) => homeRoute,
        ),
      ],
      child: PopScope(
        canPop: _canPop,
        onPopInvokedWithResult: _onPopInvokedWithResult,
        child: _buildBody(queryMetadata),
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
        leading: widget.isSimpleMode
            ? IconButton(
                color: Theme.of(context).hintColor,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  Navigator.pop(context);
                },
              )
            : null,
        title: searchField,
        bottom: TabBar(
          controller: _tabController,
          onTap: _onTabTap,
          tabs: const [
            Tab(
              icon: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_rounded),
                  SizedBox(width: 8.0),
                  Text('List'),
                ],
              ),
            ),
            Tab(
              icon: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_rounded),
                  SizedBox(width: 8.0),
                  Text('Map'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          AnimatedScale(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            scale: _query.isEmpty ? 0.0 : 1.0,
            child: IconButton(
              color: Theme.of(context).hintColor,
              icon: const Icon(Icons.clear_rounded),
              onPressed: () {
                setState(() {
                  _query = '';
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  TickerFuture _collapseSheet() {
    return _resultsSheetAnimationController.fling(
      _resultsSheetAnimationController.value,
      _resultsSheetAnimationController.lowerBound,
      velocity: SearchPage._launchVelocity,
    );
  }

  TickerFuture _expandSheet() {
    return _resultsSheetAnimationController.launchTo(
      _resultsSheetAnimationController.value,
      _resultsSheetAnimationController.upperBound,
      velocity: SearchPage._launchVelocity,
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
      return _expandSheet();
    } else {
      _hideKeyboard();
      _scrollController.jumpTo(0);

      return _collapseSheet();
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

  Widget _buildBody(Map<BusStop, _QueryMetadata> queryMetadata) {
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
                    child: Opacity(
                      opacity: (const Interval(0.33, 1)
                          .transform(_resultsSheetExpandedPercentage)),
                      child: child,
                    ),
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
        if (_focusedBusStop != null) ...{
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                  start: 16.0, end: 16.0, top: 16.0),
              child: Text('Selected stop',
                  style: Theme.of(context).textTheme.headlineMedium),
            ),
          ),
          SliverToBoxAdapter(
            child: AnimatedBuilder(
              animation: _resultsSheetAnimationController,
              builder: (BuildContext context, Widget? child) {
                return Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: _resultsSheetExpandedPercentage,
                  child: child,
                );
              },
              child: const SizedBox(height: 8.0),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: BusStopItem(
                _focusedBusStop!,
                defaultExpanded:
                    _isMapVisible ? false : _isFocusedBusStopExpanded,
                onTap: () {
                  if (_isMapVisible) {
                    _expandSheet();
                    setState(() {
                      _isFocusedBusStopExpanded = true;
                    });
                  } else {
                    setState(() {
                      _isFocusedBusStopExpanded = !_isFocusedBusStopExpanded;
                    });
                  }
                },
              ),
            ),
          ),
        },
        _buildBusStopsSliverHeader(),
        _buildBusStopList(queryMetadata),
      },
      if (_query.isNotEmpty &&
          ((_filteredBusStops ?? []).isEmpty) &&
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
                    iconColor: Theme.of(context).hintColor,
                    child: const Icon(Icons.search_off_rounded),
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
        RubberBottomSheet(
          animationController: _resultsSheetAnimationController,
          scrollController: _scrollController,
          lowerLayer: SearchPageMap(
            busStops: _filteredBusStops ?? [],
            paddingTop: MediaQuery.of(context).padding.top + 128,
            paddingBottom: _resultsSheetCollapsedHeight,
            isVisible: _isMapVisible,
            query: _query,
            focusedBusStop: _focusedBusStop,
            onFocusedBusStopChanged: (BusStop? busStop) {
              setState(() {
                _focusedBusStop = busStop;
              });
            },
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

  static List<BusService> _getFilteredBusServices(
      List<BusService> services, String query, bool showServicesOnly) {
    if (query.isEmpty && !showServicesOnly) {
      return [];
    }

    return filterBusServices(services, query)
        .sorted((BusService a, BusService b) =>
            compareBusNumber(a.number, b.number))
        .toList(growable: false);
  }

  static List<BusStop> _getFilteredBusStops(
      List<BusStop> busStops, String query) {
    if (query.isEmpty) {
      return busStops;
    }

    final isQueryAllNumbers = num.tryParse(query) != null;
    double distanceFunction(BusStop busStop) {
      final busStopName = busStop.displayName.toLowerCase();
      final queryLengthBusStopName = busStopName.length > query.length
          ? busStopName.substring(0, query.length)
          : busStopName;
      final busStopNameParts = busStopName.split(RegExp(r'( |/)'));
      var minTokenDifference = double.maxFinite;

      for (var part in busStopNameParts) {
        if (part.isEmpty) continue;
        if (query.length < part.length) {
          part = part.substring(0, query.length);
        }
        minTokenDifference = min(minTokenDifference,
            jw.normalizedDistance(part, query.toLowerCase()));
      }

      var distance =
          jw.normalizedDistance(queryLengthBusStopName, query.toLowerCase()) -
              0.01;

      if (minTokenDifference < distance) {
        distance =
            minTokenDifference - 0.01 * (query.length / busStopName.length);
      }

      if (isQueryAllNumbers) {
        final codeDistance = busStop.code.startsWith(query) ? -1.0 : 1.0;
        distance = min(distance, codeDistance);
      }

      return distance;
    }

    final busStopsWithDistance = busStops
        .map((BusStop busStop) =>
            ((busStop: busStop, distance: distanceFunction(busStop))))
        .where((busStop) =>
            busStop.distance < SearchPage._searchDifferenceThreshold)
        .toList();
    mergeSort(busStopsWithDistance,
        compare: (b1, b2) => b1.distance.compareTo(b2.distance));
    return busStopsWithDistance.map((b) => b.busStop).toList();
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
      padding:
          const EdgeInsetsDirectional.only(top: 24.0, start: 16.0, bottom: 8.0),
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
                  padding: EdgeInsetsDirectional.only(
                      top: _resultsSheetExpandedPercentage * 24.0,
                      start: 16.0,
                      bottom: _resultsSheetExpandedPercentage * 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          RichText(
                              text: TextSpan(children: <InlineSpan>[
                            TextSpan(
                                text: 'Bus stops',
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            if (userLocation.data != null)
                              TextSpan(
                                text:
                                    ' • as of ${dateFormat.format(userLocation.timestamp)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Theme.of(context).hintColor,
                                    ),
                              ),
                          ])),
                          Align(
                            alignment: AlignmentDirectional.center,
                            heightFactor: _resultsSheetExpandedPercentage,
                            child: IconButton(
                                onPressed: () {
                                  ref.invalidate(userLocationProvider);
                                  ref.invalidate(busStopsByDistanceProvider);
                                },
                                icon: Icon(Icons.refresh)),
                          ),
                        ],
                      ),
                      Align(
                        alignment: AlignmentDirectional.bottomStart,
                        heightFactor: _resultsSheetExpandedPercentage,
                        child: FractionalTranslation(
                          translation:
                              Offset(0, (1 - _resultsSheetExpandedPercentage)),
                          child: Wrap(
                            spacing: 8.0,
                            children: [
                              ChoiceChip(
                                label: const Text('All'),
                                selected:
                                    _searchFilter == BusStopSearchFilter.all,
                                onSelected: (value) {
                                  setState(() {
                                    _searchFilter = BusStopSearchFilter.all;
                                  });
                                },
                              ),
                              ChoiceChip(
                                label: Text(_busStopServicesFilter.isEmpty
                                    ? 'With bus services...'
                                    : 'With ${_busStopServicesFilter.map((e) => e.number).join(', ')}'),
                                selected: _searchFilter ==
                                    BusStopSearchFilter.withService,
                                onSelected: (value) async {
                                  final selectedBusServices =
                                      await _showBusServiceFilterBottomSheet();

                                  if (selectedBusServices == null ||
                                      selectedBusServices.isEmpty) {
                                    return;
                                  }

                                  setState(() {
                                    _searchFilter =
                                        BusStopSearchFilter.withService;
                                    _busStopServicesFilter =
                                        selectedBusServices;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            collapsedChild: Align(
              alignment: Alignment.bottomLeft,
              heightFactor: (_filteredBusServices.isNotEmpty || _query.isEmpty)
                  ? 1
                  : 1 - _resultsSheetExpandedPercentage,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                    top: 16.0,
                    start: 16.0,
                    bottom: _resultsSheetExpandedPercentage * 8.0),
                child: Text(
                    _focusedBusStop != null
                        ? ''
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

  Future<List<BusService>?> _showBusServiceFilterBottomSheet() async {
    return await showModalBottomSheet<List<BusService>>(
      useSafeArea: true,
      useRootNavigator: true,
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return const BusServiceFilterSheet();
      },
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            for (var i = 0; i < 3; i++) ...{
              if (i < _filteredBusServices.length) ...{
                Expanded(
                  child: AnimatedBuilder(
                    animation: _resultsSheetAnimationController,
                    builder: (context, animation) => BusServiceSearchItem(
                      onTap: () =>
                          _pushBusServiceRoute(_filteredBusServices[i]),
                      busService: _filteredBusServices[i],
                      // TODO: Workaround because Ink does not work with opacity
                      opacity: (const Interval(0.33, 1)
                          .transform(_resultsSheetExpandedPercentage)),
                    ),
                  ),
                ),
              } else ...{
                Expanded(
                  child: Container(),
                ),
              },
              if (i < 2) const SizedBox(width: 8.0),
            },
          ],
          // shrinkWrap: true,
          // scrollDirection: Axis.horizontal,
          // physics: const NeverScrollableScrollPhysics(),
          // itemBuilder: (BuildContext context, int position) {
          //   final busService = _filteredBusServices[position];
          //   return BusServiceSearchItem(
          //     onTap: () => _pushBusServiceRoute(busService),
          //     busService: busService,
          //   );
          // },
          // separatorBuilder: (context, index) {
          //   return const SizedBox(width: 8.0);
          // },
          // itemCount: _showServicesOnly
          //     ? _filteredBusServices.length
          //     : min(_filteredBusServices.length, 3),
        ),
      ),
    );
  }

  Widget _buildBusStopSearchItem(
      BusStop busStop, _QueryMetadata metadata, BuildContext context,
      {bool showMapButton = false,
      bool? isExpanded,
      required void Function() onTap}) {
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
      isMapEnabled: showMapButton,
      defaultExpanded: isExpanded,
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
          });
        }

        // Animate to map view first, then animate to bus stop
        _tabController.animateTo(1);
        final animation = _onTabTap(1);
        animation.whenCompleteOrCancel(focusOnBusStop);
      },
      busStop: busStop,
      onTap: onTap,
    );
  }

  Widget _buildBusStopList(Map<BusStop, _QueryMetadata> queryMetadata) {
    final busStopsInSelectedBusService = _busStopServicesFilter.isEmpty
        ? []
        : ref.watch(busStopsInServicesProvider(_busStopServicesFilter)).value ??
            [];

    final orderedBusStops = _filteredBusStops
        ?.where((busStop) =>
            _busStopServicesFilter.isEmpty ||
            busStopsInSelectedBusService.contains(busStop))
        .toList();

    if (areBusStopsLoading || orderedBusStops == null) {
      return SliverList(delegate: SliverChildBuilderDelegate(
        (BuildContext context, int position) {
          final name =
              'Bus stop ${Random(kRandomSeed + position).nextInt(999) + 1}';
          final road =
              '${Random(kRandomSeed + position).nextInt(99) + 1} Street';
          final code =
              '${Random(kRandomSeed + position).nextInt(90000) + 10000}';

          final placeholderBusStop = BusStop(
            defaultName: name,
            displayName: name,
            code: code,
            latitude: 0,
            longitude: 0,
            road: road,
          );

          final busStop = orderedBusStops?[position] ?? placeholderBusStop;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Shimmer.fromColors(
              baseColor: Color.lerp(Theme.of(context).hintColor,
                  Theme.of(context).canvasColor, 0.9)!,
              highlightColor: Theme.of(context).canvasColor,
              child: IgnorePointer(
                child: BusStopItem(
                    key: ValueKey(position), isLoading: true, busStop),
              ),
            ),
          );
        },
      ));
    }

    return SliverList(
        delegate: SliverChildBuilderDelegate(
      (BuildContext context, int position) {
        final busStop = orderedBusStops[position];
        final metadata = queryMetadata[busStop]!;

        final item =
            _buildBusStopSearchItem(busStop, metadata, context, onTap: () {
          if (widget.isSimpleMode) {
            // Return result
            Navigator.pop(context, busStop);
          }
        });
        return position == 0
            ? _buildFirstBusStopItem(context, busStop, metadata)
            : item;
      },
      childCount: _showServicesOnly ? 0 : orderedBusStops.length,
    ));
  }

  Widget _buildFirstBusStopItem(
      BuildContext context, BusStop busStop, _QueryMetadata metadata) {
    return AnimatedBuilder(
      animation: _resultsSheetAnimationController,
      builder: (BuildContext context, Widget? child) {
        return _buildVerticalSwitcher(
          expandedChild: child,
          collapsedChild: _buildBusStopSearchItem(
            _displayedBusStop!,
            metadata,
            context,
            showMapButton: true,
            onTap: () {
              _expandSheet();
              setState(() {
                _isNearestBusStopExpanded = true;
              });
            },
            isExpanded: false,
          ),
          expandedPercentage: _resultsSheetExpandedPercentage,
          offset: false,
        );
      },
      child: _buildBusStopSearchItem(
        busStop,
        metadata,
        context,
        showMapButton: false,
        isExpanded: _isNearestBusStopExpanded,
        onTap: () {
          if (widget.isSimpleMode) {
            // Return result
            Navigator.pop(context, busStop);
          } else {
            setState(() {
              _isNearestBusStopExpanded = !_isNearestBusStopExpanded;
            });
          }
        },
      ),
    );
  }

  void _hideKeyboard() {
    FocusScope.of(context).unfocus();
  }

  static Iterable<BusService> filterBusServices(
          List<BusService> list, String query) =>
      list.where((BusService busService) =>
          busService.number.toLowerCase().startsWith(query.toLowerCase()));

  Map<BusStop, _QueryMetadata> useQueryMetadata() {
    return useMemoized(() {
      return <BusStop, _QueryMetadata>{
        for (BusStop busStop in (_filteredBusStops ?? []))
          busStop: _calculateQueryMetadata(busStop, _query)
      };
    }, [_filteredBusStops, _query]);
  }

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
    pushHistory(_query); // add query to history
    BusServiceDetailRoute(serviceNumber: busService.number).push(context);
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
