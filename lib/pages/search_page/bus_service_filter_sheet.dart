import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/pages/search_page/search_page.dart';
import 'package:stops_sg/widgets/bus_service_search_item.dart';

class BusServiceFilterSheet extends ConsumerStatefulWidget {
  const BusServiceFilterSheet({super.key});

  @override
  ConsumerState<BusServiceFilterSheet> createState() =>
      _BusServiceFilterSheetState();
}

class _BusServiceFilterSheetState extends ConsumerState<BusServiceFilterSheet> {
  String _busStopServicesFilterQuery = '';

  @override
  Widget build(BuildContext context) {
    final busServices = ref.watch(busServiceListProvider).valueOrNull ?? [];

    final matchingBusServices = SearchPageState.filterBusServices(
            busServices, _busStopServicesFilterQuery)
        .toList();

    return DraggableScrollableSheet(
      maxChildSize: 1,
      initialChildSize: .5,
      expand: false,
      builder: (context, controller) => CustomScrollView(
        controller: controller,
        slivers: [
          PinnedHeaderSliver(
            child: Material(
              type: MaterialType.card,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 32.0),
                      child: Text('Show bus stops with...',
                          style: Theme.of(context).textTheme.headlineMedium),
                    ),
                    const SizedBox(height: 16.0),
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          _busStopServicesFilterQuery = value;
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search for bus services',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8.0),
                  ],
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: matchingBusServices.length,
            itemBuilder: (context, position) {
              final busService = matchingBusServices[position];

              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: BusServiceSearchItem(
                  busService: busService,
                  onTap: () => Navigator.pop(context, [busService]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
