import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:implicitly_animated_reorderable_list/implicitly_animated_reorderable_list.dart';
import 'package:implicitly_animated_reorderable_list/transitions.dart';

import '../main.dart';
import '../routes/fade_page_route.dart';
import '../routes/search_page.dart';
import '../utils/bus_stop.dart';
import '../utils/user_route.dart';
import '../widgets/card_app_bar.dart';
import '../widgets/color_picker.dart';
import '../widgets/never_focus_node.dart';

class AddRoutePage extends StatefulWidget {
  const AddRoutePage() : route = null;
  const AddRoutePage.edit(this.route);

  final UserRoute route;

  @override
  State createState() {
    return AddRoutePageState();
  }
}

class AddRoutePageState extends State<AddRoutePage> {
  List<BusStop> busStops;
  bool _isReordering;
  Color _colorPickerColor;
  Color _color;
  TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    busStops = <BusStop>[];
    _color = Colors.red;
    _isReordering = false;
    _nameController = TextEditingController();

    if (widget.route != null) {
      busStops = List<BusStop>.from(widget.route.busStops);
      _color = widget.route.color;
      _nameController.text = widget.route.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    _color = _color.of(context);
    SystemChrome.setSystemUIOverlayStyle(StopsApp.overlayStyleOf(context));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.route == null ? 'Add route' : 'Edit route'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.done),
            tooltip: 'Done',
            onPressed: _popRoute,
          )
        ],
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ListView(
          physics: _isReordering ? const NeverScrollableScrollPhysics() : const ScrollPhysics(),
          children: <Widget>[
            Row(
              children: <Widget>[
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
                        child: Icon(Icons.palette,
                          color: _color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
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
          child: Icon(Icons.search, color: Theme.of(context).hintColor),
        ),
        title: TextField(
          enabled: false,
          focusNode: NeverFocusNode(),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.all(16.0),
            border: InputBorder.none,
            hintText: 'Add bus stops',
            hintStyle: const TextStyle().copyWith(color:
              Theme.of(context).hintColor),
          ),
        ),
      ),
    );
  }

  Widget _buildBusStops() {
    return Container(
      child: ImplicitlyAnimatedReorderableList<BusStop>(
        shrinkWrap: true,
        items: busStops,
        areItemsTheSame: (BusStop oldBusStop, BusStop newBusStop) => oldBusStop == newBusStop,
        onReorderStarted: (BusStop busStop, int position) {
          _isReordering = true;
        },
        onReorderFinished: (BusStop item, int from, int to, List<BusStop> newBusStops) {
          setState(() {
            busStops = newBusStops;
          });
        },
        itemBuilder: (BuildContext context, Animation<double> itemAnimation, BusStop busStop, int position) {
          return Reorderable(
            key: ValueKey<BusStop>(busStop),
            builder: (BuildContext context, Animation<double> dragAnimation, bool inDrag) {
              const double initialElevation = 2.0;
              final double elevation = Tween<double>(begin: initialElevation, end: 10.0).animate(CurvedAnimation(parent: dragAnimation, curve: Curves.easeOutCubic)).value;
              final Color materialColor = Color.lerp(Theme.of(context).cardColor, Colors.white, dragAnimation.value / 10);

              final Widget card = Material(
                color: materialColor,
                elevation: elevation,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Handle(
                        child: ListTile(
                          leading: Container(
                            width: 24,
                            child: Text('${position + 1}.',
                                style: Theme.of(context).textTheme.headline6.copyWith(color: _color),
                                textAlign: TextAlign.right,
                            ),
                          ),
                          title: Text(busStop.displayName),
                        ),
                      ),
                    ),
                    IconButton(
                      padding: const EdgeInsets.all(16.0),
                      color: Theme.of(context).hintColor,
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        busStops.remove(busStop);
                      }),
                    ),
                  ],
                ),
              );

              if (dragAnimation.value > 0.0) {
                return card;
              }

              return SizeFadeTransition(
                sizeFraction: 0.75,
                curve: Curves.easeInOut,
                animation: itemAnimation,
                child: card,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showColorDialog() async {
    _colorPickerColor = _color;
    final Color selectedColor = await showDialog<Color>(
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
          actions: <Widget>[
            ButtonTheme(
              minWidth: 0,
              height: 36,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              child: FlatButton(
                textColor: Theme.of(context).accentColor,
                onPressed: () {
                  Navigator.pop(context, _colorPickerColor);
                },
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              ),
            )
          ],
        );
      }
    );
    _colorPickerColor = null;
    if (selectedColor != null) {
      setState(() {
        _color = selectedColor;
      });
    }
  }

  Future<void> _pushSearchRoute() async {
    final FadePageRoute<BusStop> route = FadePageRoute<BusStop>(child: SearchPage.onlyBusStops());
    final BusStop selectedBusStop = await Navigator.push(context, route);
    if (selectedBusStop != null) {
      setState(() {
        busStops.add(selectedBusStop);
      });
    }
  }

  void _popRoute() {
    Navigator.pop(context, UserRoute.withId(id: widget.route?.id, name: _nameController.text, color: _color, busStops: busStops));
  }
}
