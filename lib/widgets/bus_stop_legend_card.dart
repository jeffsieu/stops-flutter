import 'package:flutter/material.dart';

import '../utils/bus_service_arrival_result.dart';
import '../utils/bus_utils.dart';

class BusStopLegendCard extends StatelessWidget {
  const BusStopLegendCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = MediaQuery.of(context).platformBrightness;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
        borderRadius: const BorderRadius.all(
          Radius.circular(16.0),
        ),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        direction: Axis.vertical,
        spacing: 16,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Theme.of(context).textTheme.headline4!.color),
              Container(width: 16.0),
              Text('Legend', style: Theme.of(context).textTheme.headline4),
            ],
          ),
          Row(
            children: [
              Container(
                width: 48,
                height: 16,
                margin: const EdgeInsets.only(right: 16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: getBusLoadColor(BusLoad.low, brightness),
                ),
              ),
              const Text('Many seats'),
            ],
          ),
          Row(
            children: [
              Container(
                width: 48,
                height: 16,
                margin: const EdgeInsets.only(right: 16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: getBusLoadColor(BusLoad.medium, brightness),
                ),
              ),
              const Text('Some seats'),
            ],
          ),
          Row(
            children: [
              Container(
                width: 48,
                height: 16,
                margin: const EdgeInsets.only(right: 16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: getBusLoadColor(BusLoad.high, brightness),
                ),
              ),
              const Text('Few seats'),
            ],
          ),
          Row(
            children: [
              Container(
                width: 48,
                margin: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: Text(
                    getBusTypeVerbose(BusType.double),
                    style: Theme.of(context).textTheme.headline4,
                  ),
                ),
              ),
              const Text('Double-decker/Long'),
            ],
          ),
        ],
      ),
    );
  }
}
