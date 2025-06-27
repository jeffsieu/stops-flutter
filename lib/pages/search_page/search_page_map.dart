import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:location/location.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/location/location.dart';
import 'package:stops_sg/utils/bus_stop_distance_utils.dart';
import 'package:stops_sg/utils/distance_utils.dart';

part 'search_page_map.g.dart';

@riverpod
Future<String> googleMapDarkStyle(Ref ref) async {
  return await rootBundle.loadString('assets/maps/map_style_dark.json');
}

class SearchPageMap extends StatefulHookConsumerWidget {
  const SearchPageMap({
    super.key,
    required this.busStops,
    required this.paddingBottom,
    required this.paddingTop,
    required this.isVisible,
    required this.query,
    required this.focusedBusStop,
    required this.onFocusedBusStopChanged,
  });

  final List<BusStop> busStops;
  final double paddingTop;
  final double paddingBottom;
  final bool isVisible;
  final String query;
  final BusStop? focusedBusStop;
  final void Function(BusStop?) onFocusedBusStopChanged;

  @override
  ConsumerState<SearchPageMap> createState() => _SearchPageMapState();
}

class _SearchPageMapState extends ConsumerState<SearchPageMap> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  static const int _furthestBusStopDistanceMeters = 3000;
  static const LatLng _defaultCameraPosition = LatLng(1.3521, 103.8198);
  BusStop? get focusedBusStop => widget.focusedBusStop;
  set focusedBusStop(BusStop? value) => widget.onFocusedBusStopChanged(value);

  @override
  Widget build(BuildContext context) {
    final userLocation = ref.watch(userLocationProvider).value?.data;
    final initialCameraPosition = _getCameraPositionFromLocation(userLocation);
    final googleMapStyle = Theme.of(context).brightness == Brightness.dark
        ? ref.watch(googleMapDarkStyleProvider).value
        : null;

    final focusedBusStopLocation = useMemoized(() {
      if (focusedBusStop == null) {
        return null;
      }

      return LatLng(focusedBusStop!.latitude, focusedBusStop!.longitude);
    }, [focusedBusStop]);
    final focusedLocation = useState<LatLng?>(focusedBusStopLocation);
    final cameraPosition = useState<CameraPosition>(initialCameraPosition);

    final markerOrigin = useMemoized(() {
      if (focusedLocation.value != null) {
        return focusedLocation.value!;
      }

      return userLocation?.toLatLng() ?? _defaultCameraPosition;
    }, [focusedLocation.value, userLocation]);

    final showRefocusButton = useMemoized(() {
      // If the distance to _focusedLocation is greater than the threshold,
      // make the re-focus button visible.
      final distanceMeters =
          markerOrigin.distanceMetersTo(cameraPosition.value.target);
      return distanceMeters > _furthestBusStopDistanceMeters;
    }, [markerOrigin, cameraPosition.value]);

    useEffect(() {
      focusedLocation.value = focusedBusStopLocation;
      return null;
    }, [focusedBusStopLocation]);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        GoogleMap(
          padding: EdgeInsets.only(
            top: widget.paddingTop,
            bottom: widget.paddingBottom,
          ),
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          mapToolbarEnabled: true,
          compassEnabled: true,
          zoomControlsEnabled: false,
          myLocationEnabled: widget.isVisible,
          myLocationButtonEnabled: false,
          mapType: MapType.normal,
          initialCameraPosition: initialCameraPosition,
          style: googleMapStyle,
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);

            if (userLocation != null) {
              controller.moveCamera(CameraUpdate.newCameraPosition(
                  _getCameraPositionFromLocation(userLocation)));
            }
          },
          onCameraMove: (CameraPosition position) {
            // If the distance to _focusedLocation is greater than the threshold,
            // make the re-focus button visible.
            cameraPosition.value = position;
          },
          onTap: (_) {
            focusedBusStop = null;
          },
          markers: _buildMapMarkersAround(
            markerOrigin,
            context,
            onBusStopMarkerTap: (busStop) {
              focusedBusStop = busStop;
              focusedLocation.value =
                  LatLng(busStop.latitude, busStop.longitude);
            },
          ),
        ),
        if (userLocation != null)
          Positioned(
            bottom: widget.paddingBottom + 16.0,
            child: FloatingActionButton.extended(
                label: const Text('Focus on my location'),
                icon: const Icon(Icons.my_location_rounded),
                onPressed: () async {
                  final controller = await _controller.future;
                  final currentZoom = await controller.getZoomLevel();

                  controller.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: userLocation.toLatLng()!,
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
                curve: widget.query.isEmpty
                    ? const Interval(0.5, 1.0)
                    : const Interval(0.0, 0.5),
                opacity: widget.query.isEmpty ? 0.0 : 1.0,
                child: AnimatedSlide(
                  offset: widget.query.isEmpty
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
                              color: Theme.of(context).hintColor, size: 20.0),
                          const SizedBox(width: 8.0),
                          Text(
                            'Showing only "${widget.query}"',
                            style:
                                TextStyle(color: Theme.of(context).hintColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: showRefocusButton ? 1.0 : 0.0,
                  child: ElevatedButton(
                    onPressed: () async {
                      final controller = await _controller.future;
                      final visibleRegion = await controller.getVisibleRegion();
                      final centerLatitude = (visibleRegion.northeast.latitude +
                              visibleRegion.southwest.latitude) /
                          2;
                      final centerLongitude =
                          (visibleRegion.northeast.longitude +
                                  visibleRegion.southwest.longitude) /
                              2;
                      focusedLocation.value =
                          LatLng(centerLatitude, centerLongitude);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).cardColor,
                    ),
                    child: Text(
                        'Search this area for ${widget.query.isEmpty ? 'stops' : '"${widget.query}"'}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  CameraPosition _getCameraPositionFromLocation(LocationData? userLocation) {
    return CameraPosition(
      target: userLocation?.toLatLng() ?? _defaultCameraPosition,
      zoom: 18,
    );
  }

  Set<Marker> _buildMapMarkersAround(LatLng? position, BuildContext context,
      {required void Function(BusStop busStop) onBusStopMarkerTap}) {
    if (position == null) {
      return {};
    }

    return widget.busStops
        .where((busStop) =>
            busStop.getMetersFromLocation(position) <=
            _furthestBusStopDistanceMeters)
        .map((busStop) => Marker(
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange),
              markerId: MarkerId(busStop.code),
              position: LatLng(busStop.latitude, busStop.longitude),
              infoWindow:
                  InfoWindow(title: busStop.displayName, snippet: busStop.road),
              onTap: () => onBusStopMarkerTap(busStop),
            ))
        .toSet();
  }
}

extension on LatLng {
  double distanceMetersTo(LatLng other) {
    return metersBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }
}
