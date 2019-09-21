import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rubber/rubber.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/bus_api.dart';
import '../utils/bus_stop.dart';
import '../utils/bus_utils.dart';
import '../utils/shared_preferences_utils.dart';
import '../widgets/bus_timing_row.dart';

class BusStopDetailSheet extends StatefulWidget {
  BusStopDetailSheet({Key key, TickerProvider vsync, @required this.isHomePage})
      : rubberAnimationController = RubberAnimationController(
          vsync: vsync,
          lowerBoundValue: AnimationControllerValue(percentage: 0),
          halfBoundValue: AnimationControllerValue(percentage: 0.5),
          upperBoundValue: AnimationControllerValue(percentage: 1),
          duration: Duration(milliseconds: 200),
          springDescription: SpringDescription.withDampingRatio(
              mass: 1, ratio: DampingRatio.NO_BOUNCY, stiffness: Stiffness.LOW),
        ),
        scrollController = ScrollController(),
        super(key: key) {
    rubberAnimationController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        rubberAnimationController.halfBoundValue = null;
      }
    });
  }

  final ScrollController scrollController;
  final RubberAnimationController rubberAnimationController;
  final bool isHomePage;
  final Duration fadeDuration = Duration(milliseconds: 500);
  final double fadeInDurationFactor = 0.7;
  final double _sheetHalfBoundValue = 0.5;

  static BusStopDetailSheetState of(BuildContext context) =>
      context.ancestorStateOfType(const TypeMatcher<BusStopDetailSheetState>());

  @override
  State<StatefulWidget> createState() => BusStopDetailSheetState();
}

