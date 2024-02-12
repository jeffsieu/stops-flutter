import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bus_service.dart';
import '../utils/database_utils.dart';

class FetchDataDialog extends ConsumerStatefulWidget {
  const FetchDataDialog({super.key, required this.isSetup});
  final bool isSetup;

  @override
  ConsumerState<FetchDataDialog> createState() {
    return _FetchDataDialogState();
  }
}

class _FetchDataDialogState extends ConsumerState<FetchDataDialog> {
  double progress = 0.25;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isSetup
          ? 'Performing first time setup'
          : 'Re-fetching cached data'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress),
          Text('${(progress * 100).toInt()}%'),
        ],
      ),
    );
  }

  Future<void> _fetchData() async {
    await ref.read(busStopListProvider.notifier).fetchFromApi();
    setState(() {
      progress += 0.25;
    });
    await ref.read(busServiceListProvider.notifier).fetchFromApi();
    setState(() {
      progress += 0.40;
    });
    await ref
        .read(busServiceRouteListProvider(BusService(number: '', operator: ''))
            .notifier)
        .fetchFromApi();
    setState(() {
      progress += 0.10;
    });
    Navigator.pop(context);
  }
}
