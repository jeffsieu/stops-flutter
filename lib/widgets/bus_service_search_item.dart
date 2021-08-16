

import 'package:flutter/material.dart';

import '../models/bus_service.dart';
import '../widgets/highlighted_icon.dart';

class BusServiceSearchItem extends StatelessWidget {
  const BusServiceSearchItem({Key? key, required this.busService, this.onTap})
      : super(key: key);

  final BusService busService;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24.0),
      leading: HighlightedIcon(
        iconColor: BusService.listColor(context),
        child: Icon(Icons.directions_bus, color: BusService.listColor(context)),
      ),
      title:
          Text(busService.number, style: Theme.of(context).textTheme.headline6),
    );
  }
}
