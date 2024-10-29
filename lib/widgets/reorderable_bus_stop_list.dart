import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:provider/provider.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/widgets/bus_stop_overview_item.dart';
import 'package:stops_sg/widgets/edit_model.dart';

class ReorderableBusStopList extends ConsumerWidget {
  const ReorderableBusStopList({
    super.key,
    required this.busStops,
    required this.isEditing,
    required this.onBusStopRemoved,
    this.onReorderStart,
    this.onReorderEnd,
    this.onReorder,
  });

  final List<BusStop> busStops;
  final bool isEditing;
  final Function(BusStop busStop) onBusStopRemoved;
  final Function(int position)? onReorderStart;
  final Function(int position)? onReorderEnd;
  final Function(int oldIndex, int newIndex)? onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ReorderableListView.builder(
        shrinkWrap: true,
        buildDefaultDragHandles: false,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: busStops.length,
        proxyDecorator: (child, index, animation) => child,
        onReorderStart: onReorderStart,
        onReorderEnd: onReorderEnd,
        onReorder: (
          int oldIndex,
          int newIndex,
        ) async {
          if (oldIndex < newIndex) {
            // See: https://api.flutter.dev/flutter/widgets/ReorderCallback.html
            // removing the item at oldIndex will shorten the list by 1.
            newIndex -= 1;
          }

          onReorder?.call(oldIndex, newIndex);
        },
        itemBuilder: (BuildContext context, int position) {
          final busStop = busStops[position];
          final Widget busStopItem = ProxyProvider(
            update: (context, value, previous) =>
                EditModel(isEditing: isEditing),
            child: BusStopOverviewItem(
              busStop,
              key: Key(busStop.code),
            ),
          );

          return Stack(
            key: Key(busStop.hashCode.toString()),
            alignment: Alignment.centerLeft,
            children: [
              busStopItem,
              AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: isEditing ? 1.0 : 0.0,
                curve: const Interval(0.5, 1),
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 600),
                  offset: isEditing ? Offset.zero : const Offset(0, 0.25),
                  curve: const Interval(0.5, 1, curve: Curves.easeOutCubic),
                  child: isEditing
                      ? ReorderableDragStartListener(
                          index: position,
                          child: Padding(
                            padding:
                                const EdgeInsetsDirectional.only(start: 16.0),
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
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 600),
                          opacity: isEditing ? 1.0 : 0.0,
                          curve: isEditing
                              ? const Interval(0.5, 1)
                              : const Interval(0, 0.25),
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 600),
                            offset:
                                isEditing ? Offset.zero : const Offset(0, 0.25),
                            curve: isEditing
                                ? const Interval(0.5, 1,
                                    curve: Curves.easeOutCubic)
                                : const Interval(0, 0.5,
                                    curve: Curves.easeOutCubic),
                            child: Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(end: 8.0),
                              child: IconButton(
                                onPressed: () => onBusStopRemoved(busStop),
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: Theme.of(context).hintColor,
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
    );
  }
}
