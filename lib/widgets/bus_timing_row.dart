import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:stops_sg/bus_api/models/bus_service.dart';
import 'package:stops_sg/bus_api/models/bus_service_arrival_result.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/bus_stop_sheet/widgets/bus_stop_sheet.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/main.dart';
import 'package:stops_sg/routes/bus_service_page.dart';
import 'package:stops_sg/utils/bus_utils.dart';
import 'package:stops_sg/utils/database/followed_buses.dart';
import 'package:stops_sg/utils/time_utils.dart';

class BusTimingRow extends ConsumerStatefulWidget {
  const BusTimingRow(
      this.busStop, this.busService, this.arrivalResult, this.isEditing,
      {super.key})
      : showNotificationButton = true;
  const BusTimingRow.unfocusable(
      this.busStop, this.busService, this.arrivalResult,
      {super.key})
      : isEditing = false,
        showNotificationButton = true;

  final BusStop busStop;
  final BusService busService;
  final BusServiceArrivalResult? arrivalResult;
  final bool isEditing;
  final bool showNotificationButton;
  static const double height = 56.0;

  bool get hasArrivals => arrivalResult != null;

  @override
  BusTimingState createState() {
    return BusTimingState();
  }
}

class BusTimingState extends ConsumerState<BusTimingRow>
    with TickerProviderStateMixin {
  bool get _isBusFollowed =>
      ref
          .watch(isBusFollowedProvider(
              busStopCode: widget.busStop.code,
              busServiceNumber: widget.busService.number))
          .valueOrNull ??
      false;

  @override
  Widget build(BuildContext context) {
    final route = context.watch<StoredUserRoute>();
    final isPinned = ref
            .watch(isBusServicePinnedProvider(
                busStop: widget.busStop,
                busService: widget.busService,
                routeId: route.id))
            .valueOrNull ??
        false;

    final Widget item = InkWell(
      onTap: widget.isEditing
          ? () async {
              if (isPinned) {
                await ref
                    .read(savedUserRouteProvider(id: route.id).notifier)
                    .unpinBusService(
                        busStop: widget.busStop, busService: widget.busService);
              } else {
                await ref
                    .read(savedUserRouteProvider(id: route.id).notifier)
                    .pinBusService(
                        busStop: widget.busStop, busService: widget.busService);
              }
            }
          : () => _pushBusServiceRoute(widget.busService.number),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.hasArrivals) Center(child: _buildBusTimingItems()),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    AnimatedSize(
                      duration: kSheetEditDuration * 2,
                      curve: Curves.easeInOutCirc,
                      child: Builder(
                        builder: (BuildContext context) {
                          final checkbox = Checkbox(
                              value: isPinned,
                              onChanged: (bool? checked) async {
                                if (checked ?? false) {
                                  await ref
                                      .read(savedUserRouteProvider(id: route.id)
                                          .notifier)
                                      .pinBusService(
                                          busStop: widget.busStop,
                                          busService: widget.busService);
                                } else {
                                  await ref
                                      .read(savedUserRouteProvider(id: route.id)
                                          .notifier)
                                      .unpinBusService(
                                          busStop: widget.busStop,
                                          busService: widget.busService);
                                }
                              });
                          if (widget.isEditing) return checkbox;
                          return Container();
                        },
                      ),
                    ),
                    if (widget.hasArrivals || widget.isEditing)
                      Container(
                        alignment: Alignment.centerLeft,
                        height: BusTimingRow.height,
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          widget.busService.number.padAsServiceNumber(),
                          style: GoogleFonts.getFont(
                            StopsApp.monospacedFont,
                            textStyle:
                                Theme.of(context).textTheme.headlineSmall,
                            color: widget.hasArrivals
                                ? Theme.of(context).textTheme.titleLarge!.color
                                : Theme.of(context).hintColor,
                          ),
                        ),
                      ),
                  ],
                ),
                if (widget.hasArrivals && widget.showNotificationButton)
                  _buildNotificationButton(),
              ],
            ),
          ),
        ],
      ),
    );
    return AnimatedSize(
      duration: kSheetEditDuration * 2,
      curve: Curves.easeInOutCirc,
      child: item,
    );
  }

  Widget _buildNotificationButton() {
    return AnimatedOpacity(
      duration: kSheetEditDuration,
      opacity: widget.isEditing ? 0 : 1,
      child: IconButton(
        tooltip: 'Notify me when the bus arrives',
        icon: _isBusFollowed
            ? const Icon(Icons.notifications_active_rounded)
            : Icon(Icons.notifications_none_rounded,
                color: Theme.of(context).hintColor),
        onPressed: widget.arrivalResult?.buses.firstOrNull != null
            ? () {
                if (_isBusFollowed) {
                  ref.read(followedBusesProvider.notifier).unfollowBus(
                      busStopCode: widget.busStop.code,
                      busServiceNumber: widget.busService.number);
                } else {
                  final snackBar = SnackBar(
                      content: Text(
                          'Tracking the ${widget.busService.number} bus arriving in ${widget.arrivalResult!.buses.first!.arrivalTime.getMinutesFromNow()} min'));
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);

                  ref.read(followedBusesProvider.notifier).followBus(
                      busStopCode: widget.busStop.code,
                      busServiceNumber: widget.busService.number);
                }

                // TODO: Verify that  home page shows followed buses
              }
            : null,
      ),
    );
  }

  Widget _buildBusTimingItems() {
    return SizedBox(
      height: BusTimingRow.height,
      child: AnimatedOpacity(
        duration: kSheetEditDuration,
        opacity: widget.isEditing ? 0 : 1,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemBuilder: (BuildContext context, int position) {
            if (position >= widget.arrivalResult!.buses.length) {
              return Container(width: BusTimingRow.height);
            }
            return _BusTimingItem(widget.arrivalResult!.buses[position],
                key: Key(
                    '${widget.busStop.code} ${widget.busService.number} $position'));
          },
          separatorBuilder: (BuildContext context, int position) {
            return const VerticalDivider(width: 1, indent: 8.0, endIndent: 8.0);
          },
          itemCount: 3,
        ),
      ),
    );
  }

  void _pushBusServiceRoute(String serviceNumber) {
    final Widget page =
        BusServicePage.withBusStop(serviceNumber, widget.busStop);
    final Route<void> route =
        MaterialPageRoute<void>(builder: (BuildContext context) => page);
    Navigator.push(context, route);
  }
}

