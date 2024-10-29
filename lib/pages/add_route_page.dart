import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/main.dart';
import 'package:stops_sg/routes/bus_stop_search_route.dart';
import 'package:stops_sg/routes/routes.dart';
import 'package:stops_sg/widgets/bus_stop_overview_item.dart';
import 'package:stops_sg/widgets/card_app_bar.dart';
import 'package:stops_sg/widgets/color_picker.dart';
import 'package:stops_sg/widgets/edit_model.dart';
import 'package:stops_sg/widgets/never_focus_node.dart';
import 'package:stops_sg/widgets/reorderable_bus_stop_list.dart';

class AddRoutePage extends StatefulHookConsumerWidget {
  const AddRoutePage({super.key}) : routeId = null;
  const AddRoutePage.edit({super.key, required int this.routeId});

  final int? routeId;

  @override
  ConsumerState<AddRoutePage> createState() {
    return AddRoutePageState();
  }
}

class AddRoutePageState extends ConsumerState<AddRoutePage> {
  List<BusStop> busStops = <BusStop>[];
  bool _isReordering = false;
  Color? _colorPickerColor;
  Color _color = Colors.red;
  final TextEditingController _nameController = TextEditingController();
  StoredUserRoute? get route => widget.routeId != null
      ? ref.watch(savedUserRouteProvider(id: widget.routeId!)).valueOrNull
      : null;

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      if (route != null) {
        busStops = List<BusStop>.from(route!.busStops);
        _color = route!.color;
        _nameController.text = route!.name;
      }
      return null;
    }, [route]);

    _color = _color.of(context);
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleOf(context));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.clear_rounded),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(route == null ? 'Add route' : 'Edit route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_rounded),
            tooltip: 'Done',
            onPressed: _popRoute,
          )
        ],
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          physics: _isReordering
              ? const NeverScrollableScrollPhysics()
              : const ScrollPhysics(),
          children: [
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(8.0),
                  onTap: _showColorDialog,
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      width: 48.0,
                      height: 48.0,
                      decoration: BoxDecoration(
                        color: _color,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.palette,
                          color: _color.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(width: 8.0),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: TextField(
                      autofocus: route == null,
                      controller: _nameController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Name',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            Container(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              child: _buildSearchField(),
            ),
            _buildBusStops(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Hero(
      tag: 'searchField',
      child: CardAppBar(
        onTap: _pushSearchRoute,
        leading: Container(
          padding: const EdgeInsets.only(
              left: 16.0, top: 8.0, right: 8.0, bottom: 8.0),
          child: Icon(Icons.search_rounded, color: Theme.of(context).hintColor),
        ),
        title: TextField(
          enabled: false,
          focusNode: NeverFocusNode(),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(16.0),
            disabledBorder: InputBorder.none,
            hintText: 'Add bus stops',
            hintStyle:
                const TextStyle().copyWith(color: Theme.of(context).hintColor),
          ),
        ),
      ),
    );
  }

  Widget _buildBusStops() {
    const isEditing = true;

    return ReorderableBusStopList(
      busStops: busStops,
      isEditing: isEditing,
      onReorderStart: (position) {
        _isReordering = true;
      },
      onReorderEnd: (position) {
        _isReordering = false;
      },
      onReorder: (oldIndex, newIndex) {
        final newBusStops = List<BusStop>.from(busStops);
        final item = newBusStops.removeAt(oldIndex);
        newBusStops.insert(newIndex, item);

        setState(() {
          busStops = newBusStops;
        });
      },
      onBusStopRemoved: (busStop) => setState(() {
        busStops.remove(busStop);
      }),
    );
  }

  Future<void> _showColorDialog() async {
    _colorPickerColor = _color;
    final selectedColor = await showDialog<Color>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Route color'),
            content: ColorPicker(
              colors: Colors.primaries.map((Color a) => a.of(context)).toList(),
              size: 48.0,
              initialColor: _color.of(context),
              onColorChanged: (Color color) {
                _colorPickerColor = color;
              },
            ),
            actions: [
              ButtonTheme(
                minWidth: 0,
                height: 36,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context, _colorPickerColor);
                  },
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              )
            ],
          );
        });
    _colorPickerColor = null;
    if (selectedColor != null) {
      setState(() {
        _color = selectedColor;
      });
    }
  }

  Future<void> _pushSearchRoute() async {
    final selectedBusStop = await BusStopSearchRoute().push<BusStop>(context);
    if (selectedBusStop != null) {
      setState(() {
        busStops.add(selectedBusStop);
      });
    }
  }

  void _popRoute() {
    Navigator.pop(
      context,
      widget.routeId != null
          ? StoredUserRoute(
              id: widget.routeId!,
              name: _nameController.text,
              color: _color,
              busStops: busStops,
            )
          : UserRoute(
              name: _nameController.text,
              color: _color,
              busStops: busStops,
            ),
    );
  }
}
