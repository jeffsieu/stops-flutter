import 'package:flutter/material.dart';

import 'package:implicitly_animated_reorderable_list/implicitly_animated_reorderable_list.dart';
import 'package:implicitly_animated_reorderable_list/transitions.dart';

import '../utils/bus_api.dart';
import '../utils/bus_stop.dart';
import '../utils/database_utils.dart';
import '../utils/reorder_status_notification.dart';
import '../utils/user_route.dart';
import '../widgets/bus_stop_overview_item.dart';
import '../widgets/custom_handle.dart';
import '../widgets/route_model.dart';

class BusStopOverviewList extends StatefulWidget {
  @override
  State createState() {
    return BusStopOverviewListState();
  }
}

class BusStopOverviewListState extends State<BusStopOverviewList> {
  List<BusStop> _busStops;

  @override
  void initState() {
    super.initState();
    _busStops = <BusStop>[];
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BusStop>>(
      stream: routeBusStopsStream(UserRoute.home),
      builder: (BuildContext context, AsyncSnapshot<List<BusStop>> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            return _messageBox(BusAPI.kNoInternetError);
            case ConnectionState.waiting:
              if (snapshot.data == null) {
                return const Center(child: CircularProgressIndicator());
              }
            continue done;
            done:
          case ConnectionState.active:
          case ConnectionState.done:
            if (snapshot.hasData && _busStops != snapshot.data) {
              if (snapshot.data.isEmpty)
                return Container(
                  padding: const EdgeInsets.all(32.0),
                  child: Center(
                    child: Text('Pinned bus stops appear here.\n\nTap the star next to a bus stop to pin it.\n\n\nAdd a route to organize multiple bus stops together.', style: Theme.of(context).textTheme.headline4.copyWith(color: Theme.of(context).hintColor)),
                  ),
                );
              else {
                // Only update list when database is updated, otherwise the list is updated with old positions
                _busStops..clear()..addAll(snapshot.data);
              }
            }
            return MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: ImplicitlyAnimatedReorderableList<BusStop>(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                items: _busStops,
                areItemsTheSame: (BusStop busStop, BusStop otherBusStop) => busStop == otherBusStop,
                onReorderStarted: (BusStop busStop, int position) {
                  ReorderStatusNotification(true).dispatch(context);
                },
                onReorderFinished: (BusStop busStop, int from, int to, List<BusStop> newBusStops) async {
                  ReorderStatusNotification(false).dispatch(context);
                  _busStops..clear()..addAll(newBusStops);
                  await moveBusStopPositionInRoute(from, to, RouteModel.of(context).route);
                  setState(() {});
                },
                itemBuilder: (BuildContext context, Animation<double> itemAnimation, BusStop busStop, int position) {
                  return Reorderable(
                    key: Key(busStop.code),
                    builder: (BuildContext context, Animation<double> dragAnimation, bool inDrag) {
                      const double initialElevation = 0.0;
                      final Color materialColor = Color.lerp(Theme.of(context).scaffoldBackgroundColor, Colors.white, dragAnimation.value / 10);
                      final double elevation = Tween<double>(begin: initialElevation, end: 10.0).animate(CurvedAnimation(parent: dragAnimation, curve: Curves.easeOutCubic)).value;

                      Widget busStopItem = BusStopOverviewItem(busStop, key: Key(busStop.code));

                      if (position > 0)
                        busStopItem = Column(
                          children: <Widget>[
                            Divider(height: 1 - dragAnimation.value),
                            busStopItem,
                          ],
                        );

                      final Widget child = CustomHandle(
                        delay: const Duration(milliseconds: 500),
                        child: Material(
                          color: materialColor,
                          elevation: elevation,
                          child: busStopItem,
                        ),
                      );

                      if (dragAnimation.value > 0.0)
                        return child;

                      return SizeFadeTransition(
                        sizeFraction: 0.75,
                        curve: Curves.easeInOut,
                        animation: itemAnimation,
                        child: child,
                      );
                    },
                  );
                },
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