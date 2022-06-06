import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubber/rubber.dart';
import '../bloc/bus_stop_sheet_bloc.dart';
import 'bus_stop_sheet.dart';
import 'bus_stop_sheet_header_dropdown.dart';

class BusStopSheetHeader extends StatelessWidget {
  const BusStopSheetHeader({
    Key? key,
    required this.rubberAnimationController,
    required this.hasAppBar,
  }) : super(key: key);

  final RubberAnimationController rubberAnimationController;
  final bool hasAppBar;

  @override
  Widget build(BuildContext context) {
    final busStop =
        context.select((BusStopSheetBloc bloc) => bloc.state.busStop)!;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final extraPadding = hasAppBar ? 0 : statusBarHeight;

    return AnimatedBuilder(
      animation: rubberAnimationController,
      builder: (BuildContext context, Widget? child) {
        final completed = rubberAnimationController.upperBound!;
        final dismissed = rubberAnimationController.lowerBound!;
        const animationStart = 0.75;
        final animationRange = completed - animationStart;
        final animationStartBound =
            dismissed + (completed - dismissed) * animationStart;
        final paddingHeightScale =
            ((rubberAnimationController.value - animationStartBound) /
                    animationRange)
                .clamp(0.0, 1.0);
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
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 56.0, right: 56.0),
              child: AnimatedSize(
                alignment: Alignment.topCenter,
                duration: kSheetUpdateDuration * 0.1,
                child: AnimatedSwitcher(
                  duration: kSheetUpdateDuration * kTitleFadeInDurationFactor,
                  switchInCurve: const Interval(0.25, 1),
                  switchOutCurve: const Interval(0.75, 1),
                  layoutBuilder:
                      (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                      alignment: Alignment.topCenter,
                    );
                  },
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    final entering =
                        child.key == ValueKey<String>(busStop.code);
                    final Animatable<double> curve = CurveTween(
                        curve: entering ? Curves.easeOutCubic : Curves.linear);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: animation.drive(curve).drive(Tween<Offset>(
                            begin: Offset(0, 0.5 * (entering ? 1 : -1)),
                            end: Offset.zero)),
                        child: entering
                            ? child
                            : Align(
                                alignment: Alignment.topCenter,
                                heightFactor: 1 - animation.value,
                                child: child),
                      ),
                    );
                  },
                  child: Column(
                    key: Key(busStop.code),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AutoSizeText(
                        busStop.displayName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                      ),
                      Text('${busStop.code} · ${busStop.road}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .subtitle2!
                              .copyWith(color: Theme.of(context).hintColor)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            alignment: Alignment.centerRight,
            child: const BusStopSheetHeaderDropdown(),
          ),
        ],
      ),
    );
  }
}
