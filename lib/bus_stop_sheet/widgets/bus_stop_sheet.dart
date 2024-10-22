import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:provider/provider.dart';
import 'package:rubber/rubber.dart';
import 'package:stops_sg/bus_api/bus_api.dart';
import 'package:stops_sg/bus_api/models/bus_stop.dart';
import 'package:stops_sg/bus_stop_sheet/bloc/bus_stop_sheet_bloc.dart';
import 'package:stops_sg/bus_stop_sheet/widgets/bus_stop_sheet_header.dart';
import 'package:stops_sg/bus_stop_sheet/widgets/bus_stop_sheet_service_list.dart';
import 'package:stops_sg/database/database.dart';
import 'package:stops_sg/database/models/user_route.dart';
import 'package:stops_sg/pages/settings_page.dart';
import 'package:stops_sg/widgets/bus_stop_legend_card.dart';

const Duration kSheetUpdateDuration = Duration(milliseconds: 1000);
const Duration kSheetEditDuration = Duration(milliseconds: 250);
const double kSheetRowAnimDuration = 0.4;
const double kSheetRowAnimationOffset = 0.075;
const double _launchVelocity = 5.0;
const double kTitleFadeInDurationFactor = 0.5;
const double _sheetHalfBoundValue = 0.5;

class BusStopSheet extends ConsumerStatefulWidget {
  BusStopSheet(
      {super.key, required TickerProvider vsync, required this.hasAppBar})
      : rubberAnimationController = RubberAnimationController(
          vsync: vsync,
          lowerBoundValue: AnimationControllerValue(percentage: 0),
          halfBoundValue: AnimationControllerValue(percentage: 0.5),
          upperBoundValue: AnimationControllerValue(percentage: 1),
          duration: const Duration(milliseconds: 200),
          springDescription: SpringDescription.withDampingRatio(
              mass: 1, ratio: DampingRatio.NO_BOUNCY, stiffness: Stiffness.LOW),
        ),
        scrollController = ScrollController() {
    rubberAnimationController.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        rubberAnimationController.halfBoundValue = null;
      }
    });
  }

  final ScrollController scrollController;
  final RubberAnimationController rubberAnimationController;
  final bool hasAppBar;

  static _BusStopSheetState? of(BuildContext context) =>
      context.findAncestorStateOfType<_BusStopSheetState>();

  @override
  ConsumerState<BusStopSheet> createState() => _BusStopSheetState();
}

