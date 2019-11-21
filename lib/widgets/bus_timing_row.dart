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

class BusTimingRow extends StatefulWidget {
  const BusTimingRow(this.busStop, this.busService, this.arrivalResult, this.isEditing, {Key key})
      : super(key: key);

  final BusStop busStop;
  final BusService busService;
  final BusServiceArrivalResult arrivalResult;
  final bool isEditing;
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
                        future: isBusServicePinned(widget.busStop, service),
                        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                          final bool isChecked = snapshot.data;
                          if (widget.isEditing)
                            return Checkbox(
                              value: isChecked,
                              onChanged: (bool checked) => setState(() {
                                if (checked)
                                  pinBusService(widget.busStop, service);
                                else
                                  unpinBusService(widget.busStop, service);
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
                            Theme.of(context).textTheme.title.copyWith(fontFamily: 'B612 Mono') :
                            Theme.of(context).textTheme.title.copyWith(
                              fontFamily: 'B612 Mono',
                              color: Theme.of(context).hintColor,
                            ),
                        ),
                      ),
                  ],
                ),
                if (widget.hasArrivals)
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
        icon: Icon(_isBusFollowed
            ? Icons.notifications_active
            : Icons.notifications_none),
        onPressed: () {
          if (_isBusFollowed) {
            unfollowBus(stop: widget.busStop.code, bus: service.number);
          } else {
            BusFollowStatusListener listener;
            listener = (String stop, String code, bool isFollowed) {
              if (stop == widget.busStop.code &&
                  code == service.number &&
                  !isFollowed) {
                setState(() {
                  _isBusFollowed = !_isBusFollowed;
                });

                removeBusFollowStatusListener(widget.busStop.code, service.number, listener);
              }
            };

            addBusFollowStatusListener(widget.busStop.code, service.number, listener);

            final DateTime estimatedArrivalTime = widget.arrivalResult.buses[0].arrivalTime;
            final DateTime notificationTime = estimatedArrivalTime.subtract(const Duration(seconds: 30));

            followBus(stop: widget.busStop.code, bus: service.number);
            final SnackBar snackBar = SnackBar(content: Text('You will be notified when ${service.number} arrives'));

            Scaffold.of(context).showSnackBar(snackBar);
            // Add notification timer
            NotificationAPI().scheduleNotification(widget.busStop.code, service.number, notificationTime);

            if (mounted)
              setState(() {
                _isBusFollowed = !_isBusFollowed;
              });
          }
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
            return const VerticalDivider(width: 1);
          },
          itemCount: 3,
        ),
      ),
    );
  }

  void _pushBusServiceRoute(String serviceNumber) {
    final Route<void> route = MaterialPageRoute<void>(builder: (BuildContext context) => BusServicePage(serviceNumber));
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
    if (getMinutesFromNow(widget.bus.arrivalTime) <= 1)
      _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color busLoadColor = getBusLoadColor(widget.bus.load, MediaQuery.of(context).platformBrightness);
    return Stack(
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        Text(
          getBusTypeVerbose(widget.bus.type),
          style: Theme.of(context).textTheme.body1.copyWith(color: busLoadColor.withOpacity(0.5)),
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
                getBusTimingShortened(getMinutesFromNow(widget.bus.arrivalTime)),
                style: Theme.of(context).textTheme.title.copyWith(color: busLoadColor, fontSize: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}