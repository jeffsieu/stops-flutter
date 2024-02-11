import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/bus_stop.dart';
import '../utils/database_utils.dart';
import '../widgets/highlighted_icon.dart';

class BusStopSearchItem extends StatefulWidget {
  const BusStopSearchItem({
    required Key key,
    required this.codeStart,
    required this.codeBold,
    required this.codeEnd,
    required this.nameStart,
    required this.nameBold,
    required this.nameEnd,
    required this.distance,
    required this.busStop,
    required this.isMapEnabled,
    required this.onShowOnMapTap,
    this.onTap,
  }) : super(key: key);

  final String codeStart;
  final String codeBold;
  final String codeEnd;
  final String nameStart;
  final String nameBold;
  final String nameEnd;
  final String distance;
  final BusStop busStop;
  final bool isMapEnabled;
  final void Function()? onTap;
  final void Function() onShowOnMapTap;

  @override
  State<StatefulWidget> createState() {
    return BusStopSearchItemState();
  }
}

class BusStopSearchItemState extends State<BusStopSearchItem>
    with SingleTickerProviderStateMixin {
  bool _isStarEnabled = false;

  @override
  void initState() {
    super.initState();
    isBusStopInRouteWithId(widget.busStop, kDefaultRouteId)
        .then((bool contains) {
      if (mounted) {
        setState(() {
          _isStarEnabled = contains;
        });
      }
    });
    // _busStopListener = (BusStop busStop) {
    //   isBusStopInRouteWithId(widget.busStop, defaultRouteId).then((bool contains) {
    //     if (mounted) {
    //       setState(() {
    //         _isStarEnabled = contains;
    //       });
    //     }
    //   });
    // };
    // registerBusStopListener(widget.busStop, _busStopListener);
  }

  @override
  void dispose() {
    // unregisterBusStopListener(widget.busStop, _busStopListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      onTap: widget.onTap,
      leading: SizedBox(
        width: 48.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            HighlightedIcon(
              iconColor: Theme.of(context).colorScheme.primary,
              child: SvgPicture.asset(
                'assets/images/bus-stop.svg',
                width: 24.0,
                height: 24.0,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            if (widget.distance.isNotEmpty)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.distance,
                    softWrap: false,
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AutoSizeText.rich(
            TextSpan(
              text: widget.nameStart,
              style: Theme.of(context).textTheme.titleMedium,
              children: <TextSpan>[
                TextSpan(
                  text: widget.nameBold,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
                TextSpan(text: widget.nameEnd),
              ],
            ),
            maxLines: 1,
          ),
          AutoSizeText.rich(
            TextSpan(
              text: widget.codeStart,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(color: Theme.of(context).hintColor),
              children: <TextSpan>[
                TextSpan(
                  text: widget.codeBold,
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
                TextSpan(text: widget.codeEnd),
                TextSpan(text: ' · ${widget.busStop.road}'),
              ],
            ),
            maxLines: 1,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
      trailing: widget.isMapEnabled
          ? IconButton(
              tooltip: 'Show on map',
              icon: Icon(
                Icons.my_location_rounded,
                color: Theme.of(context).hintColor,
              ),
              onPressed: widget.onShowOnMapTap,
            )
          : PopupMenuButton<String>(
              tooltip: 'More',
              icon: Icon(Icons.more_vert_rounded,
                  color: Theme.of(context).hintColor),
              onSelected: (String item) {
                if (item == 'Pin') {
                  setState(() {
                    _isStarEnabled = !_isStarEnabled;
                  });
                  if (_isStarEnabled) {
                    addBusStopToRouteWithId(
                        widget.busStop, kDefaultRouteId, context);
                  } else {
                    removeBusStopFromRoute(
                        widget.busStop, kDefaultRouteId, context);
                  }
                } else if (item == 'Show on map') {
                  widget.onShowOnMapTap();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
                PopupMenuItem<String>(
                  value: 'Pin',
                  child: Text(
                    _isStarEnabled ? 'Unpin from home' : 'Pin to home',
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Show on map',
                  child: Text('Show on map'),
                ),
              ],
            ),
    );
  }
}
