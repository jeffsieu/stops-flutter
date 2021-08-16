// @dart=2.9

import 'package:flutter/material.dart';

import '../utils/bus_api.dart';

class FetchDataDialog extends StatefulWidget {
  const FetchDataDialog({@required this.isSetup });
  final bool isSetup;

  @override
  State<StatefulWidget> createState() {
    return _FetchDataDialogState();
  }
}


class _FetchDataDialogState extends State<FetchDataDialog> {
  double progress = 0.25;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isSetup ? 'Performing first time setup' : 'Re-fetching cached data'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LinearProgressIndicator(value: progress),
          Text('${(progress * 100).toInt()}%'),
        ],
      ),
    );
  }

  Future<void> _fetchData() async {
    await BusAPI().fetchAndStoreBusStops();
    setState(() {
      progress += 0.25;
    });
    await BusAPI().fetchAndStoreBusServices();
    setState(() {
      progress += 0.40;
    });
    await BusAPI().fetchAndStoreBusServiceRoutes();
    setState(() {
      progress += 0.10;
    });
    Navigator.pop(context);
  }
}