import 'package:flutter/material.dart';

import '../utils/bus_stop.dart';
import '../utils/database_utils.dart';
import '../widgets/bus_stop_overview_item.dart';

class BusStopOverviewList extends StatefulWidget {
  @override
  State createState() {
    return BusStopOverviewListState();
  }
}

class BusStopOverviewListState extends State<BusStopOverviewList> {
  List<BusStop> _busStops = <BusStop>[];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BusStop>>(
        initialData: _busStops,
        future: getStarredBusStops(),
        builder: (BuildContext context, AsyncSnapshot<List<BusStop>> snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.none:
                return const SliverToBoxAdapter(child: Center(child: Text('Error')));
              case ConnectionState.active:
                return const SliverToBoxAdapter(child: Center(child: Text('Active')));
              case ConnectionState.waiting:
                if (snapshot.data == null)
                  return const SliverToBoxAdapter(child: Center(child: Text('Loading buses...')));
                continue done;
              done:
              case ConnectionState.done:
                _busStops = snapshot.data;
                List<BusStop> busStopList;
                if (snapshot.hasData)
                  busStopList = _busStops;
                else
                  busStopList = <BusStop>[];
                return SliverToBoxAdapter(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (BuildContext context, int position) {
                        final BusStop busStop = busStopList[position];
                        return BusStopOverviewItem(busStop, key: Key(busStop.code));
                      },
                      itemCount: busStopList.length,
                      separatorBuilder: (BuildContext context, int position) => const Divider(height: 1),
                    ),
                  ),
                );
            }
            return null;
          }
    );
  }
}