class BusStopDetailSheetState extends State<BusStopDetailSheet>
    with SingleTickerProviderStateMixin {
  BusStop _busStop;
  List<dynamic> _buses = <dynamic>[];
  String _latestData;
  bool _isStarEnabled = false;
  bool _isDismissed = true;

  Stream<String> _busArrivalStream;

  AnimationController fadeAnimationController;
  Animation<double> fadeAnimation;

  BusStopChangeListener _busStopListener;
  TextEditingController textController;

  /*
   * Updates the bottom sheet with details of another bus stop
   *
   * Called externally from the parent containing this widget
   */
  Future<void> updateWith(BusStop busStop) async {
    final bool starred = await isBusStopStarred(busStop);
    setState(() {
      if (_busStopListener != null) {
        unregisterBusStopListener(_busStop, _busStopListener);
      }

      _busStop = busStop;
      _isStarEnabled = starred;
      _busArrivalStream = BusAPI().busStopArrivalStream(busStop);
      _latestData = BusAPI().busStopArrivalLatest(busStop);
      textController = TextEditingController(text: _busStop.displayName);

      if (!_isDismissed)
        fadeAnimationController.forward(from: 0);
      _isDismissed = true;

      widget.rubberAnimationController.halfBoundValue =
          AnimationControllerValue(percentage: widget._sheetHalfBoundValue);
      widget.rubberAnimationController.halfExpand();
      AnimationStatusListener statusListener;
      statusListener = (AnimationStatus status) {
        if (widget.rubberAnimationController.animationState.value ==
            AnimationState.collapsed) {
          widget.rubberAnimationController.removeStatusListener(statusListener);
        }
      };
      widget.rubberAnimationController.addStatusListener(statusListener);
    });

    _busStopListener = (BusStop busStop) {
      setState(() {
        _busStop = busStop;
      });
    };
    registerBusStopListener(_busStop, _busStopListener);

    Function listener;
    listener = () {
      if (widget.rubberAnimationController.isDismissed) {
        widget.rubberAnimationController.removeListener(listener);
        _isDismissed = true;
      }
    };
    widget.rubberAnimationController.addListener(listener);
  }

  @override
  void initState() {
    super.initState();

    fadeAnimationController =
        AnimationController(vsync: this, duration: Duration(seconds: 1));
    fadeAnimation = CurvedAnimation(
      parent: fadeAnimationController,
      curve: Curves.ease,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_busStop == null)
      return Container();

    final Widget scrollView = CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      controller: widget.scrollController,
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: _buildHeader(),
        ),
        SliverToBoxAdapter(
          child: _buildTimingList(),
        )
      ],
    );

    return Material(
      elevation: 16.0,
      child: scrollView,
    );
  }

  @override
  void dispose() {
    fadeAnimationController.reverse(from: 1);
    fadeAnimationController.dispose();
    unregisterBusStopListener(_busStop, _busStopListener);
    super.dispose();
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(
        top: 16.0,
        left: 16.0,
        right: 8.0,
        bottom: 16.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          // [Expanded], [IntrinsicHeight] and [SizedBox] widgets
          // required to make the [Column] fill the parent [Row]
          // to ensure left-alignment of text
          Expanded(
            child: AnimatedSwitcher(
              duration: widget.fadeDuration,
              switchInCurve: Interval(1-widget.fadeInDurationFactor, 1),
              switchOutCurve: Interval(widget.fadeInDurationFactor, 1),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: IntrinsicHeight(
                key: Key(_busStop.code),
                child: SizedBox.expand(
                  child: OverflowBox(
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(_busStop.displayName,
                            style: Theme.of(context).textTheme.title),
                        Text(_busStop.code,
                            style: Theme.of(context).textTheme.subtitle),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: <Widget>[
              _isStarEnabled && widget.isHomePage
                  ? IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit name',
                      onPressed: () => _showEditNameDialog(),
                    )
                  : Container(),
              IconButton(
                tooltip: _isStarEnabled ? 'Unfavorite' : 'Favorite',
                icon: Icon(_isStarEnabled ? Icons.star : Icons.star_border),
                onPressed: () {
                  if (!_isStarEnabled) {
                    starBusStop(_busStop);
                  } else {
//                    CancelableOperation<thing >;
//                    Future.delayed(duration).
                  unstarBusStop(_busStop);
                    Scaffold.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Bus stop unfavorited'),
//                          action: SnackBarAction(
//                          label: 'Undo',
//                          onPressed: () {
////                            //TODO(jeffsieu): Add undo functionality.
//                          }),
                      ),
                    );
                  }
                  setState(() {
                    _isStarEnabled = !_isStarEnabled;
                  });
                },
              ),
              IconButton(
                tooltip: 'Open in Google Maps',
                icon: const Icon(Icons.open_in_new),
                onPressed: () => launch(
                    'geo:${_busStop.latitude},${_busStop.longitude}?q=${_busStop.latitude},${_busStop.longitude}(Label+Name)'),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTimingList() {
    _latestData = BusAPI().busStopArrivalLatest(_busStop);
    return AnimatedSwitcher(
        duration: widget.fadeDuration,
        switchInCurve: Interval(1-widget.fadeInDurationFactor, 1),
        switchOutCurve: Interval(widget.fadeInDurationFactor, 1),
        transitionBuilder:
        (Widget child, Animation<double> animation) {
      return FadeTransition(
        child: child,
        opacity: animation,
      );
    },
    child: StreamBuilder<String>(
      key: Key(_busStop.code),
      initialData: _latestData,
      stream: _busArrivalStream,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.none:
            return _messageBox(BusAPI.kNoInternetError);
          case ConnectionState.active:
          case ConnectionState.waiting:
            if (snapshot.data == null) {
              return _messageBox(BusAPI.kLoadingMessage);
            }
            continue done;
          done:
          case ConnectionState.done:
            if (snapshot.hasError)
              return _messageBox('Error: ${snapshot.error}');

            _buses = jsonDecode(snapshot.data)['Services'];
            _buses.sort((dynamic a, dynamic b) =>
                compareBusNumber(a['ServiceNo'], b['ServiceNo']));
            _latestData = snapshot.data;
            return _buses.isNotEmpty
                ? ListView.builder(
              shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (BuildContext context, int position) {
                        return BusTimingRow(_busStop.code, _buses[position],
                              key: Key(_busStop.code +
                                  _buses[position]['ServiceNo']));
                      },
                    itemCount: _buses.length,
                  )
                : _messageBox(BusAPI.kNoBusesError);
        }
        return null;
      }),
    );
  }

  Widget _messageBox(String text) {
    return Center(
        child: Text(text),
    );
  }

  void _showEditNameDialog() {
    showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          textController.selection = TextSelection(
              baseOffset: 0, extentOffset: textController.text.length);
          return AlertDialog(
            title: const Text('Edit name'),
            content: TextField(
              onSubmitted: (String name) {
                changeBusStopName(name);
                Navigator.of(context).pop();
              },
              autofocus: true,
              autocorrect: true,
              controller: textController,
              cursorColor: Theme.of(context).accentColor,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Bus stop name',
              ),
            ),
            actions: <Widget>[
              FlatButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              FlatButton(
                onPressed: () {
                  final String newName = textController.text;
                  changeBusStopName(newName);
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              )
            ],
          );
        });
  }

  void changeBusStopName(String newName) {
    _busStop.displayName = newName;
    starBusStop(_busStop);
  }
}