class _BusStopSheetState extends ConsumerState<BusStopSheet>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  BusStop? busStop;
  bool _isAnimating = false;

  late final AnimationController timingListAnimationController =
      AnimationController(duration: kSheetUpdateDuration, vsync: this);

  TextEditingController? textController;

  /// Updates the bottom sheet with details of another bus stop.
  /// Called externally from the parent containing this widget.
  Future<void> updateWith(BusStop? newBusStop, int? routeId) async {
    if (newBusStop == null || routeId == null) {
      setState(() {
        busStop = newBusStop;
      });
      return;
    }
    setState(() {
      busStop = newBusStop;
      textController = TextEditingController(text: newBusStop.displayName);

      timingListAnimationController.forward(from: 0);
      widget.rubberAnimationController.halfBoundValue =
          AnimationControllerValue(percentage: _sheetHalfBoundValue);
      // Lock animation while animating, as pressing another bus stop item
      // before the animation ends will cause the bottom sheet to be "dragged"
      // to the finger
      if (!_isAnimating) {
        _isAnimating = true;
        widget.rubberAnimationController
            .launchTo(
          widget.rubberAnimationController.value,
          widget.rubberAnimationController.halfBound,
          velocity: _launchVelocity,
        )
            .whenCompleteOrCancel(() {
          _isAnimating = false;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Listen to when sheet is closed
    widget.rubberAnimationController.animationState.addListener(() {
      if (widget.rubberAnimationController.value <= 0) {
        context.read<BusStopSheetBloc>().add(const SheetHidden());
      }
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final busStop =
        context.select((BusStopSheetBloc bloc) => bloc.state.busStop);
    final routeId =
        context.select((BusStopSheetBloc bloc) => bloc.state.routeId);
    if (busStop == null || routeId == null) return Container();

    final route = ref.watch(savedUserRouteProvider(id: routeId)).valueOrNull;

    final Widget scrollView = ListView(
      padding: const EdgeInsets.all(0),
      physics: const NeverScrollableScrollPhysics(),
      controller: widget.scrollController,
      children: [
        BusStopSheetHeader(
          rubberAnimationController: widget.rubberAnimationController,
          hasAppBar: widget.hasAppBar,
        ),
        BusStopSheetServiceList(
          timingListAnimation: timingListAnimationController,
        ),
        _buildFooter(context),
      ],
    );

    return MultiBlocListener(
      listeners: [
        BlocListener<BusStopSheetBloc, BusStopSheetState>(
          listenWhen: (previous, current) =>
              previous.isEditing != current.isEditing,
          listener: (context, state) {
            if (state.isEditing) {
              if (widget.rubberAnimationController.value !=
                  widget.rubberAnimationController.upperBound) {
                widget.rubberAnimationController.launchTo(
                    widget.rubberAnimationController.value,
                    widget.rubberAnimationController.upperBound,
                    velocity: _launchVelocity / 2);
              }
            }
          },
        ),
        BlocListener<BusStopSheetBloc, BusStopSheetState>(
          listenWhen: (previous, current) =>
              previous.busStop != current.busStop ||
              previous.routeId != current.routeId ||
              previous.latestOpenTimestamp != current.latestOpenTimestamp,
          listener: (context, state) async {
            if (state.visible) {
              await updateWith(state.busStop, state.routeId);
            }
            // TODO: implement listener
          },
        ),
        BlocListener<BusStopSheetBloc, BusStopSheetState>(
          listenWhen: (previous, current) =>
              previous.isRenaming != current.isRenaming,
          listener: (context, state) {
            if (state.isRenaming) {
              showEditNameDialog();
            }
          },
        ),
      ],
      child: PopScope(
        canPop: _canPop,
        onPopInvokedWithResult: _onPopInvokedWithResult,
        child: Material(
          type: MaterialType.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16.0),
            topRight: Radius.circular(16.0),
          ),
          elevation: 16.0,
          child: (route != null)
              ? Provider<StoredUserRoute>(
                  create: (_) => route,
                  child: scrollView,
                )
              : Container(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _canPop {
    if (context.read<BusStopSheetBloc>().state.isEditing) {
      return false;
    }

    if (widget.rubberAnimationController.value != 0) {
      widget.rubberAnimationController.animateTo(to: 0);
      return false;
    }

    return true;
  }

  void _onPopInvokedWithResult<T>(bool didPop, T? result) {
    if (didPop) {
      return;
    }

    if (context.read<BusStopSheetBloc>().state.isEditing) {
      setState(() {
        context.read<BusStopSheetBloc>().add(const EditModeExited());
      });
      return;
    }

    if (widget.rubberAnimationController.value != 0) {
      widget.rubberAnimationController.animateTo(to: 0);
      return;
    }
  }

  Widget _buildFooter(BuildContext context) {
    final rowCount = busStop == null
        ? 0
        : ref.watch(busStopArrivalsProvider(busStop!)).value?.length ?? 0;
    final startOffset = (rowCount * kSheetRowAnimationOffset).clamp(0.0, 1.0);
    final endOffset =
        (rowCount * kSheetRowAnimationOffset + kSheetRowAnimDuration)
            .clamp(0.0, 1.0);
    final animation = timingListAnimationController
        .drive(CurveTween(
            curve: const Interval(
                kTitleFadeInDurationFactor - kSheetRowAnimationOffset,
                1))) // animate after previous code disappears
        .drive(CurveTween(
            curve: Interval(
                startOffset, endOffset))); // delay animation based on position
    return SlideTransition(
      position: animation
          .drive(CurveTween(curve: Curves.easeOutQuint))
          .drive(Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          )),
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8.0),
              const BusStopLegendCard(),
              Center(
                child: TextButton(
                  onPressed: () {
                    // Open settings page
                    Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const SettingsPage()));
                  },
                  child: Text('Missing bus services?',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall!
                          .copyWith(color: Theme.of(context).hintColor)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showEditNameDialog() async {
    final busStop = context.read<BusStopSheetBloc>().state.busStop!;
    // Reset text controller
    textController!.text = busStop.displayName;
    final newName = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          textController!.selection = TextSelection(
              baseOffset: 0, extentOffset: textController!.text.length);
          return Dialog(
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0, left: 16.0),
                    child: Text(
                      'Rename bus stop',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Container(height: 16.0),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      onSubmitted: (String name) {
                        final newName = textController!.text;
                        Navigator.pop(context, newName);
                      },
                      autofocus: true,
                      autocorrect: true,
                      controller: textController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Name',
                      ),
                    ),
                  ),
                  Container(height: 28.0),
                  ButtonTheme(
                    minWidth: 0,
                    height: 36,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            textController!.text = busStop.defaultName;
                          },
                          child: Text('Reset',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1)),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1)),
                        ),
                        Container(width: 8.0),
                        TextButton(
                          onPressed: () {
                            final newName = textController!.text;
                            Navigator.pop(context, newName);
                          },
                          child: Text('Save',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        });

    context.read<BusStopSheetBloc>().add(const RenameExited());
    if (newName != null) {
      context.read<BusStopSheetBloc>().add(BusStopRenamed(newName));
    }
  }
}
