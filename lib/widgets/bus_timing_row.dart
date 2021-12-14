import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:collection/collection.dart';

import '../main.dart';
import '../models/bus_service.dart';
import '../models/bus_stop.dart';
import '../routes/bus_service_page.dart';
import '../routes/home_page.dart';
import '../utils/bus_service_arrival_result.dart';
import '../utils/bus_utils.dart';
import '../utils/database_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/bus_stop_detail_sheet.dart';
import '../widgets/route_model.dart';

class BusTimingRow extends StatefulWidget {
  const BusTimingRow(
      this.busStop, this.busService, this.arrivalResult, this.isEditing,
      {Key? key})
      : showNotificationButton = true,
        super(key: key);
  const BusTimingRow.unfocusable(
      this.busStop, this.busService, this.arrivalResult,
      {Key? key})
      : isEditing = false,
        showNotificationButton = true,
        super(key: key);

  final BusStop busStop;
  final BusService busService;
  final BusServiceArrivalResult? arrivalResult;
  final bool isEditing;
  final bool showNotificationButton;
  static const double height = 56.0;

  bool get hasArrivals => arrivalResult != null;

  @override
  _BusTimingState createState() {
    return _BusTimingState();
  }
}

class _BusTimingState extends State<BusTimingRow>
    with TickerProviderStateMixin {
  bool _isBusFollowed = false;

  @override
  void initState() {
    super.initState();

    addBusFollowStatusListener(widget.busStop.code, widget.busService.number,
        onBusFollowStatusChanged);

    isBusFollowed(stop: widget.busStop.code, bus: widget.busService.number)
        .then((bool isFollowed) {
      setState(() {
        _isBusFollowed = isFollowed;
      });
    });
  }

  void onBusFollowStatusChanged(
      String busStopCode, String busServiceNumber, bool isFollowed) {
    setState(() {
      _isBusFollowed = isFollowed;
    });
  }

  @override
  void dispose() {
    removeBusFollowStatusListener(widget.busStop.code, widget.busService.number,
        onBusFollowStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget item = InkWell(
      onTap: widget.isEditing
          ? () async {
              final bool isPinned = await isBusServicePinned(widget.busStop,
                  widget.busService, RouteModel.of(context)!.route);

              if (isPinned) {
                await unpinBusService(widget.busStop, widget.busService,
                    RouteModel.of(context)!.route);
              } else {
                await pinBusService(widget.busStop, widget.busService,
                    RouteModel.of(context)!.route);
              }
              HomePage.of(context)?.refresh();
              setState(() {});
            }
          : () => _pushBusServiceRoute(widget.busService.number),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (widget.hasArrivals) Center(child: _buildBusTimingItems()),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    AnimatedSize(
                      duration: BusStopDetailSheet.editAnimationDuration * 2,
                      curve: Curves.easeInOutCirc,
                      child: FutureBuilder<bool>(
                        initialData: false,
                        future: isBusServicePinned(widget.busStop,
                            widget.busService, RouteModel.of(context)!.route),
                        builder: (BuildContext context,
                            AsyncSnapshot<bool> snapshot) {
                          final bool isChecked = snapshot.data!;
                          final Checkbox checkbox = Checkbox(
                              value: isChecked,
                              onChanged: (bool? checked) async {
                                if (checked ?? false) {
                                  await pinBusService(
                                      widget.busStop,
                                      widget.busService,
                                      RouteModel.of(context)!.route);
                                } else {
                                  await unpinBusService(
                                      widget.busStop,
                                      widget.busService,
                                      RouteModel.of(context)!.route);
                                }
                                HomePage.of(context)?.refresh();
                                setState(() {});
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
                            textStyle: Theme.of(context).textTheme.headline5,
                            color: widget.hasArrivals
                                ? Theme.of(context).textTheme.headline6!.color
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
      duration: BusStopDetailSheet.editAnimationDuration * 2,
      curve: Curves.easeInOutCirc,
      child: item,
    );
  }

  Widget _buildNotificationButton() {
    return AnimatedOpacity(
      duration: BusStopDetailSheet.editAnimationDuration,
      opacity: widget.isEditing ? 0 : 1,
      child: IconButton(
        tooltip: 'Notify me when the bus arrives',
        icon: _isBusFollowed
            ? const Icon(Icons.notifications_active)
            : Icon(Icons.notifications_none,
                color: Theme.of(context).hintColor),
        onPressed: widget.arrivalResult?.buses.firstOrNull != null
            ? () {
                if (_isBusFollowed) {
                  unfollowBus(
                      stop: widget.busStop.code, bus: widget.busService.number);
                } else {
                  final SnackBar snackBar = SnackBar(
                      content: Text(
                          'Tracking the ${widget.busService.number} bus arriving in ${widget.arrivalResult!.buses.first!.arrivalTime.getMinutesFromNow()} min'));
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);

                  final DateTime estimatedArrivalTime =
                      widget.arrivalResult!.buses.first!.arrivalTime;
                  followBus(
                      stop: widget.busStop.code,
                      bus: widget.busService.number,
                      arrivalTime: estimatedArrivalTime);
                }

                // Refresh home page to show followed buses
                HomePage.of(context)?.refresh();
              }
            : null,
      ),
    );
  }

  Widget _buildBusTimingItems() {
    return SizedBox(
      height: BusTimingRow.height,
      child: AnimatedOpacity(
        duration: BusStopDetailSheet.editAnimationDuration,
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
  const _BusTimingItem(this.busArrival, {Key? key}) : super(key: key);

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
    final Color busLoadColor = getBusLoadColor(
        widget.busArrival?.load, MediaQuery.of(context).platformBrightness);
    return Stack(
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        Text(
          getBusTypeVerbose(widget.busArrival?.type),
          style: Theme.of(context)
              .textTheme
              .bodyText2!
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
                    .headline6!
                    .copyWith(color: busLoadColor, fontSize: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
