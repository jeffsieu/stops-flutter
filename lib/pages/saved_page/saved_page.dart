import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:location/location.dart';
import 'package:provider/provider.dart' hide Consumer;
import 'package:stops_sg/bus_api/bus_api.dart';
import 'package:stops_sg/bus_api/models/bus.dart';
import 'package:stops_sg/bus_stop_sheet/bloc/bus_stop_sheet_bloc.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/location/location.dart';
import 'package:stops_sg/main.dart';
import 'package:stops_sg/utils/database/followed_buses.dart';
import 'package:stops_sg/utils/reorder_status_notification.dart';
import 'package:stops_sg/utils/time_utils.dart';
import 'package:stops_sg/widgets/bus_stop_overview_list.dart';
import 'package:stops_sg/widgets/edit_model.dart';

class SavedPage extends ConsumerStatefulWidget {
  const SavedPage({super.key});

  @override
  SavedPageState createState() => SavedPageState();

  static SavedPageState? of(BuildContext context) =>
      context.findAncestorStateOfType<SavedPageState>();
}

class SavedPageState extends ConsumerState<SavedPage> {
  bool _isEditing = false;
  List<Bus> get _followedBuses =>
      ref.watch(followedBusesProvider).valueOrNull ?? [];
  bool canScroll = true;
  bool get hasLocationPermissions => ref.watch(userLocationProvider
      .select((value) => value.valueOrNull?.hasPermission ?? false));
  LocationData? get locationData => ref
      .watch(userLocationProvider.select((value) => value.valueOrNull?.data));

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleOf(context));

    return Provider<EditModel>(
      create: (_) => const EditModel(isEditing: false),
      child: NotificationListener<ReorderStatusNotification>(
        onNotification: (ReorderStatusNotification notification) {
          setState(() {
            canScroll = !notification.isReordering;
          });

          return true;
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text('Saved'),
            actions: [
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                firstChild: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: Theme.of(context).hintColor),
                  itemBuilder: (BuildContext context) {
                    return <PopupMenuItem<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Edit stops'),
                      ),
                    ];
                  },
                  onSelected: (String value) {
                    if (value == 'edit') {
                      setState(() {
                        _isEditing = true;
                      });
                    }
                  },
                ),
                secondChild: IconButton(
                    icon: const Icon(Icons.done_rounded),
                    tooltip: 'Save',
                    color: Theme.of(context).colorScheme.secondary,
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                      });
                    }),
                crossFadeState: _isEditing
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
              ),
            ],
          ),
          body: ListView(
            children: _buildHomeItems(),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackedBuses() {
    final hasTrackedBuses = _followedBuses.isNotEmpty;

    return AnimatedSize(
      alignment: Alignment.topCenter,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: hasTrackedBuses ? 1 : 0,
        duration:
            hasTrackedBuses ? const Duration(milliseconds: 650) : Duration.zero,
        curve: const Interval(0.66, 1),
        child: hasTrackedBuses
            ? Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Tracked buses',
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      AnimatedSize(
                        alignment: Alignment.topCenter,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOutCubic,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (BuildContext context, int position) {
                            final bus = _followedBuses[position];
                            return ListTile(
                              onTap: () {
                                context.read<BusStopSheetBloc>().add(
                                    SheetRequested(
                                        bus.busStop, kDefaultRouteId));
                              },
                              title: Consumer(
                                builder: (context, ref, child) {
                                  final arrivalTime = ref
                                      .watch(firstArrivalTimeProvider(
                                          busStop: bus.busStop,
                                          busServiceNumber:
                                              bus.busService.number))
                                      .value;

                                  return Text(
                                    arrivalTime != null
                                        ? '${bus.busService.number} - ${arrivalTime.getMinutesFromNow()} min'
                                        : '',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  );
                                },
                              ),
                              subtitle: Text(bus.busStop.displayName),
                            );
                          },
                          itemCount: _followedBuses.length,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.notifications_off_rounded),
                            label: Text(
                              'STOP TRACKING ALL BUSES',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            onPressed: () async {
                              final trackedBuses =
                                  await ref.read(followedBusesProvider.future);
                              await ref
                                  .read(followedBusesProvider.notifier)
                                  .unfollowAllBuses();
                              ScaffoldMessenger.of(context)
                                  .hideCurrentSnackBar();
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content:
                                    const Text('Stopped tracking all buses'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () async {
                                    for (var trackedBus in trackedBuses) {
                                      await ref
                                          .read(followedBusesProvider.notifier)
                                          .followBus(
                                              busStopCode:
                                                  trackedBus.busStop.code,
                                              busServiceNumber:
                                                  trackedBus.busService.number);
                                    }
                                  },
                                ),
                              ));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            : Container(),
      ),
    );
  }

  List<Widget> _buildHomeItems() {
    return [
      _buildTrackedBuses(),
      ProxyProvider0<EditModel>(
        update: (_, __) => EditModel(isEditing: _isEditing),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: BusStopOverviewList(
            routeId: kDefaultRouteId,
            emptyView: Container(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Text(
                    'Pinned bus stops appear here.\n\nTap the pin next to a bus stop to pin it.\n\n\nAdd a route to organize multiple bus stops together.',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium!
                        .copyWith(color: Theme.of(context).hintColor)),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 64.0),
    ];
  }
}
