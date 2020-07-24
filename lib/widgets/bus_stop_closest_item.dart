import 'package:flutter/material.dart';

import '../models/bus_stop.dart';
import 'bus_stop_overview_item.dart';

class BusStopClosestItem extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return BusStopClosestItemState();
  }
}

class BusStopClosestItemState extends State<BusStopClosestItem> {
  BusStop busStop;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: <Widget>[
          Text('NEAREST BUS STOP', style: Theme.of(context).textTheme.headline6),
          BusStopOverviewItem(busStop, key: Key(busStop.code)),
        ],
      )
    );
  }
}