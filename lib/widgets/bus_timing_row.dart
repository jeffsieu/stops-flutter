import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../routes/bus_service_page.dart';
import '../utils/bus_service.dart';
import '../utils/bus_service_arrival_result.dart';
import '../utils/bus_stop.dart';
import '../utils/bus_utils.dart';
import '../utils/database_utils.dart';
import '../utils/notification_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/bus_stop_detail_sheet.dart';
import '../widgets/route_model.dart';

class BusTimingRow extends StatefulWidget {
  const BusTimingRow(this.busStop, this.busService, this.arrivalResult, this.isEditing, {Key key})
      : showNotificationButton = true, super(key: key);
  const BusTimingRow.unfocusable(this.busStop, this.busService, this.arrivalResult, {Key key})
      : isEditing = false, showNotificationButton = false, super(key: key);

  final BusStop busStop;
  final BusService busService;
  final BusServiceArrivalResult arrivalResult;
  final bool isEditing;
  final bool showNotificationButton;
  static const double height = 56.0;

  bool get hasArrivals => arrivalResult != null;

  @override
  _BusTimingState createState() {
    return _BusTimingState();
  }
}

class _BusTimingState extends State<BusTimingRow> with TickerProviderStateMixin {
  bool _isBusFollowed = false;
  BusService service;

  @override
  void initState() {
    super.initState();
    service = widget.busService;
    isBusFollowed(stop: widget.busStop.code, bus: service.number)
        .then((bool isFollowed) {
      if (mounted && _isBusFollowed != isFollowed)
        setState(() {
          _isBusFollowed = isFollowed;
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget item = InkWell(
      onTap: () => widget.isEditing ? null : _pushBusServiceRoute(service.number),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (widget.hasArrivals)
            Center(child: _buildBusTimingItems()),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    AnimatedSize(
                      vsync: this,
                      duration: BusStopDetailSheet.editAnimationDuration * 2,
                      curve: Curves.easeInOutCirc,
                      child: FutureBuilder<bool>(
                        initialData: false,
                        future: isBusServicePinned(widget.busStop, service, RouteModel.of(context).route),
                        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                          final bool isChecked = snapshot.data;
                          if (widget.isEditing)
                            return Checkbox(
                              value: isChecked,
                              onChanged: (bool checked) => setState(() {
                                if (checked)
                                  pinBusService(widget.busStop, service, RouteModel.of(context).route);
                                else
                                  unpinBusService(widget.busStop, service, RouteModel.of(context).route);
                              }),
                            );
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
                          _padServiceNumber(service.number),
                          style: widget.hasArrivals ?
                            Theme.of(context).textTheme.headline6.copyWith(fontFamily: 'B612 Mono') :
                            Theme.of(context).textTheme.headline6.copyWith(
                              fontFamily: 'B612 Mono',
                              color: Theme.of(context).hintColor,
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
      vsync: this,
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
        icon: _isBusFollowed ? const Icon(Icons.notifications_active)
            : Icon(Icons.notifications_none, color: Theme.of(context).hintColor),
        onPressed: () {
          if (_isBusFollowed) {
            unfollowBus(stop: widget.busStop.code, bus: service.number);
            NotificationAPI().untrackBus();
          } else {

            final DateTime estimatedArrivalTime = widget.arrivalResult.buses[0].arrivalTime;
            final DateTime notificationTime = estimatedArrivalTime.subtract(const Duration(seconds: 30));

            followBus(stop: widget.busStop.code, bus: service.number);
            final SnackBar snackBar = SnackBar(content: Text('Tracking the next ${service.number} bus'));

            Scaffold.of(context).showSnackBar(snackBar);
            // Add notification timer
            NotificationAPI().trackBus(widget.busStop, service, notificationTime);
          }

          if (mounted)
            setState(() {
              _isBusFollowed = !_isBusFollowed;
            });
        },
      ),
    );
  }

  Widget _buildBusTimingItems() {
    return Container(
      height: BusTimingRow.height,
      child: AnimatedOpacity(
        duration: BusStopDetailSheet.editAnimationDuration,
        opacity: widget.isEditing ? 0 : 1,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemBuilder: (BuildContext context, int position) {
            if (position >= widget.arrivalResult.buses.length) {
              return Container(width: BusTimingRow.height);
            }
            return _BusTimingItem(
              widget.arrivalResult.buses[position],
              key: Key('${widget.busStop.code} ${service.number} $position')
            );
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
    final Route<void> route = MaterialPageRoute<void>(builder: (BuildContext context) => BusServicePage.withBusStop(serviceNumber, widget.busStop));
    Navigator.push(context, route);
  }

  String _padServiceNumber(String serviceNumber) {
    // Service number contains letter
    if (serviceNumber.contains(RegExp(r'\D'))) {
      final String number = serviceNumber.substring(0, serviceNumber.length - 1);
      final String letter = serviceNumber[serviceNumber.length - 1];
      return number.padLeft(3) + letter;
    } else {
      return serviceNumber.padLeft(3).padRight(1);
    }
  }
}

class _BusTimingItem extends StatefulWidget {
  const _BusTimingItem(this.bus, {Key key}) : super(key: key);

  final Bus bus;

  @override
  State<StatefulWidget> createState() {
    return _BusTimingItemState();
  }
}

class _BusTimingItemState extends State<_BusTimingItem>
    with SingleTickerProviderStateMixin {
  AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controller.forward();
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
    if (widget.bus.arrivalTime.getMinutesFromNow() <= 1) {
      if (!_controller.isAnimating)
        _controller.forward();
    }
    else
      _controller.reset();
    final Color busLoadColor = getBusLoadColor(widget.bus.load, MediaQuery.of(context).platformBrightness);
    return Stack(
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        Text(
          getBusTypeVerbose(widget.bus.type),
          style: Theme.of(context).textTheme.bodyText2.copyWith(color: busLoadColor.withOpacity(0.5)),
        ),
        Container(
          width: BusTimingRow.height,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller.drive(CurveTween(curve: Curves.easeInOutExpo)),
              builder: (BuildContext context, Widget child) {
                return Transform.scale(
                    scale: lerpDouble(1, 1.25, _controller.value),
                    child: child,
                );
              },
              child: Text(
                getBusTimingShortened(widget.bus.arrivalTime.getMinutesFromNow()),
                style: Theme.of(context).textTheme.headline6.copyWith(color: busLoadColor, fontSize: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}