import 'package:flutter/material.dart';

import '../utils/bus_api.dart';
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
                return _messageBox(BusAPI.kNoInternetError);
                case ConnectionState.active:
                case ConnectionState.waiting:
                  if (snapshot.data == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
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

  Widget _messageBox(String text) {
    return SliverToBoxAdapter(
      child: Center(
        child: Text(text),
      ),
    );
  }
}