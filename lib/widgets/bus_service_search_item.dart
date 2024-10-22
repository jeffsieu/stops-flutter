import 'package:flutter/material.dart';

import 'package:stops_sg/bus_api/models/bus_service.dart';
import 'package:stops_sg/widgets/highlighted_icon.dart';

class BusServiceSearchItem extends StatelessWidget {
  const BusServiceSearchItem(
      {super.key, required this.busService, this.onTap, this.opacity = 1});

  final BusService busService;
  final void Function()? onTap;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
        borderRadius: const BorderRadius.all(
          Radius.circular(8.0),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
        horizontalTitleGap: 8.0,
        leading: HighlightedIcon(
          iconColor: BusService.listColor(context),
          child: Icon(
            Icons.directions_bus_rounded,
            color: BusService.listColor(context),
          ),
          opacity: opacity,
        ),
        title: Text(busService.number,
            style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
