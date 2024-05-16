import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/widgets/highlighted_icon.dart';

class BusStopSearchItem extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final isInRoute = ref
            .watch(isBusStopInRouteProvider(
                busStop: busStop, routeId: kDefaultRouteId))
            .valueOrNull ??
        false;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      onTap: onTap,
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
                colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.primary, BlendMode.srcIn),
              ),
            ),
            if (distance.isNotEmpty)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    distance,
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
              text: nameStart,
              style: Theme.of(context).textTheme.titleMedium,
              children: <TextSpan>[
                TextSpan(
                  text: nameBold,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
                TextSpan(text: nameEnd),
              ],
            ),
            maxLines: 1,
          ),
          AutoSizeText.rich(
            TextSpan(
              text: codeStart,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall!
                  .copyWith(color: Theme.of(context).hintColor),
              children: <TextSpan>[
                TextSpan(
                  text: codeBold,
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                ),
                TextSpan(text: codeEnd),
                TextSpan(text: ' · ${busStop.road}'),
              ],
            ),
            maxLines: 1,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
      trailing: isMapEnabled
          ? IconButton(
              tooltip: 'Show on map',
              icon: Icon(
                Icons.my_location_rounded,
                color: Theme.of(context).hintColor,
              ),
              onPressed: onShowOnMapTap,
            )
          : PopupMenuButton<String>(
              tooltip: 'More',
              icon: Icon(Icons.more_vert_rounded,
                  color: Theme.of(context).hintColor),
              onSelected: (String item) {
                if (item == 'Pin') {
                  if (isInRoute) {
                    ref
                        .read(savedUserRouteProvider(id: kDefaultRouteId)
                            .notifier)
                        .removeBusStop(busStop);
                  } else {
                    ref
                        .read(savedUserRouteProvider(id: kDefaultRouteId)
                            .notifier)
                        .addBusStop(busStop);
                  }
                } else if (item == 'Show on map') {
                  onShowOnMapTap();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
                PopupMenuItem<String>(
                  value: 'Pin',
                  child: Text(
                    isInRoute ? 'Unpin from home' : 'Pin to home',
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
