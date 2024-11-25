import 'package:flutter/material.dart';

import 'package:stops_sg/bus_api/models/bus_service_arrival_result.dart';
import 'package:stops_sg/utils/bus_utils.dart';
import 'package:stops_sg/widgets/bus_type_icon.dart';

class BusStopLegendCard extends StatelessWidget {
  const BusStopLegendCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  color: Theme.of(context).textTheme.headlineMedium!.color),
              Container(width: 16.0),
              Text('Legend', style: Theme.of(context).textTheme.headlineMedium),
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
                  color: getBusLoadColor(BusLoad.low, theme),
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
                  color: getBusLoadColor(BusLoad.medium, theme),
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
                  color: getBusLoadColor(BusLoad.high, theme),
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
                  child: BusTypeIcon.bendy(
                    width: 24.0,
                    height: 24.0,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
              const Text('Bendy'),
            ],
          ),
          Row(
            children: [
              Container(
                width: 48,
                margin: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: BusTypeIcon.double(
                    width: 24.0,
                    height: 24.0,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
              const Text('Double-decker'),
            ],
          ),
          Row(
            children: [
              Container(
                width: 48,
                margin: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: Icon(
                    Icons.not_accessible_rounded,
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ),
              const Text('Wheelchair-inaccessible'),
            ],
          ),
        ],
      ),
    );
  }
}
