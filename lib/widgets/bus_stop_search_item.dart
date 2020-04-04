import 'package:meta/meta.dart';

import 'package:flutter/material.dart';

import '../utils/bus_stop.dart';
import '../utils/database_utils.dart';
import '../utils/user_route.dart';

class BusStopSearchItem extends StatefulWidget {
  const BusStopSearchItem({
    @required Key key,
    @required this.codeStart,
    @required this.codeBold,
    @required this.codeEnd,
    @required this.nameStart,
    @required this.nameBold,
    @required this.nameEnd,
    @required this.distance,
    @required this.busStop,
    this.onTap
  }) : super (key: key);

  final String codeStart;
  final String codeBold;
  final String codeEnd;
  final String nameStart;
  final String nameBold;
  final String nameEnd;
  final String distance;
  final BusStop busStop;
  final Function onTap;

  @override
  State<StatefulWidget> createState() {
    return BusStopSearchItemState();
  }
}

class BusStopSearchItemState extends State<BusStopSearchItem> with SingleTickerProviderStateMixin {
  bool _isStarEnabled = false;

  BusStopChangeListener _busStopListener;

  @override
  void initState() {
    super.initState();
    isBusStopInRoute(widget.busStop, UserRoute.home).then((bool contains) {
      if (mounted)
        setState(() {
          _isStarEnabled = contains;
        });
    });
    _busStopListener = (BusStop busStop) {
      isBusStopInRoute(widget.busStop, UserRoute.home).then((bool contains) {
        if (mounted)
          setState(() {
            _isStarEnabled = contains;
          });
      });
    };
    registerBusStopListener(widget.busStop, _busStopListener);
  }

  @override
  void dispose() {
    unregisterBusStopListener(widget.busStop, _busStopListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: widget.onTap,
      leading: Text(widget.distance),
      title: RichText(
        text: TextSpan(
          text: widget.nameStart,
          style: Theme.of(context)
              .textTheme
              .title
              .copyWith(fontWeight: FontWeight.normal),
          children: <TextSpan>[
            TextSpan(
                text: widget.nameBold,
                style: Theme.of(context).textTheme.title.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Theme.of(context).textTheme.body1.color,
                  background: Paint()
                    ..color =
                        Theme.of(context).highlightColor,
                )),
            TextSpan(
                text: widget.nameEnd),
          ],
        ),
      ),
      subtitle: RichText(
        text: TextSpan(
          text: widget.codeStart,
          style: Theme.of(context)
              .textTheme
              .subtitle
              .copyWith(fontWeight: FontWeight.normal),
          children: <TextSpan>[
            TextSpan(
                text: widget.codeBold,
                style: Theme.of(context).textTheme.subtitle.copyWith(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Theme.of(context).textTheme.body1.color,
                  background: Paint()
                    ..color =
                        Theme.of(context).highlightColor,
                )),
            TextSpan(
                text: widget.codeEnd),
          ],
        ),
      ),
      trailing: IconButton(
        icon: Icon(_isStarEnabled ? Icons.star : Icons.star_border),
        tooltip: _isStarEnabled ? 'Unpin from home' : 'Pin to home',
        onPressed: () {
          setState(() {
            _isStarEnabled = !_isStarEnabled;
          });
          if (_isStarEnabled) {
            addBusStopToRoute(widget.busStop, UserRoute.home);
          } else {
            removeBusStopFromRoute(widget.busStop, UserRoute.home);
          }
        },
      ),
    );
  }
}