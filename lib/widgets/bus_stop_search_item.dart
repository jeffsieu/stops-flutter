import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/widgets/bus_stop_item.dart';

class BusStopSearchItem extends ConsumerWidget {
  const BusStopSearchItem({
    required Key key,
    required this.codeStart,
    required this.codeBold,
    required this.codeEnd,
    required this.nameStart,
    required this.nameBold,
    required this.nameEnd,
    required this.busStop,
    required this.isMapEnabled,
    required this.onShowOnMapTap,
    this.onTap,
    this.defaultExpanded,
  }) : super(key: key);

  final String codeStart;
  final String codeBold;
  final String codeEnd;
  final String nameStart;
  final String nameBold;
  final String nameEnd;
  final BusStop busStop;
  final bool isMapEnabled;
  final void Function()? onTap;
  final void Function() onShowOnMapTap;
  final bool? defaultExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInRoute = ref
            .watch(isBusStopInRouteProvider(
                busStop: busStop, routeId: kDefaultRouteId))
            .value ??
        false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: BusStopItem(
        busStop,
        onTap: onTap,
        defaultExpanded: defaultExpanded,
      ),
    );
  }
}
