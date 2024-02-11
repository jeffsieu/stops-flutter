import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bus_stop_with_pinned_services.dart';
import '../models/user_route.dart';
import '../utils/bus_api.dart';
import '../utils/database_utils.dart';
import '../utils/reorder_status_notification.dart';
import '../widgets/bus_stop_overview_item.dart';
import 'edit_model.dart';

class BusStopOverviewList extends StatelessWidget {
  const BusStopOverviewList({Key? key, required this.routeId})
      : super(key: key);

  final int routeId;

  @override
  Widget build(BuildContext context) {
    final rootContext = context;
    final _isEditing = context.watch<EditModel>().isEditing;

    return StreamBuilder<StoredUserRoute>(
        initialData: null,
        stream: routeStream(routeId),
        builder:
            (BuildContext context, AsyncSnapshot<StoredUserRoute> snapshot) {
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
              if (snapshot.hasData) {
                if (snapshot.data?.busStops.isEmpty ?? true) {
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
                  /// ToDO: handle this
                  // _busStops = snapshot.data!;
                }
              }
              return Provider<StoredUserRoute>(
                create: (_) => snapshot.data!,
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    buildDefaultDragHandles: false,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.busStops.length,
                    onReorderStart: (int position) {
                      ReorderStatusNotification(true).dispatch(context);
                    },
                    onReorder: (
                      int oldIndex,
                      int newIndex,
                    ) async {
                      ReorderStatusNotification(false).dispatch(context);

                      // setState(() {
                      //   _busStops
                      //     ..clear()
                      //     ..addAll(newBusStops);
                      // });
                      await moveBusStopPositionInRoute(
                          oldIndex, newIndex, context.read<StoredUserRoute>());
                      // setState(() {});
                    },
                    itemBuilder: (BuildContext context, int position) {
                      final busStop = snapshot.data!.busStops[position];
                      final Widget busStopItem = BusStopOverviewItem(
                        busStop,
                        key: Key(busStop.code +
                            hashList(busStop.pinnedServices).toString()),
                      );

                      return Stack(
                        key: Key(busStop.hashCode.toString()),
                        alignment: Alignment.centerLeft,
                        children: [
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
                                  ? ReorderableDragStartListener(
                                      index: position,
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
                                  children: [
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
                                                  kDefaultRouteId,
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
                      );
                    },
                  ),
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
