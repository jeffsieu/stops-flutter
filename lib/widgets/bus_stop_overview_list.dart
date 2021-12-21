import 'package:flutter/material.dart';
import 'package:implicitly_animated_reorderable_list/implicitly_animated_reorderable_list.dart';
import 'package:provider/provider.dart';

import '../models/bus_stop_with_pinned_services.dart';
import '../models/user_route.dart';
import '../utils/bus_api.dart';
import '../utils/database_utils.dart';
import '../utils/reorder_status_notification.dart';
import '../widgets/bus_stop_overview_item.dart';
import 'edit_model.dart';

class BusStopOverviewList extends StatefulWidget {
  const BusStopOverviewList({Key? key}) : super(key: key);

  @override
  State createState() {
    return BusStopOverviewListState();
  }
}

class BusStopOverviewListState extends State<BusStopOverviewList> {
  List<BusStopWithPinnedServices>? _busStops;

  @override
  Widget build(BuildContext context) {
    final BuildContext rootContext = context;
    final bool _isEditing = context.watch<EditModel>().isEditing;

    return StreamBuilder<List<BusStopWithPinnedServices>>(
        initialData: _busStops,
        stream: routeBusStopsStream(context.watch<UserRoute>()),
        builder: (BuildContext context,
            AsyncSnapshot<List<BusStopWithPinnedServices>> snapshot) {
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
                if (snapshot.data?.isEmpty ?? true) {
                  return Container(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                          'Pinned bus stops appear here.\n\nTap the pin next to a bus stop to pin it.\n\n\nAdd a route to organize multiple bus stops together.',
                          style: Theme.of(context)
                              .textTheme
                              .headline4!
                              .copyWith(color: Theme.of(context).hintColor)),
                    ),
                  );
                } else {
                  // Only update list when database is updated, otherwise the list is updated with old positions
                  _busStops = snapshot.data!;
                }
              }
              return MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: ImplicitlyAnimatedReorderableList<
                    BusStopWithPinnedServices>(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  items: snapshot.data!,
                  areItemsTheSame: (BusStopWithPinnedServices busStop,
                          BusStopWithPinnedServices otherBusStop) =>
                      busStop.code == otherBusStop.code,
                  onReorderStarted:
                      (BusStopWithPinnedServices busStop, int position) {
                    ReorderStatusNotification(true).dispatch(context);
                  },
                  onReorderFinished: (BusStopWithPinnedServices busStop,
                      int from,
                      int to,
                      List<BusStopWithPinnedServices> newBusStops) async {
                    ReorderStatusNotification(false).dispatch(context);
                    if (from == to) {
                      return;
                    }
                    // setState(() {
                    //   _busStops
                    //     ..clear()
                    //     ..addAll(newBusStops);
                    // });
                    await moveBusStopPositionInRoute(
                        from, to, context.read<UserRoute>());
                    // setState(() {});
                  },
                  itemBuilder: (BuildContext context,
                      Animation<double> itemAnimation,
                      BusStopWithPinnedServices busStop,
                      int position) {
                    final Widget busStopItem = BusStopOverviewItem(
                      busStop,
                      key: Key(busStop.code +
                          hashList(busStop.pinnedServices).toString()),
                    );

                    return Reorderable(
                      key: Key(busStop.hashCode.toString()),
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: <Widget>[
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: busStopItem,
                          ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 600),
                            opacity: _isEditing ? 1.0 : 0.0,
                            curve: const Interval(0.5, 1),
                            child: AnimatedSlide(
                              duration: const Duration(milliseconds: 600),
                              offset: _isEditing
                                  ? Offset.zero
                                  : const Offset(0, 0.25),
                              curve: const Interval(0.5, 1,
                                  curve: Curves.easeOutCubic),
                              child: _isEditing
                                  ? Handle(
                                      child: Padding(
                                        padding:
                                            const EdgeInsetsDirectional.only(
                                                start: 32.0),
                                        child: Icon(
                                          Icons.drag_handle_rounded,
                                          color: Theme.of(context).hintColor,
                                        ),
                                      ),
                                    )
                                  : Container(),
                            ),
                          ),
                          Positioned.fill(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 17.0,
                                  vertical:
                                      9.0), // Offset by 1 to account for outline
                              child: Material(
                                type: MaterialType.transparency,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: <Widget>[
                                    AnimatedOpacity(
                                      duration:
                                          const Duration(milliseconds: 600),
                                      opacity: _isEditing ? 1.0 : 0.0,
                                      curve: _isEditing
                                          ? const Interval(0.5, 1)
                                          : const Interval(0, 0.25),
                                      child: AnimatedSlide(
                                        duration:
                                            const Duration(milliseconds: 600),
                                        offset: _isEditing
                                            ? Offset.zero
                                            : const Offset(0, 0.25),
                                        curve: _isEditing
                                            ? const Interval(0.5, 1,
                                                curve: Curves.easeOutCubic)
                                            : const Interval(0, 0.5,
                                                curve: Curves.easeOutCubic),
                                        child: Padding(
                                          padding:
                                              const EdgeInsetsDirectional.only(
                                                  end: 8.0),
                                          child: IconButton(
                                            onPressed: () async {
                                              await removeBusStopFromRoute(
                                                  busStop,
                                                  UserRoute.home,
                                                  rootContext);
                                            },
                                            icon: Icon(
                                              Icons.clear_rounded,
                                              color:
                                                  Theme.of(context).hintColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
          }
        });
  }

  Widget _messageBox(String text) {
    return SliverToBoxAdapter(
      child: Center(
        child: Text(text),
      ),
    );
  }
}
