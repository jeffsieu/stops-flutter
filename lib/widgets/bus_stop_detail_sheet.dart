import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rubber/rubber.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/bus_api.dart';
import '../utils/bus_service.dart';
import '../utils/bus_service_arrival_result.dart';
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
  static const Duration updateAnimationDuration = Duration(milliseconds: 1000);
  static const Duration editAnimationDuration = Duration(milliseconds: 250);
  static const double _launchVelocity = 5.0;
  final double titleFadeInDurationFactor = 0.5;
  final double _sheetHalfBoundValue = 0.5;

  static BusStopDetailSheetState of(BuildContext context) =>
      context.ancestorStateOfType(const TypeMatcher<BusStopDetailSheetState>());

  @override
  State<StatefulWidget> createState() => BusStopDetailSheetState();
}

class BusStopDetailSheetState extends State<BusStopDetailSheet>
    with TickerProviderStateMixin {
  BusStop _busStop;
  List<BusServiceArrivalResult> _latestData;
  bool _isStarEnabled = false;
  bool _isEditing = false;
  bool _isAnimating = false;

  Stream<List<BusServiceArrivalResult>> _busArrivalStream;

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
      _isEditing = false;
      _busArrivalStream = BusAPI().busStopArrivalStream(busStop);
      _latestData = BusAPI().getLatestArrival(busStop);
      textController = TextEditingController(text: _busStop.displayName);

      timingListAnimationController.forward(from: 0);
      widget.rubberAnimationController.halfBoundValue =
          AnimationControllerValue(percentage: widget._sheetHalfBoundValue);
      // Lock animation while animating, as pressing another bus stop item
      // before the animation ends will cause the bottom sheet to be "dragged"
      // to the finger
      if (!_isAnimating) {
        _isAnimating = true;
        widget.rubberAnimationController.launchTo(
          widget.rubberAnimationController.value,
          widget.rubberAnimationController.halfBound,
          velocity: BusStopDetailSheet._launchVelocity,
        ).whenCompleteOrCancel(() {
          _isAnimating = false;
        });
      }

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
      isBusStopStarred(busStop).then((bool contains) {
        if (mounted)
          setState(() {
            _busStop = busStop;
            _isStarEnabled = contains;
          });
      });
    };
    registerBusStopListener(_busStop, _busStopListener);
  }

  @override
  void initState() {
    super.initState();
    timingListAnimationController = AnimationController(duration: BusStopDetailSheet.updateAnimationDuration, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    if (_busStop == null)
      return Container();

    final Widget scrollView = ListView(
      padding: const EdgeInsets.all(0),
      physics: const NeverScrollableScrollPhysics(),
      controller: widget.scrollController,
      children: <Widget>[
        _buildHeader(),
        _buildServiceList(),
        _buildFooter(context),
      ],
    );

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Material(
        type: MaterialType.card,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
        ),
        elevation: 16.0,
        child: scrollView,
      ),
    );
  }

  @override
  void dispose() {
    timingListAnimationController.dispose();
    unregisterBusStopListener(_busStop, _busStopListener);
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_isEditing) {
      setState(() {
        _isEditing = false;
      });
      return false;
    }

    if (widget.rubberAnimationController.value != 0) {
      widget.rubberAnimationController.animateTo(to: 0);
      return false;
    }

    return true;
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
            top: 48.0 + extraPadding * paddingHeightScale,
            left: 16.0,
            right: 16.0,
            bottom: 32.0,
          ),
          child: child,
        );
      },
      child: Stack(
        children: <Widget>[
          Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 56.0, right: 56.0),
              child: AnimatedSwitcher(
                duration: BusStopDetailSheet.updateAnimationDuration * widget.titleFadeInDurationFactor,
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
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headline),
                    Text('${_busStop.code} · ${_busStop.road}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.subtitle.copyWith(color: Theme.of(context).hintColor)),
                  ],
                ),
              ),
            ),
          ),
          Container(
            alignment: Alignment.centerLeft,
            child: AnimatedOpacity(
              opacity: _isEditing ? 1 : 0,
              duration: BusStopDetailSheet.editAnimationDuration,
              child: IconButton(
                tooltip: 'Edit name',
                icon: Icon(Icons.edit),
                onPressed: _isEditing ? _showEditNameDialog : null,
              ),
            )
          ),
          Container(
            alignment: Alignment.centerRight,
            child: _buildHeaderOverflow(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderOverflow() {
    if (_isEditing)
      return IconButton(
        tooltip: 'Done',
        icon: Icon(Icons.done),
        onPressed: () {
          setState(() {
            _isEditing = false;
          });
        },
      );
    return PopupMenuButton<String>(
      onSelected: (String option) {
        switch(option) {
          case 'edit':
            setState(() {
              _isEditing = !_isEditing;
              if (widget.rubberAnimationController.value != widget.rubberAnimationController.upperBound)
                widget.rubberAnimationController.launchTo(
                    widget.rubberAnimationController.value,
                    widget.rubberAnimationController.upperBound,
                    velocity: BusStopDetailSheet._launchVelocity/2);
            });
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
    );
  }

  Widget _buildServiceList() {
    return Column(
      children: <Widget>[
        AnimatedSize(
          vsync: this,
          duration: BusStopDetailSheet.editAnimationDuration * 2,
          curve: Curves.easeInOutCirc,
          child: _isEditing ? Container(
            padding: const EdgeInsets.only(left: 32.0, right: 32.0, bottom: 8.0),
            child: Column(
              children: <Widget>[
                Text(
                  'Pinned bus services',
                  style: Theme.of(context).textTheme.display1,
                ),
                Text(
                  'Arrival times of pinned buses are displayed on the homepage',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.body1.copyWith(color: Theme.of(context).hintColor),
                )
              ],
            )
          ) : Container(),
        ),
        FutureBuilder<List<BusService>>(
          initialData: const <BusService>[],
          future: getServicesIn(_busStop),
          builder: (BuildContext context, AsyncSnapshot<List<BusService>> snapshot) {
            return _buildTimingList(snapshot.data);
          }
        ),
      ],
    );
  }

  Widget _buildTimingList(List<BusService> allServices) {
    _latestData = BusAPI().getLatestArrival(_busStop);
    return StreamBuilder<List<BusServiceArrivalResult>>(
        key: Key(_busStop.code),
        initialData: _latestData,
        stream: _busArrivalStream,
        builder: (BuildContext context, AsyncSnapshot<List<BusServiceArrivalResult>> snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.none:
              return _messageBox(BusAPI.kNoInternetError);
            case ConnectionState.active:
            case ConnectionState.waiting:
              if (snapshot.data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              continue done;
            done:
            case ConnectionState.done:
              if (snapshot.hasError)
                return _messageBox('Error: ${snapshot.error}');

              final List<BusServiceArrivalResult> buses = snapshot.data;
              buses.sort((BusServiceArrivalResult a, BusServiceArrivalResult b) =>
                  compareBusNumber(a.busService.number, b.busService.number));
              _latestData = snapshot.data;

              // Calculate the positions that the bus services will be displayed at
              // If the bus service has no arrival timings, it will not show and
              // will have a position of -1
              final List<int> displayedPositions = List<int>(allServices.length);
              displayedPositions.fillRange(0, allServices.length, -1);
              for (int i = 0, j = 0; i < allServices.length && j < buses.length; i++) {
                if (allServices[i] == buses[j].busService) {
                  displayedPositions[i] = j;
                  j++;
                }
              }

              return Stack(
                children: <Widget>[
                  if (buses.isEmpty)
                    AnimatedOpacity(
                      duration: BusStopDetailSheet.editAnimationDuration,
                      opacity: _isEditing ? 0 : 1,
                      child: _messageBox(BusAPI.kNoBusesError),
                    ),
                  MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (BuildContext context, int position) {
                        final int displayedPosition = displayedPositions[position];
                        final bool isDisplayed = displayedPosition != -1;

                        BusServiceArrivalResult arrivalResult;
                        if (isDisplayed)
                          arrivalResult = buses[displayedPosition];

                        const double duration = 0.4;
                        const double offset = 0.075;
                        final double startOffset = (displayedPosition * offset).clamp(0.0, 1.0);
                        final double endOffset = (displayedPosition * offset + duration).clamp(0.0, 1.0);
                        final Animation<double> animation = timingListAnimationController
                            .drive(CurveTween(curve: Interval(widget.titleFadeInDurationFactor-offset, 1))) // animate after previous code disappears
                            .drive(CurveTween(curve: Interval(startOffset, endOffset))); // delay animation based on position

                        final Widget item = BusTimingRow(
                            _busStop,
                            allServices[position],
                            arrivalResult,
                            _isEditing,
                            key: Key(_busStop.code +
                                allServices[position].number),
                        );

                        // Animate if displayed
                        if (isDisplayed)
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
                              child: item,
                            ),
                          );
                        else
                          return item;
                      },
                      separatorBuilder: (BuildContext context, int position) {
                        // Checks if the item above and below the divider are both shown
                        // If both are shown, show divider
                        final int displayedPositionTop = displayedPositions[position];
                        final int displayedPositionBottom = displayedPositions[position+1];
                        final bool areTopAndBottomDisplayed = displayedPositionTop != -1 && displayedPositionBottom != -1;
                        final bool isDisplayed = _isEditing || areTopAndBottomDisplayed;
                        return isDisplayed ? const Divider(height: 1) : Container();
                      },
                      itemCount: allServices.length,
                    ),
                  ),
                ],
              );
          }
          return null;
        },
      );
  }

  Widget _messageBox(String text) {
    return Center(
        child: Text(text),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final Brightness brightness = MediaQuery.of(context).platformBrightness;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
          borderRadius: const BorderRadius.all(
            Radius.circular(16.0),
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          direction: Axis.vertical,
          spacing: 16,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.info_outline, color: Theme.of(context).textTheme.display1.color),
                Container(width: 8.0),
                Text(
                  'Legend',
                  style: Theme.of(context).textTheme.display1
                ),
              ],
            ),
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 16,
                  margin: const EdgeInsets.only(right: 8.0),
                  color: getBusLoadColor(BusLoad.low, brightness),
                ),
                const Text('Many seats'),
              ],
            ),
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 16,
                  margin: const EdgeInsets.only(right: 8.0),
                  color: getBusLoadColor(BusLoad.medium, brightness),
                ),
                const Text('Some seats'),
              ],
            ),
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 16,
                  margin: const EdgeInsets.only(right: 8.0),
                  color: getBusLoadColor(BusLoad.high, brightness),
                ),
                const Text('Few seats'),
              ],
            ),
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  margin: const EdgeInsets.only(right: 8.0),
                  child: Center(
                    child: Text(
                      getBusTypeVerbose(BusType.double),
                      style: Theme.of(context).textTheme.title,
                    ),
                  ),
                ),
                const Text('Double-decker/Long'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog() {
    showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          textController.selection = TextSelection(
              baseOffset: 0, extentOffset: textController.text.length);
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0, left: 16.0),
                    child: Text(
                      'Edit name',
                      style: Theme.of(context).textTheme.title,
                    ),
                  ),
                  Container(height: 16.0),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
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
                  ),
                  Container(height: 28.0),
                  ButtonTheme(
                    minWidth: 0,
                    height: 36,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    child: Row(
                      children: <Widget>[
                        FlatButton(
                          textColor: Theme.of(context).accentColor,
                          onPressed: () {
                            textController.text = _busStop.defaultName;
                            final String newName = textController.text;
                            changeBusStopName(newName);
                            Navigator.of(context).pop();
                          },
                          child: const Text('RESET', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                        ),
                        Spacer(),
                        FlatButton(
                          textColor: Theme.of(context).accentColor,
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                        ),
                        Container(width: 8.0),
                        FlatButton(
                          textColor: Theme.of(context).accentColor,
                          onPressed: () {
                            final String newName = textController.text;
                            changeBusStopName(newName);
                            Navigator.of(context).pop();
                          },
                          child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        });
  }

  void changeBusStopName(String newName) {
    _busStop.displayName = newName;
    starBusStop(_busStop);
  }
}
