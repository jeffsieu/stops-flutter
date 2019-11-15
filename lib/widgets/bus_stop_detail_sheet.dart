import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rubber/rubber.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/bus_api.dart';
import '../utils/bus_stop.dart';
import '../utils/bus_utils.dart';
import '../utils/database_utils.dart';
import '../widgets/bus_timing_row.dart';

class BusStopDetailSheet extends StatefulWidget {
  BusStopDetailSheet({Key key, TickerProvider vsync, @required this.hasAppBar})
      : rubberAnimationController = RubberAnimationController(
          vsync: vsync,
          lowerBoundValue: AnimationControllerValue(percentage: 0),
          halfBoundValue: AnimationControllerValue(percentage: 0.5),
          upperBoundValue: AnimationControllerValue(percentage: 1),
          duration: const Duration(milliseconds: 200),
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
  final bool hasAppBar;
  final Duration fadeDuration = const Duration(milliseconds: 1000);
  final double titleFadeInDurationFactor = 0.5;
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

  Stream<String> _busArrivalStream;

  AnimationController timingListAnimationController;

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

      timingListAnimationController.forward(from: 0);
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
  }

  @override
  void initState() {
    super.initState();
    timingListAnimationController = AnimationController(duration: widget.fadeDuration, vsync: this);
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
      type: MaterialType.card,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16.0),
        topRight: Radius.circular(16.0),
      ),
      elevation: 16.0,
      child: scrollView,
    );
  }

  @override
  void dispose() {
    timingListAnimationController.dispose();
    unregisterBusStopListener(_busStop, _busStopListener);
    super.dispose();
  }

  Widget _buildHeader() {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double extraPadding = widget.hasAppBar ? 0 : statusBarHeight;

    return AnimatedBuilder(
      animation: widget.rubberAnimationController,
      builder: (BuildContext context, Widget child) {
        final double completed = widget.rubberAnimationController.upperBound;
        final double dismissed = widget.rubberAnimationController.lowerBound;
        const double animationStart = 0.75;
        final double animationRange = completed - animationStart;
        final double animationStartBound = dismissed + (completed - dismissed) * animationStart;
        final double paddingHeightScale = ((widget.rubberAnimationController.value - animationStartBound) / animationRange).clamp(0.0, 1.0);
        return Container(
          padding: EdgeInsets.only(
            top: 32.0 + extraPadding * paddingHeightScale,
            left: 16.0,
            right: 8.0,
            bottom: 32.0,
          ),
          child: child,
        );
      },
      child: Stack(
        children: <Widget>[
          Center(
            child: AnimatedSwitcher(
              duration: widget.fadeDuration * widget.titleFadeInDurationFactor,
              switchInCurve: Interval(0.25, 1),
              switchOutCurve: Interval(0.75, 1),
              transitionBuilder: (Widget child, Animation<double> animation) {
                final bool entering = child.key == ValueKey<String>(_busStop.code);
                final Animatable<double> curve = CurveTween(curve: entering ? Curves.easeOutCubic : Curves.linear);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: animation
                        .drive(curve)
                        .drive(Tween<Offset>(begin: Offset(0, 0.5 * (entering ? 1 : -1)), end: Offset.zero)),
                    child: child,
                  ),
                );
              },
              child: Column(
                key: Key(_busStop.code),
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(_busStop.displayName,
                      style: Theme.of(context).textTheme.headline),
                  Text('${_busStop.code} · ${_busStop.road}',
                      style: Theme.of(context).textTheme.subtitle.copyWith(color: Theme.of(context).hintColor)),
                ],
              ),
            ),
          ),
          Container(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<String>(
              onSelected: (String option) {
                switch(option) {
                  case 'edit':
                    _showEditNameDialog();
                    break;
                  case 'star':
                    setState(() {
                      _isStarEnabled = !_isStarEnabled;
                    });
                    if (_isStarEnabled) {
                      starBusStop(_busStop);
                    } else {
                      unstarBusStop(_busStop);
                      Scaffold.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Bus stop unfavorited'),
//                          action: SnackBarAction(
//                          label: 'Undo',
//                          onPressed: () {
                            // TODO(jeffsieu): Add undo functionality.
//                          }),
                        ),
                      );
                    }
                    break;
                  case 'gmaps':
                    launch('geo:${_busStop.latitude},${_busStop.longitude}?q=${_busStop.defaultName} ${_busStop.code}');
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
                if (_isStarEnabled)
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                PopupMenuItem<String>(
                  value: 'star',
                  child: Text(_isStarEnabled ? 'Unfavorite' : 'Favorite'),
                ),
                const PopupMenuItem<String>(
                  value: 'gmaps',
                  child: Text('Open in Google Maps'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimingList() {
    _latestData = BusAPI().busStopArrivalLatest(_busStop);
    return Container(
//      duration: widget.fadeDuration,
//      switchInCurve: Interval(1-widget.fadeInDurationFactor, 1),
//      switchOutCurve: Interval(widget.fadeInDurationFactor, 1),
//      transitionBuilder: (Widget child, Animation<double> animation) {
//        return FadeTransition(
//          child: child,
//          opacity: animation,
//        );
//      },
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
                  ? MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (BuildContext context, int position) {
                          const double duration = 0.4;
                          const double offset = 0.075;
                          final double startOffset = (position * offset).clamp(0.0, 1.0);
                          final double endOffset = (position * offset + duration).clamp(0.0, 1.0);
                          final Animation<double> animation = timingListAnimationController
                              .drive(CurveTween(curve: Interval(widget.titleFadeInDurationFactor-offset, 1))) // animate after previous code disappears
                              .drive(CurveTween(curve: Interval(startOffset, endOffset))); // delay animation based on position
                          return SlideTransition(
                            position: animation
                                .drive(CurveTween(curve: Curves.easeOutQuint))
                                .drive(Tween<Offset>(
                                        begin: const Offset(0, 0.5),
                                        end: Offset.zero,
                                )
                            ),
                            child: FadeTransition(
                              opacity: animation,
                              child: BusTimingRow(_busStop.code, _buses[position],
                                      key: Key(_busStop.code +
                                          _buses[position]['ServiceNo'])),
                            ),
                          );
                        },
                        separatorBuilder: (BuildContext context, int position) {
                          return const Divider(height: 1);
                        },
                        itemCount: _buses.length,
                      ),
                    )
                  : _messageBox(BusAPI.kNoBusesError);
          }
          return null;
        },
      ),
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
