import 'dart:ui';

import 'package:flutter/material.dart';

import '../routes/bus_service_page.dart';
import '../utils/bus_utils.dart';
import '../utils/database_utils.dart';
import '../utils/notification_utils.dart';
import '../utils/time_utils.dart';

class BusTimingRow extends StatefulWidget {
  const BusTimingRow(this.busStopCode, this.busInfo, {Key key})
      : super(key: key);

  final dynamic busInfo;
  final String busStopCode;
  static const double height = 56.0;

  @override
  _BusTimingState createState() {
    return _BusTimingState();
  }
}

class _BusTimingState extends State<BusTimingRow> {
  bool _isBusFollowed = false;
  String serviceNumber;

  @override
  void initState() {
    super.initState();
    serviceNumber = widget.busInfo['ServiceNo'];
    isBusFollowed(stop: widget.busStopCode, bus: serviceNumber)
        .then((bool isFollowed) {
      if (mounted && _isBusFollowed != isFollowed)
        setState(() {
          _isBusFollowed = isFollowed;
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pushBusServiceRoute(serviceNumber),
      child: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Text(
                    serviceNumber + ' '*( 4-serviceNumber.length),
                    style: Theme.of(context).textTheme.title.copyWith(fontFamily: 'B612 Mono'),
                    textAlign: TextAlign.right,
                  ),
                ),
                _buildBusTimingItems(),
              ],
            ),
            IconButton(
              tooltip: 'Notify me when the bus arrives',
              icon: Icon(_isBusFollowed
                  ? Icons.notifications_active
                  : Icons.notifications_none),
              onPressed: () {
                if (_isBusFollowed) {
                  unfollowBus(stop: widget.busStopCode, bus: serviceNumber);
                } else {
                  BusFollowStatusListener listener;
                  listener = (String stop, String code, bool isFollowed) {
                    if (stop == widget.busStopCode &&
                        code == serviceNumber &&
                        !isFollowed) {
                      setState(() {
                        _isBusFollowed = !_isBusFollowed;
                      });

                      removeBusFollowStatusListener(widget.busStopCode, serviceNumber, listener);
                    }
                  };

                  addBusFollowStatusListener(widget.busStopCode, serviceNumber, listener);

                  final DateTime estimatedArrivalTime = DateTime.parse(widget.busInfo['NextBus']['EstimatedArrival']);
                  final DateTime notificationTime = estimatedArrivalTime.subtract(const Duration(seconds: 30));

                  followBus(stop: widget.busStopCode, bus: serviceNumber);
                  final SnackBar snackBar = SnackBar(content: Text('You will be notified when $serviceNumber arrives'));

                  Scaffold.of(context).showSnackBar(snackBar);
                  // Add notification timer
                  NotificationAPI().scheduleNotification(widget.busStopCode, serviceNumber, notificationTime);

                  if (mounted)
                    setState(() {
                      _isBusFollowed = !_isBusFollowed;
                    });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusTimingItems() {
    final Function listLength = (dynamic busInfo) {
      if (busInfo['NextBus3']['EstimatedArrival'].isNotEmpty)
        return 3;
      if (busInfo['NextBus2']['EstimatedArrival'].isNotEmpty)
        return 2;
      if (busInfo['NextBus']['EstimatedArrival'].isNotEmpty)
        return 1;
      return 0;
    };
    return Container(
      height: BusTimingRow.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemBuilder: (BuildContext context, int position) {
          dynamic busInfo;
          if (position == 0)
            busInfo = widget.busInfo['NextBus'];
          else
            busInfo = widget.busInfo['NextBus${position+1}'];
          return _BusTimingItem(
              busInfo['EstimatedArrival'],
              busInfo['Type'],
              busInfo['Load'],
              key: Key('${widget.busStopCode} $serviceNumber $position')
          );
        },
        separatorBuilder: (BuildContext context, int position) {
          return const VerticalDivider();
        },
        itemCount: listLength(widget.busInfo),
      ),
    );
  }

  void _pushBusServiceRoute(String serviceNumber) {
    final Route<void> route = MaterialPageRoute<void>(builder: (BuildContext context) => BusServicePage(serviceNumber));
    Navigator.push(context, route);
  }
}

class _BusTimingItem extends StatefulWidget {
  const _BusTimingItem(this.timeArrival, this.busSize, this.busLoad, {Key key}) : super(key: key);

  final String timeArrival, busSize, busLoad;

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
    if (widget.timeArrival.isNotEmpty &&
        getMinutesFromNow(widget.timeArrival) <= 1)
      _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color busLoadColor = getBusLoadColor(widget.busLoad, Brightness.light);
    return Stack(
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        Text(getBusTypeVerbose(widget.busSize)),
        Container(
          width: BusTimingRow.height,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller.drive(CurveTween(curve: Curves.easeInOutExpo)),
              builder: (BuildContext context, Widget child) {
                return Transform.scale(scale: lerpDouble(1, 1.25, _controller.value), child: child);
              },
              child: Text(
                widget.timeArrival.isNotEmpty
                    ? getBusTimingShortened(
                    getMinutesFromNow(widget.timeArrival))
                    : '',
                style: Theme.of(context).textTheme.title.copyWith(color: busLoadColor, fontSize: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}