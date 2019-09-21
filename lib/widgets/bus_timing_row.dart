import 'package:flutter/material.dart';

import '../utils/bus_utils.dart';
import '../utils/notification_utils.dart';
import '../utils/shared_preferences_utils.dart';
import '../utils/time_utils.dart';

class BusTimingRow extends StatefulWidget {
  const BusTimingRow(this.busStopCode, this.busInfo, {Key key})
      : super(key: key);

  final dynamic busInfo;
  final String busStopCode;

  @override
  _BusTimingState createState() {
    return _BusTimingState();
  }
}

class _BusTimingState extends State<BusTimingRow> {
  bool _isBusFollowed = false;
  String busCode;

  @override
  void initState() {
    super.initState();
    busCode = widget.busInfo['ServiceNo'];
    isBusFollowed(stop: widget.busStopCode, bus: busCode)
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
      onTap: () {
        // TODO(jeffsieu): Do something with bus row is tapped (maybe open bus service page).
      },
      child: Container(
        child: CustomPaint(
//          painter: TrapeziumPainter(
//              BusUtils.getOperatorColor(widget.busInfo['Operator'])),
          child: Container(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Text(
                        busCode + ' '*(4-busCode.length),
                        style: Theme.of(context).textTheme.title.copyWith(fontFamily: 'B612 Mono'),
                      ),
                    ),
                    _BusTimingItem(
                        widget.busInfo['NextBus']['EstimatedArrival'],
                        widget.busInfo['NextBus']['Type'],
                        widget.busInfo['NextBus']['Load'],
                        key: Key('${widget.busStopCode} $busCode 1')
                    ),
                    _BusTimingItem(
                        widget.busInfo['NextBus2']['EstimatedArrival'],
                        widget.busInfo['NextBus2']['Type'],
                        widget.busInfo['NextBus2']['Load'],
                        key: Key('${widget.busStopCode} $busCode 2')
                    ),
                    _BusTimingItem(
                        widget.busInfo['NextBus3']['EstimatedArrival'],
                        widget.busInfo['NextBus3']['Type'],
                        widget.busInfo['NextBus3']['Load'],
                        key: Key('${widget.busStopCode} $busCode 3')
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Notify me when the bus arrives',
                  icon: Icon(_isBusFollowed
                      ? Icons.notifications_active
                      : Icons.notifications_none),
                  onPressed: () {
                    if (_isBusFollowed) {
                      unfollowBus(stop: widget.busStopCode, bus: busCode);
                    } else {
                      BusFollowStatusListener listener;
                      listener = (String stop, String code, bool isFollowed) {
                        if (stop == widget.busStopCode &&
                            code == busCode &&
                            !isFollowed) {
                          setState(() {
                            _isBusFollowed = !_isBusFollowed;
                          });

                          removeBusFollowStatusListener(widget.busStopCode, busCode, listener);
                        }
                      };

                      addBusFollowStatusListener(widget.busStopCode, busCode, listener);

                      final DateTime estimatedArrivalTime = DateTime.parse(widget.busInfo['NextBus']['EstimatedArrival']);
                      final DateTime notificationTime = estimatedArrivalTime.subtract(const Duration(seconds: 30));

                      followBus(stop: widget.busStopCode, bus: busCode);
                      final SnackBar snackBar = SnackBar(content: Text('You will be notified when $busCode arrives'));

                      Scaffold.of(context).showSnackBar(snackBar);
                      // Add notification timer
                      NotificationAPI().scheduleNotification(widget.busStopCode, busCode, notificationTime);

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
        ),
      ),
    );
  }
}

class _BusTimingItem extends StatefulWidget {
  const _BusTimingItem(this.timeArrival, this.busSize, this.busLoad, {Key key}) : super(key: key);

  static const double boxSize = 56.0;
  static const double paddingLeft = 4.0;
  static const double paddingBottom = 4.0;
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
        getMinutesFromNow(widget.timeArrival) < 3)
      _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.timeArrival.isEmpty) {
      return Container(
          width: _BusTimingItem.boxSize + _BusTimingItem.paddingLeft);
    }

    final Color busLoadColor = getBusLoadColor(widget.busLoad, Brightness.light);
    const double offset = 0.5;
    return FittedBox(
      fit: BoxFit.fitHeight,
        child:
          Stack(
            alignment: Alignment.bottomCenter,
            children: <Widget>[
            AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget child) => Container(
                    width: _BusTimingItem.boxSize,
                    height: _BusTimingItem.boxSize,
                    color: Color.lerp(busLoadColor, busLoadColor.withOpacity(0.5), _controller.value),
                  ),
            ),
            Text.rich(
              TextSpan(
                text: getBusTypeVerbose(widget.busSize),
                style: Theme.of(context).textTheme.overline.copyWith(shadows: <Shadow>[
                  Shadow( // bottomLeft
                      offset: const Offset(-offset, -offset),
                      color: Theme.of(context).canvasColor,
                  ),
                  Shadow( // bottomRight
                      offset: const Offset(offset, -offset),
                    color: Theme.of(context).canvasColor,
                  ),
                  Shadow( // topRight
                      offset: const Offset(offset, offset),
                    color: Theme.of(context).canvasColor,
                  ),
                  Shadow( // topLeft
                      offset: const Offset(-offset, offset),
                    color: Theme.of(context).canvasColor,
                  ),
                ],
                ),
              ),
              maxLines: 1,
            ),
            Container(
              width: _BusTimingItem.boxSize,
              height: _BusTimingItem.boxSize,
              padding: const EdgeInsets.all(8.0),
              child: FittedBox(
                fit: BoxFit.contain,
                  child: Text(
                    widget.timeArrival.isNotEmpty
                        ? getBusTimingShortened(
                        getMinutesFromNow(widget.timeArrival))
                        : '',
                    style: Theme.of(context).textTheme.body1.copyWith(color: Colors.white)),
              ),
            ),
          ]),
        );
  }
}

class TrapeziumPainter extends CustomPainter {
  TrapeziumPainter(this.color);

  Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = Path();

    path.moveTo(0, 0);
    path.lineTo(size.width / 2, 0);
    path.lineTo(size.width / 2 - size.height, size.height);
    path.lineTo(0, size.height);

    final Paint paint = Paint();
    paint..color = color;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
