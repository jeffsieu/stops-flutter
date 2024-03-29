import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:implicitly_animated_reorderable_list/implicitly_animated_reorderable_list.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/bus_service.dart';
import '../models/bus_stop.dart';
import '../models/bus_stop_with_pinned_services.dart';
import '../models/user_route.dart';
import '../routes/fade_page_route.dart';
import '../routes/search_page.dart';
import '../widgets/bus_stop_overview_item.dart';
import '../widgets/card_app_bar.dart';
import '../widgets/color_picker.dart';
import '../widgets/edit_model.dart';
import '../widgets/never_focus_node.dart';

class AddRoutePage extends StatefulWidget {
  const AddRoutePage({Key? key})
      : route = null,
        routeId = null,
        super(key: key);
  AddRoutePage.edit(StoredUserRoute storedRoute, {Key? key})
      : route = storedRoute,
        routeId = storedRoute.id,
        super(key: key);

  final UserRoute? route;
  final int? routeId;

  @override
  State createState() {
    return AddRoutePageState();
  }
}

class AddRoutePageState extends State<AddRoutePage> {
  List<BusStop> busStops = <BusStop>[];
  bool _isReordering = false;
  Color? _colorPickerColor;
  Color _color = Colors.red;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.route != null) {
      busStops = List<BusStop>.from(widget.route!.busStops);
      _color = widget.route!.color;
      _nameController.text = widget.route!.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    _color = _color.of(context);
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleOf(context));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.clear_rounded),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.route == null ? 'Add route' : 'Edit route'),
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
                      autofocus: widget.route == null,
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
        elevation: 2.0,
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
    const _isEditing = true;
    return Provider<EditModel>(
      create: (_) => const EditModel(isEditing: _isEditing),
      child: ImplicitlyAnimatedReorderableList<BusStop>(
        shrinkWrap: true,
        items: busStops,
        areItemsTheSame: (BusStop oldBusStop, BusStop newBusStop) =>
            oldBusStop == newBusStop,
        onReorderStarted: (BusStop busStop, int position) {
          _isReordering = true;
        },
        onReorderFinished:
            (BusStop item, int from, int to, List<BusStop> newBusStops) {
          setState(() {
            busStops = newBusStops;
          });
        },
        itemBuilder: (BuildContext context, Animation<double> itemAnimation,
            BusStop busStop, int position) {
          return Reorderable(
            key: Key(busStop.hashCode.toString()),
            builder: (BuildContext context, Animation<double> dragAnimation,
                bool inDrag) {
              final Widget busStopItem = BusStopOverviewItem(
                BusStopWithPinnedServices.fromBusStop(busStop, <BusService>[]),
                key: Key(busStop.code),
              );

              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  busStopItem,
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 600),
                      opacity: _isEditing ? 1.0 : 0.0,
                      curve: const Interval(0.5, 1),
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 600),
                        offset:
                            _isEditing ? Offset.zero : const Offset(0, 0.25),
                        curve:
                            const Interval(0.5, 1, curve: Curves.easeOutCubic),
                        child: _isEditing
                            ? Handle(
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                          start: 16.0),
                                      child: Icon(
                                        Icons.drag_handle_rounded,
                                        color: Theme.of(context).hintColor,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Container(),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 9.0,
                          horizontal:
                              1.0), // Offset by 1 to account for card outline
                      child: Material(
                        type: MaterialType.transparency,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _isEditing
                                ? Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                        end: 0.0),
                                    child: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          busStops.remove(busStop);
                                        });
                                      },
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color: Theme.of(context).hintColor,
                                      ),
                                    ),
                                  )
                                : Container(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
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
    final Widget page = SearchPage.onlyBusStops();
    final route = FadePageRoute<BusStop>(child: page);
    final selectedBusStop = await Navigator.push(context, route);
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
              busStops: busStops
                  .map((BusStop busStop) =>
                      BusStopWithPinnedServices.fromBusStop(
                          busStop, <BusService>[]))
                  .toList(),
            )
          : UserRoute(
              name: _nameController.text,
              color: _color,
              busStops: busStops
                  .map((BusStop busStop) =>
                      BusStopWithPinnedServices.fromBusStop(
                          busStop, <BusService>[]))
                  .toList(),
            ),
    );
  }
}