class _BusTimingItem extends StatefulWidget {
  const _BusTimingItem(this.busArrival, {super.key});

  final BusArrival? busArrival;

  @override
  State<StatefulWidget> createState() {
    return _BusTimingItemState();
  }
}

class _BusTimingItemState extends State<_BusTimingItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      duration: const Duration(milliseconds: 500), vsync: this);

  bool get shouldAnimate =>
      (widget.busArrival?.arrivalTime.getMinutesFromNow() ?? 0) <= 1;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((AnimationStatus status) {
      if (shouldAnimate) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _controller.forward();
        }
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (shouldAnimate) {
      if (!_controller.isAnimating) _controller.forward();
    } else {
      _controller.stop();
      _controller.reset();
    }
    final busLoadColor =
        getBusLoadColor(widget.busArrival?.load, Theme.of(context));
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Text(
          getBusTypeVerbose(widget.busArrival?.type),
          style: Theme.of(context)
              .textTheme
              .bodyMedium!
              .copyWith(color: busLoadColor.withOpacity(0.5)),
        ),
        SizedBox(
          width: BusTimingRow.height,
          child: Center(
            child: AnimatedBuilder(
              animation:
                  _controller.drive(CurveTween(curve: Curves.easeInOutExpo)),
              builder: (BuildContext context, Widget? child) {
                return Transform.scale(
                  scale: lerpDouble(1, 1.25, _controller.value)!,
                  child: child,
                );
              },
              child: Text(
                widget.busArrival != null
                    ? getBusTimingShortened(
                        widget.busArrival!.arrivalTime.getMinutesFromNow())
                    : '',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .copyWith(color: busLoadColor, fontSize: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
